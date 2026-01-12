-- Migration: Create Row Level Security policies
-- Based on: RLS_POLICIES_SPECIFICATION.md
-- Description: Implements RLS policies for all tables based on caregiver relationships

-- ============================================
-- A) HELPER FUNCTIONS
-- Funções SECURITY DEFINER com search_path fixo para segurança
-- ============================================

-- Helper function: Check if user is an active caregiver for a baby
-- Valida acesso via caregivers e verifica que baby não está soft deleted
CREATE OR REPLACE FUNCTION is_active_caregiver(baby_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM caregivers c
        INNER JOIN babies b ON c.baby_id = b.id
        WHERE c.baby_id = baby_uuid
          AND c.user_id = user_uuid
          AND c.deleted_at IS NULL
          AND b.deleted_at IS NULL
    );
END;
$$;

-- Helper function: Check if user can write (owner or editor)
-- Valida permissões de escrita e verifica que baby não está soft deleted
CREATE OR REPLACE FUNCTION can_write(baby_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM caregivers c
        INNER JOIN babies b ON c.baby_id = b.id
        WHERE c.baby_id = baby_uuid
          AND c.user_id = user_uuid
          AND c.role IN ('owner', 'editor')
          AND c.deleted_at IS NULL
          AND b.deleted_at IS NULL
    );
END;
$$;

-- Helper function: Check if user is owner
-- Valida permissões de owner e verifica que baby não está soft deleted
CREATE OR REPLACE FUNCTION is_owner(baby_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM caregivers c
        INNER JOIN babies b ON c.baby_id = b.id
        WHERE c.baby_id = baby_uuid
          AND c.user_id = user_uuid
          AND c.role = 'owner'
          AND c.deleted_at IS NULL
          AND b.deleted_at IS NULL
    );
END;
$$;

-- ============================================
-- B) RLS POLICIES
-- Políticas por tabela: SELECT, INSERT, UPDATE (sem DELETE)
-- ============================================

-- ============================================
-- B.1) POLICIES: babies
-- ============================================

-- SELECT: Utilizador vê bebé se é cuidador ativo e bebé não está soft deleted
CREATE POLICY "Users can view babies they care for"
    ON babies FOR SELECT
    USING (
        deleted_at IS NULL AND
        is_active_caregiver(id, auth.uid())
    );

-- INSERT: Utilizador autenticado pode criar bebé, created_by deve ser auth.uid()
CREATE POLICY "Users can create babies"
    ON babies FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL AND
        created_by = auth.uid()
    );

-- UPDATE: Owner/editor pode atualizar, apenas owner pode soft delete
-- Imutabilidade de created_by e created_at garantida por trigger
CREATE POLICY "Owners and editors can update babies"
    ON babies FOR UPDATE
    USING (
        deleted_at IS NULL AND
        can_write(id, auth.uid())
    )
    WITH CHECK (
        can_write(id, auth.uid()) AND
        (deleted_at IS NULL OR (deleted_at IS NOT NULL AND is_owner(id, auth.uid())))
    );

-- ============================================
-- B.2) POLICIES: caregivers
-- ============================================

-- SELECT: Utilizador vê seus próprios cuidadores ou cuidadores do mesmo bebé
CREATE POLICY "Users can view their own caregivers or caregivers of their babies"
    ON caregivers FOR SELECT
    USING (
        deleted_at IS NULL AND
        (user_id = auth.uid() OR is_active_caregiver(baby_id, auth.uid()))
    );

-- INSERT: Owner/editor pode adicionar cuidadores, criador pode auto-adicionar-se como primeiro owner
CREATE POLICY "Owners, editors, or baby creator can add caregivers"
    ON caregivers FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL AND
        (
            -- Auto-criação do primeiro cuidador (via trigger)
            (
                user_id = auth.uid() AND
                EXISTS (
                    SELECT 1 FROM babies
                    WHERE id = baby_id
                      AND created_by = auth.uid()
                      AND deleted_at IS NULL
                ) AND
                NOT EXISTS (
                    SELECT 1 FROM caregivers
                    WHERE baby_id = caregivers.baby_id
                      AND deleted_at IS NULL
                ) AND
                role = 'owner'
            ) OR
            -- Owner/editor adiciona novo cuidador
            (
                can_write(baby_id, auth.uid()) AND
                (role != 'owner' OR is_owner(baby_id, auth.uid()))
            )
        )
    );

-- UPDATE: Owner pode alterar roles de outros, utilizador pode atualizar próprios metadados
-- Apenas owner pode soft delete outros cuidadores (não pode remover-se)
CREATE POLICY "Owners can update caregiver roles, users can update own metadata"
    ON caregivers FOR UPDATE
    USING (
        deleted_at IS NULL AND
        (is_owner(baby_id, auth.uid()) AND user_id != auth.uid() OR user_id = auth.uid())
    )
    WITH CHECK (
        (is_owner(baby_id, auth.uid()) AND user_id != auth.uid() OR user_id = auth.uid()) AND
        (deleted_at IS NULL OR (deleted_at IS NOT NULL AND is_owner(baby_id, auth.uid()) AND user_id != auth.uid()))
    );

-- ============================================
-- B.3) POLICIES: sleep_events
-- ============================================

-- SELECT: Utilizador vê eventos se é cuidador ativo do baby_id (todos os papéis podem ver)
CREATE POLICY "Users can view events for babies they care for"
    ON sleep_events FOR SELECT
    USING (is_active_caregiver(baby_id, auth.uid()));

-- INSERT: Owner/editor pode criar evento, caregiver_id deve pertencer ao auth.uid()
CREATE POLICY "Owners and editors can create events"
    ON sleep_events FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL AND
        can_write(baby_id, auth.uid()) AND
        EXISTS (
            SELECT 1 FROM caregivers
            WHERE id = caregiver_id
              AND user_id = auth.uid()
              AND deleted_at IS NULL
        )
    );

-- UPDATE: Owner/editor pode atualizar eventos
-- Imutabilidade de campos críticos (id, baby_id, type, timestamp, caregiver_id, created_at) garantida por trigger
-- Validação de quem pode marcar como corrigido pode ser feita no trigger se necessário
CREATE POLICY "Owners and editors can update events"
    ON sleep_events FOR UPDATE
    USING (can_write(baby_id, auth.uid()))
    WITH CHECK (can_write(baby_id, auth.uid()));

-- ============================================
-- B.4) POLICIES: devices
-- ============================================

-- SELECT: Utilizador vê apenas seus próprios dispositivos
CREATE POLICY "Users can view their own devices"
    ON devices FOR SELECT
    USING (user_id = auth.uid());

-- INSERT: Utilizador pode criar seus próprios dispositivos
CREATE POLICY "Users can create their own devices"
    ON devices FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- UPDATE: Utilizador pode atualizar seus próprios dispositivos
CREATE POLICY "Users can update their own devices"
    ON devices FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================
-- C) TRIGGERS AND FUNCTIONS
-- Triggers para primeiro caregiver, último owner, e imutabilidade
-- ============================================

-- ============================================
-- C.1) TRIGGER: Auto-create first caregiver (owner) when baby is created
-- ============================================

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

CREATE TRIGGER create_first_caregiver_trigger
    AFTER INSERT ON babies
    FOR EACH ROW
    EXECUTE FUNCTION create_first_caregiver();

-- ============================================
-- C.2) TRIGGER: Prevent removing last owner
-- ============================================

CREATE OR REPLACE FUNCTION ensure_at_least_one_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
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

CREATE TRIGGER ensure_at_least_one_owner_trigger
    BEFORE UPDATE ON caregivers
    FOR EACH ROW
    EXECUTE FUNCTION ensure_at_least_one_owner();

-- ============================================
-- C.3) TRIGGER: Enforce immutability of critical columns
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

CREATE TRIGGER enforce_sleep_events_immutability_trigger
    BEFORE UPDATE ON sleep_events
    FOR EACH ROW
    EXECUTE FUNCTION enforce_sleep_events_immutability();
