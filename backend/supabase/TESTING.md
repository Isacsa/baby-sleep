# Testing the Database Schema

This document provides guidance on testing the database schema, RLS policies, and triggers.

## Prerequisites

- Supabase project set up
- Migrations applied in order
- Test user accounts created

## Testing RLS Policies

### Test 1: Baby Creation and First Caregiver

```sql
-- As user A, create a baby
INSERT INTO babies (name, created_by) 
VALUES ('Test Baby', auth.uid())
RETURNING id, name, created_by;

-- Verify first caregiver (owner) was created automatically
SELECT * FROM caregivers 
WHERE baby_id = '<baby_id_from_above>';

-- Should show one caregiver with role 'owner' and user_id = auth.uid()
```

### Test 2: Adding Caregivers

```sql
-- As owner, add another caregiver
INSERT INTO caregivers (baby_id, user_id, role)
VALUES ('<baby_id>', '<other_user_id>', 'editor');

-- Verify the new caregiver
SELECT * FROM caregivers WHERE baby_id = '<baby_id>';
```

### Test 3: Creating Sleep Events

```sql
-- As owner or editor, create a sleep event
INSERT INTO sleep_events (
    id, 
    baby_id, 
    type, 
    timestamp, 
    caregiver_id, 
    device_id
)
VALUES (
    gen_random_uuid(),
    '<baby_id>',
    'SleepStart',
    NOW(),
    '<caregiver_id>',
    'ios-test-device'
);

-- Verify the event
SELECT * FROM sleep_events WHERE baby_id = '<baby_id>';
```

### Test 4: RLS - User Cannot See Other Users' Babies

```sql
-- As user B (not a caregiver), try to see baby
SELECT * FROM babies WHERE id = '<baby_id_of_user_a>';

-- Should return no rows (RLS blocks access)
```

### Test 5: RLS - Viewer Cannot Create Events

```sql
-- As viewer, try to create event
INSERT INTO sleep_events (...)
VALUES (...);

-- Should fail with permission denied
```

### Test 6: Soft Delete

```sql
-- As owner, soft delete a baby
UPDATE babies 
SET deleted_at = NOW() 
WHERE id = '<baby_id>';

-- Verify baby is soft deleted
SELECT * FROM babies WHERE id = '<baby_id>';
-- Should return no rows (RLS hides soft deleted)

-- Verify events are also inaccessible
SELECT * FROM sleep_events WHERE baby_id = '<baby_id>';
-- Should return no rows
```

### Test 7: Prevent Removing Last Owner

```sql
-- As owner, try to soft delete yourself (last owner)
UPDATE caregivers 
SET deleted_at = NOW() 
WHERE id = '<your_caregiver_id>' 
  AND role = 'owner';

-- Should fail with "Cannot remove the last owner of a baby"
```

### Test 8: Timestamp Validation

```sql
-- Try to create event with future timestamp (> 1 hour)
INSERT INTO sleep_events (
    id, baby_id, type, timestamp, caregiver_id, device_id
)
VALUES (
    gen_random_uuid(),
    '<baby_id>',
    'SleepStart',
    NOW() + INTERVAL '2 hours',
    '<caregiver_id>',
    'ios-test'
);

-- Should fail with timestamp validation error
```

## Testing Triggers

### Test 1: Auto-create First Caregiver

```sql
-- Create baby
INSERT INTO babies (name, created_by) 
VALUES ('Trigger Test', auth.uid())
RETURNING id;

-- Check if caregiver was auto-created
SELECT * FROM caregivers 
WHERE baby_id = '<baby_id>';
-- Should show one owner caregiver
```

### Test 2: Updated_at Auto-update

```sql
-- Get current updated_at
SELECT updated_at FROM babies WHERE id = '<baby_id>';

-- Wait a moment, then update
UPDATE babies SET name = 'Updated Name' WHERE id = '<baby_id>';

-- Check updated_at changed
SELECT updated_at FROM babies WHERE id = '<baby_id>';
-- Should be newer than before
```

### Test 3: Device Last Seen Update

```sql
-- Create device
INSERT INTO devices (device_id, user_id, name)
VALUES ('ios-test-device', auth.uid(), 'Test Device');

-- Create sleep event
INSERT INTO sleep_events (...)
VALUES (...);

-- Check device last_seen_at updated
SELECT last_seen_at FROM devices WHERE device_id = 'ios-test-device';
-- Should be recent
```

## Testing Indexes

### Verify Indexes Exist

```sql
-- List all indexes on sleep_events
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'sleep_events';

-- Should show indexes for:
-- - baby_id, timestamp DESC
-- - baby_id, is_corrected, timestamp DESC
-- - caregiver_id, created_at DESC
-- - synced_at
```

### Test Query Performance

```sql
-- Test timeline query (should use index)
EXPLAIN ANALYZE
SELECT * FROM sleep_events 
WHERE baby_id = '<baby_id>' 
  AND is_corrected = false
ORDER BY timestamp DESC;

-- Should show index usage in execution plan
```

## Common Issues

### Issue: "Permission denied for table"

**Cause**: RLS policy is blocking access.

**Solution**: 
- Verify user is an active caregiver
- Check caregiver role has required permissions
- Verify baby is not soft deleted

### Issue: "Cannot remove the last owner"

**Cause**: Trying to remove the only owner caregiver.

**Solution**: 
- Add another owner first
- Then remove the original owner

### Issue: "Event timestamp cannot be more than X in the future"

**Cause**: Timestamp validation trigger.

**Solution**: 
- Ensure device clock is correct
- Use current time or recent past for events

### Issue: "Caregiver does not belong to this baby"

**Cause**: caregiver_id doesn't match baby_id.

**Solution**: 
- Verify caregiver_id is correct
- Ensure caregiver is active (not soft deleted)

## Performance Testing

### Test with Large Dataset

```sql
-- Insert many events
DO $$
DECLARE
    i INTEGER;
    baby_uuid UUID := '<baby_id>';
    caregiver_uuid UUID := '<caregiver_id>';
BEGIN
    FOR i IN 1..1000 LOOP
        INSERT INTO sleep_events (
            id, baby_id, type, timestamp, caregiver_id, device_id
        )
        VALUES (
            gen_random_uuid(),
            baby_uuid,
            CASE WHEN i % 2 = 0 THEN 'SleepEnd' ELSE 'SleepStart' END,
            NOW() - (i || ' hours')::INTERVAL,
            caregiver_uuid,
            'ios-test'
        );
    END LOOP;
END $$;

-- Test query performance
EXPLAIN ANALYZE
SELECT * FROM sleep_events 
WHERE baby_id = '<baby_id>'
ORDER BY timestamp DESC
LIMIT 50;
```

