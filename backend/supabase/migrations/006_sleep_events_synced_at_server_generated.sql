-- Migration: Server-generated synced_at for sleep_events
-- Purpose: Enable reliable incremental sync by ensuring synced_at is always server-time
-- 
-- This migration:
-- 1. Backfills existing NULL synced_at with conservative value (never future)
-- 2. Creates trigger to set synced_at = NOW() on INSERT (ignores client value)
-- 3. Creates trigger to update synced_at = NOW() on UPDATE of mutable fields
-- 4. Creates composite index for efficient cursor-based pull (baby_id, synced_at, id)
-- 5. Adjusts validate_sleep_event to not block UPDATEs on mutable fields only

-- ============================================
-- 1. BACKFILL: Conservative synced_at for existing rows
-- ============================================
-- Uses LEAST(COALESCE(created_at, NOW()), NOW()) to ensure:
-- - synced_at is never in the future (capped at NOW())
-- - synced_at uses created_at if available (preserves relative order)
-- - synced_at falls back to NOW() only if created_at is somehow NULL

UPDATE sleep_events 
SET synced_at = LEAST(COALESCE(created_at, NOW()), NOW()) 
WHERE synced_at IS NULL;

-- ============================================
-- 2. TRIGGER: Set synced_at on INSERT (server-time only)
-- ============================================
-- Ensures client cannot control synced_at; always uses server timestamp
-- This eliminates clock-skew issues in incremental sync

CREATE OR REPLACE FUNCTION set_synced_at_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Always override client-provided synced_at with server time
    NEW.synced_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_synced_at_on_insert_trigger ON sleep_events;
CREATE TRIGGER set_synced_at_on_insert_trigger
    BEFORE INSERT ON sleep_events
    FOR EACH ROW
    EXECUTE FUNCTION set_synced_at_on_insert();

-- ============================================
-- 3. TRIGGER: Update synced_at on UPDATE of mutable fields
-- ============================================
-- When mutable fields change (is_corrected, corrected_by, metadata),
-- update synced_at to NOW() so other devices see the change via incremental pull.
-- 
-- Mutable fields: is_corrected, corrected_by, metadata, synced_at
-- Immutable fields: id, baby_id, type, timestamp, caregiver_id, device_id, created_at

CREATE OR REPLACE FUNCTION update_synced_at_on_mutable_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if any mutable field changed (excluding synced_at itself which we're setting)
    IF OLD.is_corrected IS DISTINCT FROM NEW.is_corrected
       OR OLD.corrected_by IS DISTINCT FROM NEW.corrected_by
       OR OLD.metadata IS DISTINCT FROM NEW.metadata
    THEN
        NEW.synced_at = NOW();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_synced_at_on_mutable_change_trigger ON sleep_events;
CREATE TRIGGER update_synced_at_on_mutable_change_trigger
    BEFORE UPDATE ON sleep_events
    FOR EACH ROW
    EXECUTE FUNCTION update_synced_at_on_mutable_change();

-- ============================================
-- 4. INDEX: Composite index for cursor-based incremental pull
-- ============================================
-- Supports efficient range scan for:
-- WHERE baby_id = ? AND (synced_at, id) > (cursorSyncedAt, cursorId)
-- ORDER BY synced_at ASC, id ASC

CREATE INDEX IF NOT EXISTS idx_sleep_events_baby_synced_at_id 
ON sleep_events(baby_id, synced_at, id);

-- ============================================
-- 5. ADJUST: validate_sleep_event to allow mutable-only UPDATEs
-- ============================================
-- The existing trigger validates baby exists and caregiver is valid on every INSERT/UPDATE.
-- For UPDATEs that only change mutable fields (is_corrected, corrected_by, metadata, synced_at),
-- we should skip the caregiver validation since caregiver_id is immutable and was already validated.
-- 
-- We detect "mutable-only update" by checking if immutable fields are unchanged.

CREATE OR REPLACE FUNCTION validate_sleep_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    max_future_hours INTEGER := 1;
    now_ts TIMESTAMPTZ := NOW();
    baby_exists BOOLEAN;
    caregiver_valid BOOLEAN;
    is_mutable_only_update BOOLEAN := false;
BEGIN
    -- For UPDATE: check if this is a mutable-only update
    -- If only mutable fields changed, skip caregiver re-validation
    IF TG_OP = 'UPDATE' THEN
        -- Check if all immutable fields are unchanged
        IF OLD.id = NEW.id
           AND OLD.baby_id = NEW.baby_id
           AND OLD.type = NEW.type
           AND OLD.timestamp = NEW.timestamp
           AND OLD.caregiver_id = NEW.caregiver_id
           AND OLD.device_id = NEW.device_id
           AND OLD.created_at = NEW.created_at
        THEN
            is_mutable_only_update := true;
        END IF;
    END IF;

    -- Skip validation for mutable-only updates
    -- (baby and caregiver were already validated on INSERT)
    IF is_mutable_only_update THEN
        RETURN NEW;
    END IF;

    -- Full validation for INSERT or UPDATE with immutable field changes
    
    -- Validate timestamp is not too far in the future (> 1 hour)
    IF NEW.timestamp > now_ts + (max_future_hours || ' hours')::INTERVAL THEN
        RAISE EXCEPTION 'Event timestamp cannot be more than % hour(s) in the future', max_future_hours;
    END IF;
    
    -- Validate baby exists and is not soft deleted
    SELECT EXISTS (
        SELECT 1 FROM babies
        WHERE id = NEW.baby_id
          AND deleted_at IS NULL
    ) INTO baby_exists;
    
    IF NOT baby_exists THEN
        RAISE EXCEPTION 'Baby does not exist or has been deleted';
    END IF;
    
    -- Validate caregiver exists, is active, and belongs to the baby
    SELECT EXISTS (
        SELECT 1 FROM caregivers
        WHERE id = NEW.caregiver_id
          AND baby_id = NEW.baby_id
          AND deleted_at IS NULL
    ) INTO caregiver_valid;
    
    IF NOT caregiver_valid THEN
        RAISE EXCEPTION 'Caregiver does not exist, is inactive, or does not belong to this baby';
    END IF;
    
    RETURN NEW;
END;
$$;

-- Note: The trigger validate_sleep_event_trigger already exists from migration 004.
-- We just replaced the function, so no need to recreate the trigger.

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON FUNCTION set_synced_at_on_insert() IS 'Ensures synced_at is always server-generated on INSERT, eliminating client clock-skew issues.';
COMMENT ON FUNCTION update_synced_at_on_mutable_change() IS 'Updates synced_at when mutable fields change, enabling incremental sync to detect corrections.';
COMMENT ON INDEX idx_sleep_events_baby_synced_at_id IS 'Composite index for efficient cursor-based incremental pull by (baby_id, synced_at, id).';
