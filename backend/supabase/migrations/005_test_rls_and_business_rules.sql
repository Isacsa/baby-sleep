-- ============================================
-- TEST SUITE: Row Level Security (RLS) and Business Rules
-- ============================================
-- Description: Comprehensive test queries to validate RLS policies and business rules
-- 
-- IMPORTANT: These queries assume you have at least 2 authenticated users:
--   - User A (auth.uid() = 'user-a-uuid')
--   - User B (auth.uid() = 'user-b-uuid')
--
-- To run these tests:
--   1. Authenticate as User A in Supabase Dashboard
--   2. Run the User A test queries
--   3. Authenticate as User B
--   4. Run the User B test queries
--   5. Verify expected results match actual results
--
-- ============================================
-- SETUP: Get user IDs (run these first to get actual UUIDs)
-- ============================================

-- Get current authenticated user ID
-- EXPECTED: SUCCESS - Returns your current auth.uid()
SELECT auth.uid() AS current_user_id;

-- List all users (if you have access)
-- EXPECTED: SUCCESS or FAIL (depending on permissions)
-- SELECT id, email FROM auth.users LIMIT 10;

-- ============================================
-- TEST GROUP 1: User A creates a baby
-- ============================================
-- Context: User A is authenticated (auth.uid() = User A UUID)
-- ============================================

-- TEST 1.1: User A creates a baby
-- EXPECTED: SUCCESS - Baby is created
-- Note: Replace 'Baby Test A' with desired name
INSERT INTO babies (name, created_by, created_at)
VALUES ('Baby Test A', auth.uid(), NOW())
RETURNING id, name, created_by, created_at;

-- TEST 1.2: Verify trigger automatically created caregiver (owner) for User A
-- EXPECTED: SUCCESS - Should return 1 row with role = 'owner'
-- Note: Replace <baby_id_from_1.1> with the ID returned from TEST 1.1
SELECT id, baby_id, user_id, role, created_at
FROM caregivers
WHERE baby_id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
  AND user_id = auth.uid()
  AND role = 'owner'
  AND deleted_at IS NULL;

-- TEST 1.3: User A can view the baby they created
-- EXPECTED: SUCCESS - Should return the baby
SELECT id, name, created_by, created_at
FROM babies
WHERE id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
  AND deleted_at IS NULL;

-- ============================================
-- TEST GROUP 2: User A (owner) permissions
-- ============================================
-- Context: User A is authenticated and is owner of a baby
-- ============================================

-- TEST 2.1: User A (owner) can insert sleep_event
-- EXPECTED: SUCCESS - Event is created
-- Note: Replace <baby_id> and <caregiver_id> with actual IDs
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),  -- Or use a specific UUID from Flutter
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    'SleepStart',
    NOW() - INTERVAL '2 hours',
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id = auth.uid() AND deleted_at IS NULL LIMIT 1),
    'device-user-a-001',
    NOW() - INTERVAL '2 hours',
    false
)
RETURNING id, baby_id, type, timestamp, caregiver_id, created_at;

-- TEST 2.2: User A (owner) can add another caregiver (editor)
-- EXPECTED: SUCCESS - New caregiver is created
-- Note: Replace <baby_id> and <user_b_uuid> with actual IDs
-- IMPORTANT: User B must exist in auth.users
INSERT INTO caregivers (baby_id, user_id, role, created_at, updated_at)
VALUES (
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    '<user_b_uuid>',  -- Replace with User B's UUID from auth.users
    'editor',
    NOW(),
    NOW()
)
RETURNING id, baby_id, user_id, role, created_at;

-- TEST 2.3: User A (owner) can add another caregiver (viewer)
-- EXPECTED: SUCCESS - New caregiver is created
-- Note: This assumes you have a third user, or use a different user
INSERT INTO caregivers (baby_id, user_id, role, created_at, updated_at)
VALUES (
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    '<user_c_uuid>',  -- Replace with another user's UUID (optional test)
    'viewer',
    NOW(),
    NOW()
)
RETURNING id, baby_id, user_id, role, created_at;

-- TEST 2.4: User A (owner) can soft delete a non-owner caregiver
-- EXPECTED: SUCCESS - Caregiver is soft deleted (deleted_at is set)
-- Note: Replace <caregiver_id> with ID of a non-owner caregiver
UPDATE caregivers
SET deleted_at = NOW()
WHERE id = '<caregiver_id>'  -- Replace with actual caregiver_id (non-owner)
  AND baby_id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
  AND role != 'owner'
RETURNING id, baby_id, user_id, role, deleted_at;

-- TEST 2.5: User A (owner) CANNOT soft delete the last owner (themselves)
-- EXPECTED: FAIL - Trigger should raise exception "Cannot remove the last owner of a baby"
-- Note: This should fail if User A is the only owner
UPDATE caregivers
SET deleted_at = NOW()
WHERE id = (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id = auth.uid() AND role = 'owner' AND deleted_at IS NULL LIMIT 1)
RETURNING id, baby_id, user_id, role, deleted_at;

-- TEST 2.6: User A (owner) can update baby name
-- EXPECTED: SUCCESS - Baby name is updated
UPDATE babies
SET name = 'Baby Test A Updated'
WHERE id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
RETURNING id, name, updated_at;

-- TEST 2.7: User A (owner) CANNOT change created_by (immutability)
-- EXPECTED: FAIL - Trigger should raise exception "Cannot change created_by in babies"
UPDATE babies
SET created_by = '<user_b_uuid>'  -- Replace with User B's UUID
WHERE id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
RETURNING id, created_by;

-- TEST 2.8: User A (owner) can soft delete the baby
-- EXPECTED: SUCCESS - Baby is soft deleted (deleted_at is set)
-- Note: After this, the baby should not be visible via RLS
UPDATE babies
SET deleted_at = NOW()
WHERE id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
RETURNING id, name, deleted_at;

-- ============================================
-- TEST GROUP 3: User B as editor permissions
-- ============================================
-- Context: User B is authenticated and is editor of a baby
-- IMPORTANT: Switch authentication to User B before running these tests
-- ============================================

-- TEST 3.1: User B (editor) can view the baby
-- EXPECTED: SUCCESS - Should return the baby
SELECT id, name, created_by, created_at
FROM babies
WHERE id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
  AND deleted_at IS NULL;

-- TEST 3.2: User B (editor) can insert sleep_event
-- EXPECTED: SUCCESS - Event is created
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    'SleepEnd',
    NOW() - INTERVAL '1 hour',
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id = auth.uid() AND deleted_at IS NULL LIMIT 1),
    'device-user-b-001',
    NOW() - INTERVAL '1 hour',
    false
)
RETURNING id, baby_id, type, timestamp, caregiver_id, created_at;

-- TEST 3.3: User B (editor) can update sleep_event (non-immutable fields)
-- EXPECTED: SUCCESS - Event is updated (e.g., is_corrected, synced_at)
-- Note: Replace <sleep_event_id> with actual event ID
UPDATE sleep_events
SET is_corrected = true,
    synced_at = NOW()
WHERE id = '<sleep_event_id>'  -- Replace with actual sleep_event id
  AND baby_id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
RETURNING id, is_corrected, synced_at;

-- TEST 3.4: User B (editor) CANNOT change immutable fields (timestamp)
-- EXPECTED: FAIL - Trigger should raise exception "Cannot change timestamp in sleep_events"
UPDATE sleep_events
SET timestamp = NOW()
WHERE id = '<sleep_event_id>'  -- Replace with actual sleep_event id
RETURNING id, timestamp;

-- TEST 3.5: User B (editor) CANNOT soft delete the baby
-- EXPECTED: FAIL - RLS policy should block (only owner can soft delete)
UPDATE babies
SET deleted_at = NOW()
WHERE id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
RETURNING id, deleted_at;

-- TEST 3.6: User B (editor) CANNOT change caregiver roles
-- EXPECTED: FAIL - RLS policy should block (only owner can change roles)
UPDATE caregivers
SET role = 'viewer'
WHERE id = '<caregiver_id>'  -- Replace with actual caregiver_id
  AND baby_id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
RETURNING id, role;

-- TEST 3.7: User B (editor) can add a viewer caregiver
-- EXPECTED: SUCCESS - New caregiver is created (editor can add viewer/editor, not owner)
INSERT INTO caregivers (baby_id, user_id, role, created_at, updated_at)
VALUES (
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    '<user_c_uuid>',  -- Replace with another user's UUID
    'viewer',
    NOW(),
    NOW()
)
RETURNING id, baby_id, user_id, role, created_at;

-- TEST 3.8: User B (editor) CANNOT add an owner caregiver
-- EXPECTED: FAIL - RLS policy should block (only owner can add owner)
INSERT INTO caregivers (baby_id, user_id, role, created_at, updated_at)
VALUES (
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    '<user_c_uuid>',  -- Replace with another user's UUID
    'owner',
    NOW(),
    NOW()
)
RETURNING id, baby_id, user_id, role, created_at;

-- ============================================
-- TEST GROUP 4: User B as viewer permissions
-- ============================================
-- Context: User B is authenticated and is viewer of a baby
-- IMPORTANT: First change User B's role to 'viewer' (as owner), then run these tests
-- ============================================

-- TEST 4.1: User B (viewer) can SELECT baby
-- EXPECTED: SUCCESS - Should return the baby
SELECT id, name, created_by, created_at
FROM babies
WHERE id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
  AND deleted_at IS NULL;

-- TEST 4.2: User B (viewer) can SELECT sleep_events
-- EXPECTED: SUCCESS - Should return events
SELECT id, baby_id, type, timestamp, caregiver_id, created_at
FROM sleep_events
WHERE baby_id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
ORDER BY timestamp DESC
LIMIT 10;

-- TEST 4.3: User B (viewer) can SELECT caregivers
-- EXPECTED: SUCCESS - Should return caregivers of the baby
SELECT id, baby_id, user_id, role, created_at
FROM caregivers
WHERE baby_id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
  AND deleted_at IS NULL;

-- TEST 4.4: User B (viewer) CANNOT INSERT sleep_event
-- EXPECTED: FAIL - RLS policy should block (viewer is read-only)
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    'SleepStart',
    NOW(),
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id = auth.uid() AND deleted_at IS NULL LIMIT 1),
    'device-user-b-001',
    NOW(),
    false
)
RETURNING id;

-- TEST 4.5: User B (viewer) CANNOT UPDATE sleep_event
-- EXPECTED: FAIL - RLS policy should block (viewer is read-only)
UPDATE sleep_events
SET is_corrected = true
WHERE id = '<sleep_event_id>'  -- Replace with actual sleep_event id
RETURNING id, is_corrected;

-- TEST 4.6: User B (viewer) CANNOT UPDATE baby
-- EXPECTED: FAIL - RLS policy should block (viewer is read-only)
UPDATE babies
SET name = 'Baby Test A Hacked'
WHERE id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
RETURNING id, name;

-- ============================================
-- TEST GROUP 5: Security - Access control
-- ============================================
-- Context: Test that users cannot access data they shouldn't
-- ============================================

-- TEST 5.1: User B CANNOT access babies where they are not a caregiver
-- EXPECTED: FAIL - Should return 0 rows (RLS blocks access)
-- Note: Create a baby as User A, then try to access it as User B (before adding User B as caregiver)
SELECT id, name, created_by
FROM babies
WHERE id = '<baby_id_user_a_only>'  -- Replace with a baby_id where User B is NOT a caregiver
  AND deleted_at IS NULL;

-- TEST 5.2: User B CANNOT see sleep_events for babies they don't care for
-- EXPECTED: FAIL - Should return 0 rows (RLS blocks access)
SELECT id, baby_id, type, timestamp
FROM sleep_events
WHERE baby_id = '<baby_id_user_a_only>'  -- Replace with a baby_id where User B is NOT a caregiver
ORDER BY timestamp DESC;

-- TEST 5.3: User B CANNOT create sleep_event with caregiver_id of another user
-- EXPECTED: FAIL - RLS policy should block (caregiver_id must belong to auth.uid())
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),
    '<baby_id_from_1.1>',  -- Replace with actual baby_id (where User B is caregiver)
    'SleepStart',
    NOW(),
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id != auth.uid() AND deleted_at IS NULL LIMIT 1),  -- Caregiver of another user
    'device-user-b-001',
    NOW(),
    false
)
RETURNING id;

-- TEST 5.4: User B CANNOT create sleep_event for baby they don't care for
-- EXPECTED: FAIL - RLS policy should block (can_write returns false)
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),
    '<baby_id_user_a_only>',  -- Replace with a baby_id where User B is NOT a caregiver
    'SleepStart',
    NOW(),
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_user_a_only>' AND user_id != auth.uid() LIMIT 1),  -- Caregiver of User A
    'device-user-b-001',
    NOW(),
    false
)
RETURNING id;

-- ============================================
-- TEST GROUP 6: Business rules and triggers
-- ============================================
-- Context: Test business logic enforced by triggers
-- ============================================

-- TEST 6.1: Cannot create sleep_event with timestamp > 1 hour in future
-- EXPECTED: FAIL - Trigger should raise exception about future timestamp
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    'SleepStart',
    NOW() + INTERVAL '2 hours',  -- More than 1 hour in future
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id = auth.uid() AND deleted_at IS NULL LIMIT 1),
    'device-user-a-001',
    NOW(),
    false
)
RETURNING id, timestamp;

-- TEST 6.2: Can create sleep_event with timestamp in the past (retroactive)
-- EXPECTED: SUCCESS - Event is created (offline-first + retroactive corrections)
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    'SleepStart',
    NOW() - INTERVAL '1 day',  -- Past timestamp
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id = auth.uid() AND deleted_at IS NULL LIMIT 1),
    'device-user-a-001',
    NOW() - INTERVAL '1 day',
    false
)
RETURNING id, timestamp, created_at;

-- TEST 6.3: Cannot create sleep_event with corrected_by but is_corrected = false
-- EXPECTED: FAIL - CHECK constraint or trigger should raise exception
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected,
    corrected_by
)
VALUES (
    gen_random_uuid(),
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    'SleepStart',
    NOW(),
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id = auth.uid() AND deleted_at IS NULL LIMIT 1),
    'device-user-a-001',
    NOW(),
    false,  -- is_corrected = false
    '<some_event_id>'  -- But corrected_by is set
)
RETURNING id, is_corrected, corrected_by;

-- TEST 6.4: Can create sleep_event with corrected_by and is_corrected = true
-- EXPECTED: SUCCESS - Event is created (correction chain)
-- Note: Replace <original_event_id> with an actual sleep_event id
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected,
    corrected_by
)
VALUES (
    gen_random_uuid(),
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    'SleepStart',
    NOW(),
    (SELECT id FROM caregivers WHERE baby_id = '<baby_id_from_1.1>' AND user_id = auth.uid() AND deleted_at IS NULL LIMIT 1),
    'device-user-a-001',
    NOW(),
    true,  -- is_corrected = true
    '<original_event_id>'  -- Replace with actual sleep_event id
)
RETURNING id, is_corrected, corrected_by;

-- TEST 6.5: Cannot create sleep_event with invalid baby_id
-- EXPECTED: FAIL - Trigger should raise exception "Baby does not exist or has been deleted"
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000000',  -- Invalid/non-existent baby_id
    'SleepStart',
    NOW(),
    (SELECT id FROM caregivers WHERE user_id = auth.uid() AND deleted_at IS NULL LIMIT 1),
    'device-user-a-001',
    NOW(),
    false
)
RETURNING id;

-- TEST 6.6: Cannot create sleep_event with caregiver_id that doesn't belong to baby_id
-- EXPECTED: FAIL - Trigger should raise exception about caregiver not belonging to baby
INSERT INTO sleep_events (
    id,
    baby_id,
    type,
    timestamp,
    caregiver_id,
    device_id,
    created_at,
    is_corrected
)
VALUES (
    gen_random_uuid(),
    '<baby_id_from_1.1>',  -- Replace with actual baby_id
    'SleepStart',
    NOW(),
    (SELECT id FROM caregivers WHERE baby_id != '<baby_id_from_1.1>' AND deleted_at IS NULL LIMIT 1),  -- Caregiver from different baby
    'device-user-a-001',
    NOW(),
    false
)
RETURNING id;

-- ============================================
-- TEST GROUP 7: Verification queries
-- ============================================
-- Context: Queries to verify state after tests
-- ============================================

-- TEST 7.1: Count babies created by current user
-- EXPECTED: SUCCESS - Returns count of babies where user is caregiver
SELECT COUNT(*) AS baby_count
FROM babies b
WHERE EXISTS (
    SELECT 1 FROM caregivers c
    WHERE c.baby_id = b.id
      AND c.user_id = auth.uid()
      AND c.deleted_at IS NULL
)
AND b.deleted_at IS NULL;

-- TEST 7.2: List all caregivers for a baby (as owner/editor)
-- EXPECTED: SUCCESS - Returns all active caregivers
SELECT c.id, c.baby_id, c.user_id, c.role, c.created_at, c.deleted_at
FROM caregivers c
WHERE c.baby_id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
ORDER BY c.created_at;

-- TEST 7.3: List all sleep_events for a baby (timeline)
-- EXPECTED: SUCCESS - Returns events ordered by timestamp
SELECT id, type, timestamp, caregiver_id, created_at, is_corrected, corrected_by
FROM sleep_events
WHERE baby_id = '<baby_id_from_1.1>'  -- Replace with actual baby_id
ORDER BY timestamp DESC, created_at DESC;

-- TEST 7.4: Verify only one owner exists per baby (after tests)
-- EXPECTED: SUCCESS - Should return count of owners (should be >= 1)
SELECT baby_id, COUNT(*) AS owner_count
FROM caregivers
WHERE role = 'owner'
  AND deleted_at IS NULL
GROUP BY baby_id
HAVING COUNT(*) >= 1;

-- ============================================
-- CLEANUP (Optional - for testing environment only)
-- ============================================
-- WARNING: Only run these in a test environment!
-- ============================================

-- Cleanup: Soft delete test babies (as owner)
-- UPDATE babies SET deleted_at = NOW() WHERE name LIKE 'Baby Test%' AND deleted_at IS NULL;

-- Cleanup: Hard delete (only if absolutely necessary in test environment)
-- DELETE FROM sleep_events WHERE baby_id IN (SELECT id FROM babies WHERE name LIKE 'Baby Test%');
-- DELETE FROM caregivers WHERE baby_id IN (SELECT id FROM babies WHERE name LIKE 'Baby Test%');
-- DELETE FROM babies WHERE name LIKE 'Baby Test%';

