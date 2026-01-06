# Implementation Notes

This document describes implementation decisions and how they map to the specification.

## Migration Files

### 001_create_tables.sql
- Creates all base tables: `babies`, `caregivers`, `sleep_events`, `devices`
- Enables RLS on all tables
- Sets up foreign key relationships
- No CASCADE deletes (soft delete only)

### 002_create_rls_policies.sql
- Creates helper functions for RLS checks
- Implements all RLS policies per specification
- Policies enforce access through `caregivers` relationship
- Soft delete handled via UPDATE policies

### 003_create_indexes.sql
- Creates indexes for common query patterns
- Optimizes timeline queries
- Optimizes sync queries
- Supports incremental sync with `synced_at` index

### 004_create_triggers.sql
- Auto-updates `updated_at` timestamps
- Auto-creates first caregiver (owner) when baby is created
- Validates sleep event timestamps
- Prevents removing last owner
- Updates device `last_seen_at` on event creation

## Key Implementation Decisions

### 1. First Caregiver Auto-Creation
**Decision**: Trigger automatically creates first caregiver (owner) when baby is created.

**Rationale**: 
- Ensures baby creator is always a caregiver
- Simplifies application logic
- Guarantees at least one owner exists

**Implementation**: `create_first_caregiver_trigger` in 004_create_triggers.sql

### 2. RLS Policy Structure
**Decision**: Combined UPDATE policies for regular updates and soft delete.

**Rationale**:
- Avoids policy conflicts
- Single policy handles both cases
- Clearer logic flow

**Implementation**: Policies check `deleted_at IS NULL` in USING, allow both in WITH CHECK

### 3. Timestamp Validation
**Decision**: Trigger validates timestamps on INSERT/UPDATE.

**Rationale**:
- Prevents obviously incorrect data
- Enforces reasonable bounds (1 hour future, 1 year past)
- Backend validation as specified

**Implementation**: `validate_sleep_event_trigger` in 004_create_triggers.sql

### 4. Device Auto-Registration
**Decision**: Device is auto-created when first used in an event.

**Rationale**:
- Simplifies client code
- No separate device registration step
- Still allows manual device management

**Implementation**: `update_device_on_event` trigger in 004_create_triggers.sql

### 5. Immutable Fields Protection
**Decision**: RLS policies enforce immutability of core event fields.

**Rationale**:
- Prevents accidental data corruption
- Maintains audit trail integrity
- Enforces correction pattern (new events, not edits)

**Implementation**: WITH CHECK clauses in sleep_events UPDATE policy

### 6. Helper Functions Security
**Decision**: Helper functions use `SECURITY DEFINER`.

**Rationale**:
- Functions need to check caregivers table
- RLS on caregivers could block function execution
- SECURITY DEFINER allows bypass for checks only

**Note**: Functions only read data, never modify, so safe

## Mapping to Specification

### Section 1: Entidades Persistidas ✅
- All tables created with specified fields
- All constraints implemented
- Soft delete via `deleted_at` timestamp

### Section 2: Relações ✅
- Foreign keys defined
- No CASCADE deletes
- Self-reference for `corrected_by` in sleep_events

### Section 3: Campos Obrigatórios ✅
- All required fields marked NOT NULL
- Optional fields properly nullable
- Default values where appropriate

### Section 4: RLS Strategy ✅
- All tables have RLS enabled
- Policies evaluate through `caregivers` relationship
- Access always via `baby_id`

### Section 5: Role-Based Access ✅
- Owner: Full access
- Editor: Can create/edit events, add caregivers (viewer/editor only)
- Viewer: Read-only

### Section 6: Multi-Device & Auditing ✅
- `device_id` in all events
- `devices` table for tracking
- All audit fields present

### Section 7: Offline-First Sync ✅
- `id` is UUID (client-generated)
- `synced_at` for incremental sync
- UNIQUE constraint on `id` for idempotency
- Indexes support sync queries

### Section 8: Indexes ✅
- All recommended indexes created
- Partial indexes for active records
- Optimized for common queries

## Deviations from Specification

### None
All requirements from the specification have been implemented as specified.

## Future Considerations

### 1. Rate Limiting
Not implemented in MVP. Can be added via:
- Database functions with rate limit checks
- Application-level rate limiting
- Supabase Edge Functions

### 2. Export Functionality
Not implemented in MVP. Can be added via:
- Database function to generate JSON export
- Supabase Edge Function for GDPR compliance

### 3. Permanent Deletion
Not implemented in MVP. Can be added via:
- Database function with multiple confirmations
- Audit log before deletion
- Cascading hard deletes (with backups)

### 4. Generic Events Table
MVP uses `sleep_events` specifically. Future migration path:
- Create generic `events` table
- Migrate `sleep_events` → `events` with `module = 'sleep'`
- Maintain backward compatibility during transition

## Testing Checklist

- [ ] All migrations run successfully
- [ ] RLS policies work as expected
- [ ] Triggers fire correctly
- [ ] Indexes improve query performance
- [ ] Soft delete works
- [ ] First caregiver auto-creation works
- [ ] Timestamp validation works
- [ ] Multi-user scenarios work
- [ ] Offline sync simulation works

## Known Limitations

1. **Device ID Format**: No validation of device_id format. Client must ensure uniqueness.

2. **Metadata Structure**: JSONB field has no schema validation. Client must ensure structure.

3. **Concurrent Updates**: No explicit locking for concurrent updates. Relies on RLS and application logic.

4. **Sync Conflicts**: Backend doesn't resolve conflicts. Client must handle conflict resolution.

## Performance Considerations

1. **Indexes**: All critical queries have indexes. Monitor query performance in production.

2. **Partial Indexes**: Used for active records (WHERE deleted_at IS NULL). Reduces index size.

3. **JSONB**: `metadata` field uses JSONB for flexibility. Consider indexing if querying becomes common.

4. **Triggers**: Triggers add minimal overhead. Monitor in high-volume scenarios.

