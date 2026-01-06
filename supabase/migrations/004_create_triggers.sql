-- Migration: Create triggers for automatic field updates and validations
-- Based on: Modelo de Dados e Segurança - Especificação Conceitual, Secção 9.3
-- Description: Creates triggers for automatic updates, validations, and business rules

-- ============================================
-- Trigger: Auto-update updated_at timestamps
-- Secção 9.3: Triggers Necessários
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Trigger for babies.updated_at
DROP TRIGGER IF EXISTS update_babies_updated_at ON babies;
CREATE TRIGGER update_babies_updated_at
    BEFORE UPDATE ON babies
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger for caregivers.updated_at
DROP TRIGGER IF EXISTS update_caregivers_updated_at ON caregivers;
CREATE TRIGGER update_caregivers_updated_at
    BEFORE UPDATE ON caregivers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Trigger: Auto-create first caregiver (owner) when baby is created
-- Secção 8.4: Primeiro Cuidador
-- Secção 9.3: Triggers Necessários
-- ============================================

-- Function to automatically create first caregiver (owner) when baby is created
-- Criador do bebé automaticamente torna-se primeiro caregiver com role = owner
-- Garantido por trigger, não requer ação explícita do utilizador
CREATE OR REPLACE FUNCTION create_first_caregiver()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO caregivers (baby_id, user_id, role, created_at, updated_at)
    VALUES (NEW.id, NEW.created_by, 'owner', NOW(), NOW());
    RETURN NEW;
END;
$$;

-- Trigger to create first caregiver when baby is created
DROP TRIGGER IF EXISTS create_first_caregiver_trigger ON babies;
CREATE TRIGGER create_first_caregiver_trigger
    AFTER INSERT ON babies
    FOR EACH ROW
    EXECUTE FUNCTION create_first_caregiver();

-- ============================================
-- Trigger: Ensure at least one owner exists for a baby
-- Secção 8.5: Mínimo de Owners
-- Secção 9.3: Triggers Necessários
-- ============================================

-- Function to ensure at least one owner exists for a baby
-- Deve haver pelo menos um owner por bebé
-- Prevenção: trigger impede remoção do último owner
-- Regra garantida no backend, não apenas na app
CREATE OR REPLACE FUNCTION ensure_at_least_one_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    owner_count INTEGER;
BEGIN
    IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        SELECT COUNT(*) INTO owner_count
        FROM caregivers
        WHERE baby_id = NEW.baby_id
          AND role = 'owner'
          AND deleted_at IS NULL
          AND id != NEW.id;
        
        IF owner_count = 0 AND OLD.role = 'owner' THEN
            RAISE EXCEPTION 'Cannot remove the last owner of a baby';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- Trigger to ensure at least one owner exists
DROP TRIGGER IF EXISTS ensure_at_least_one_owner_trigger ON caregivers;
CREATE TRIGGER ensure_at_least_one_owner_trigger
    BEFORE UPDATE ON caregivers
    FOR EACH ROW
    EXECUTE FUNCTION ensure_at_least_one_owner();

-- ============================================
-- Trigger: Validate sleep event timestamps and relationships
-- Secção 10.1: Validações no Backend
-- Secção 9.3: Triggers Necessários
-- ============================================

-- Function to validate sleep event on insert/update
-- Note: RLS policies handle authorization, this function handles data integrity
-- Validações obrigatórias:
-- - baby_id existe e não está soft deleted
-- - caregiver_id existe, está ativo, e pertence ao baby_id
-- - timestamp não muito no futuro (ajuste de relógio)
-- Nota: Validação de timestamp no passado removida (offline-first + correções retroativas)
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
BEGIN
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

-- Trigger to validate sleep events
DROP TRIGGER IF EXISTS validate_sleep_event_trigger ON sleep_events;
CREATE TRIGGER validate_sleep_event_trigger
    BEFORE INSERT OR UPDATE ON sleep_events
    FOR EACH ROW
    EXECUTE FUNCTION validate_sleep_event();

-- ============================================
-- Trigger: Validate correction integrity
-- Integridade mínima entre is_corrected e corrected_by
-- Regra: Se corrected_by IS NOT NULL, então is_corrected = true
-- Nota: Cadeias de correções são permitidas (lógica de domínio no cliente)
-- ============================================

-- Function to validate correction integrity
-- Backend valida apenas integridade mínima, não lógica de domínio avançada
CREATE OR REPLACE FUNCTION validate_correction_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Regra: Se corrected_by IS NOT NULL, então is_corrected = true
    -- (Já garantido por CHECK constraint, mas validação adicional no trigger)
    IF NEW.corrected_by IS NOT NULL AND NEW.is_corrected = false THEN
        RAISE EXCEPTION 'Event with corrected_by must have is_corrected = true';
    END IF;
    
    -- Nota: Cadeias de correções são permitidas (ex: A corrigido por B, B corrigido por C)
    -- Backend não bloqueia cadeias, cliente decide lógica de domínio
    
    RETURN NEW;
END;
$$;

-- Trigger to validate correction integrity
DROP TRIGGER IF EXISTS validate_correction_integrity_trigger ON sleep_events;
CREATE TRIGGER validate_correction_integrity_trigger
    BEFORE INSERT OR UPDATE ON sleep_events
    FOR EACH ROW
    EXECUTE FUNCTION validate_correction_integrity();

-- ============================================
-- Trigger: Enforce immutability of critical columns
-- ============================================

-- Function to enforce immutability in babies
CREATE OR REPLACE FUNCTION enforce_babies_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.created_by != NEW.created_by THEN
        RAISE EXCEPTION 'Cannot change created_by in babies';
    END IF;
    IF OLD.created_at != NEW.created_at THEN
        RAISE EXCEPTION 'Cannot change created_at in babies';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_babies_immutability_trigger ON babies;
CREATE TRIGGER enforce_babies_immutability_trigger
    BEFORE UPDATE ON babies
    FOR EACH ROW
    EXECUTE FUNCTION enforce_babies_immutability();

-- Function to enforce immutability in sleep_events
CREATE OR REPLACE FUNCTION enforce_sleep_events_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.id != NEW.id THEN
        RAISE EXCEPTION 'Cannot change id in sleep_events';
    END IF;
    IF OLD.baby_id != NEW.baby_id THEN
        RAISE EXCEPTION 'Cannot change baby_id in sleep_events';
    END IF;
    IF OLD.type != NEW.type THEN
        RAISE EXCEPTION 'Cannot change type in sleep_events';
    END IF;
    IF OLD.timestamp != NEW.timestamp THEN
        RAISE EXCEPTION 'Cannot change timestamp in sleep_events';
    END IF;
    IF OLD.caregiver_id != NEW.caregiver_id THEN
        RAISE EXCEPTION 'Cannot change caregiver_id in sleep_events';
    END IF;
    IF OLD.created_at != NEW.created_at THEN
        RAISE EXCEPTION 'Cannot change created_at in sleep_events';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_sleep_events_immutability_trigger ON sleep_events;
CREATE TRIGGER enforce_sleep_events_immutability_trigger
    BEFORE UPDATE ON sleep_events
    FOR EACH ROW
    EXECUTE FUNCTION enforce_sleep_events_immutability();

-- ============================================
-- Trigger: Update device last_seen_at (Opcional no MVP)
-- Secção 1.4: Device (Opcional no MVP)
-- Comentado: Pode ser ativado se necessário para auditoria avançada
-- ============================================

-- Function to update devices.last_seen_at
-- Device é auto-criado quando primeiro usado em um evento
-- Simplifica código cliente, não requer registo separado de dispositivo
-- COMENTADO: Opcional no MVP, pode ser ativado se necessário
/*
CREATE OR REPLACE FUNCTION update_device_last_seen()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE devices
    SET last_seen_at = NOW()
    WHERE device_id = NEW.device_id;
    
    INSERT INTO devices (device_id, user_id, last_seen_at, created_at)
    SELECT NEW.device_id, c.user_id, NOW(), NOW()
    FROM caregivers c
    WHERE c.id = NEW.caregiver_id
      AND NOT EXISTS (
          SELECT 1 FROM devices WHERE device_id = NEW.device_id
      )
    ON CONFLICT (device_id) DO UPDATE
    SET last_seen_at = NOW();
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_device_on_event
    AFTER INSERT ON sleep_events
    FOR EACH ROW
    EXECUTE FUNCTION update_device_last_seen();
*/
