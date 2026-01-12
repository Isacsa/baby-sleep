-- Migration: Create indexes for performance
-- Based on: Modelo de Dados e Segurança - Especificação Conceitual, Secção 9.2
-- Description: Creates indexes for common query patterns
-- Índices críticos para: timeline, derivação de estado, queries de cuidadores, sincronização incremental

-- ============================================
-- INDEXES: sleep_events
-- Secção 9.2: Índices Críticos
-- ============================================

-- Índice crítico: Timeline de eventos por bebé
-- Query: SELECT * FROM sleep_events WHERE baby_id = ? ORDER BY timestamp DESC
CREATE INDEX idx_sleep_events_baby_timestamp ON sleep_events(baby_id, timestamp DESC);

-- Índice crítico: Derivação eficiente do estado atual (apenas eventos válidos)
-- Query: SELECT * FROM sleep_events WHERE baby_id = ? AND is_corrected = false ORDER BY timestamp DESC
CREATE INDEX idx_sleep_events_baby_valid ON sleep_events(baby_id, is_corrected, timestamp DESC)
WHERE is_corrected = false;

-- Índice: Eventos por cuidador (para auditoria)
CREATE INDEX idx_sleep_events_caregiver_created ON sleep_events(caregiver_id, created_at DESC);

-- Índice crítico: Sincronização incremental baseada em synced_at
-- Query: SELECT * FROM sleep_events WHERE synced_at IS NULL
CREATE INDEX idx_sleep_events_synced_at ON sleep_events(synced_at)
WHERE synced_at IS NULL;

-- Idempotency (id is already PK, but explicit index for clarity)
-- Note: Primary key already provides unique index on id
-- UNIQUE constraint on sleep_event.id (idempotência)

-- ============================================
-- INDEXES: caregivers
-- Secção 9.2: Índices Críticos
-- ============================================

-- Índice crítico: Queries frequentes de cuidadores por utilizador
-- Query: SELECT * FROM caregivers WHERE user_id = ? AND deleted_at IS NULL
CREATE INDEX idx_caregivers_user_active ON caregivers(user_id, deleted_at)
WHERE deleted_at IS NULL;

-- Índice crítico: Queries frequentes de cuidadores por bebé
-- Query: SELECT * FROM caregivers WHERE baby_id = ? AND deleted_at IS NULL
CREATE INDEX idx_caregivers_baby_active ON caregivers(baby_id, deleted_at)
WHERE deleted_at IS NULL;

-- Unique constraint on (baby_id, user_id) is already enforced by UNIQUE constraint
-- But we can add an index for faster lookups
CREATE INDEX idx_caregivers_baby_user ON caregivers(baby_id, user_id);

-- ============================================
-- INDEXES: babies
-- Secção 9.2: Índices Críticos
-- ============================================

-- Babies created by user
-- babies(created_by) para bebés criados por utilizador
CREATE INDEX idx_babies_created_by ON babies(created_by);

-- Active babies (for filtering)
-- babies(deleted_at) para bebés ativos
CREATE INDEX idx_babies_active ON babies(deleted_at)
WHERE deleted_at IS NULL;

-- ============================================
-- INDEXES: devices
-- ============================================

-- Devices by user
CREATE INDEX idx_devices_user ON devices(user_id);

-- Device lookup by device_id (already unique, but index helps)
-- Note: UNIQUE constraint already provides index on device_id
