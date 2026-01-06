# Quick Start Guide

This guide helps you quickly set up the database schema for the Baby Sleep Monitor MVP.

## Prerequisites

- Supabase project created
- Supabase CLI installed (optional, for local development)
- Access to Supabase Dashboard

## Applying Migrations

### Option 1: Using Supabase CLI (Recommended)

```bash
# Navigate to project root
cd /path/to/baby-sleep

# Link to your Supabase project (if not already linked)
supabase link --project-ref your-project-ref

# Push migrations to remote
supabase db push
```

### Option 2: Using Supabase Dashboard

1. Open your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Run each migration file in order:
   - `001_create_tables.sql`
   - `002_create_rls_policies.sql`
   - `003_create_indexes.sql`
   - `004_create_triggers.sql`

**Important**: Run migrations in this exact order!

## Verification

After applying migrations, verify the setup:

```sql
-- Check tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('babies', 'caregivers', 'sleep_events', 'devices');

-- Check RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('babies', 'caregivers', 'sleep_events', 'devices');
-- All should show rowsecurity = true

-- Check policies exist
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Check indexes exist
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN ('babies', 'caregivers', 'sleep_events', 'devices');
```

## Quick Test

Create a test baby and verify everything works:

```sql
-- As authenticated user, create a baby
INSERT INTO babies (name, created_by) 
VALUES ('Test Baby', auth.uid())
RETURNING id, name;

-- Verify first caregiver (owner) was auto-created
SELECT c.*, b.name as baby_name
FROM caregivers c
JOIN babies b ON c.baby_id = b.id
WHERE b.name = 'Test Baby';

-- Should show one caregiver with role 'owner'
```

## Next Steps

1. **Configure Authentication**: Set up Supabase Auth with your preferred provider
2. **Test RLS Policies**: See `TESTING.md` for comprehensive test scenarios
3. **Review Implementation**: See `IMPLEMENTATION_NOTES.md` for design decisions
4. **Start Flutter Development**: Database schema is ready for Flutter app integration

## Troubleshooting

### Migration Fails

- Check you're running migrations in order
- Verify you have proper permissions
- Check for existing tables (may need to drop first in development)

### RLS Blocking Access

- Verify user is authenticated (`auth.uid()` is not null)
- Check user is an active caregiver for the baby
- Verify baby is not soft deleted

### Trigger Not Firing

- Check trigger exists: `SELECT * FROM pg_trigger WHERE tgname LIKE '%caregiver%';`
- Verify function exists: `SELECT * FROM pg_proc WHERE proname LIKE '%caregiver%';`

## Support

For detailed information:
- **Schema Overview**: See `README.md`
- **Testing Guide**: See `TESTING.md`
- **Implementation Details**: See `IMPLEMENTATION_NOTES.md`

