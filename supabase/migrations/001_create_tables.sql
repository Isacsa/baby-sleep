-- Migration: Create base tables for MVP Sono
-- Based on: Modelo de Dados e Segurança - Especificação Conceitual
-- Description: Creates babies, caregivers, sleep_events, and devices tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- Table: babies
-- Natureza: Entidade central do sistema. Representa uma criança real.
-- ============================================
CREATE TABLE babies (
    -- Campos obrigatórios
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    
    -- Campos opcionais
    birth_date DATE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- ============================================
-- Table: caregivers
-- Natureza: Relação entre um utilizador autenticado e um bebé. Define permissões e acesso.
-- ============================================
CREATE TABLE caregivers (
    -- Campos obrigatórios
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    baby_id UUID NOT NULL REFERENCES babies(id),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    role TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Campos opcionais
    invited_by UUID REFERENCES auth.users(id),
    deleted_at TIMESTAMPTZ,
    
    -- Constraints
    UNIQUE(baby_id, user_id) -- Um utilizador só pode ter uma relação por bebé
);

-- ============================================
-- Table: sleep_events
-- Natureza: Unidade base de dados do sistema. Representa um acontecimento registado no tempo.
-- ============================================
CREATE TABLE sleep_events (
    -- Campos obrigatórios
    id UUID PRIMARY KEY, -- Gerado localmente no Flutter antes de sync, para idempotência
    baby_id UUID NOT NULL REFERENCES babies(id),
    type TEXT NOT NULL CHECK (type IN ('SleepStart', 'SleepEnd')),
    timestamp TIMESTAMPTZ NOT NULL, -- Quando o evento ocorreu (UTC, fonte de verdade para ordem)
    caregiver_id UUID NOT NULL REFERENCES caregivers(id),
    device_id TEXT NOT NULL, -- Identificador do dispositivo de origem (string, formato livre)
    created_at TIMESTAMPTZ NOT NULL, -- Quando foi criado localmente no dispositivo (obrigatório, fornecido pelo cliente, não sobrescrito pelo backend)
    is_corrected BOOLEAN NOT NULL DEFAULT false, -- Boolean indicando se foi invalidado por correção
    
    -- Campos opcionais
    synced_at TIMESTAMPTZ, -- Timestamp de quando foi sincronizado (NULL = não sincronizado)
    corrected_by UUID REFERENCES sleep_events(id), -- Referência ao evento de correção que invalidou este
    metadata JSONB, -- Estrutura flexível para metadados adicionais
    
    -- Constraints
    UNIQUE(id), -- Idempotência garantida por ID único
    -- Integridade: Se corrected_by IS NOT NULL, então is_corrected = true
    CHECK (
        (corrected_by IS NULL) OR 
        (corrected_by IS NOT NULL AND is_corrected = true)
    )
);

-- ============================================
-- Table: devices (Opcional no MVP)
-- Natureza: Rastreamento de dispositivos conhecidos para auditoria e segurança avançada.
-- ============================================
CREATE TABLE devices (
    -- Campos obrigatórios
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT UNIQUE NOT NULL, -- Deve corresponder ao usado em eventos
    user_id UUID NOT NULL REFERENCES auth.users(id),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Campos opcionais
    name TEXT -- Nome amigável do dispositivo (ex: "iPhone de Maria")
);

-- ============================================
-- Enable Row Level Security
-- Todas as tabelas têm RLS ativado. Acesso é sempre avaliado por baby_id via relação caregivers.
-- ============================================
ALTER TABLE babies ENABLE ROW LEVEL SECURITY;
ALTER TABLE caregivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sleep_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- ============================================
-- Comments for documentation
-- ============================================
COMMENT ON TABLE babies IS 'Entidade central do sistema. Representa uma criança real. É o agregador principal de todos os dados.';
COMMENT ON TABLE caregivers IS 'Relação entre um utilizador autenticado e um bebé. Define permissões (owner, editor, viewer).';
COMMENT ON TABLE sleep_events IS 'Unidade base de dados do sistema. Representa um acontecimento registado no tempo. Eventos são a unidade base, não estados finais.';
COMMENT ON TABLE devices IS 'Rastreamento de dispositivos conhecidos para auditoria e segurança avançada. Opcional no MVP.';

COMMENT ON COLUMN babies.deleted_at IS 'Soft delete timestamp (NULL = ativo). Nenhum dado é eliminado fisicamente.';
COMMENT ON COLUMN caregivers.deleted_at IS 'Soft delete timestamp (NULL = ativo). Quando soft deleted, mantém-se histórico mas perde acesso.';
COMMENT ON COLUMN sleep_events.id IS 'Identificador único gerado localmente no Flutter antes de sync, para idempotência no sync offline. UUID v4.';
COMMENT ON COLUMN sleep_events.timestamp IS 'Quando o evento ocorreu (UTC). Fonte de verdade para ordem lógica. Pode ser diferente de created_at para correções retroativas.';
COMMENT ON COLUMN sleep_events.created_at IS 'Quando foi criado localmente no dispositivo. Obrigatório, fornecido pelo cliente, não sobrescrito pelo backend. Usado para auditoria e desempate em conflitos.';
COMMENT ON COLUMN sleep_events.is_corrected IS 'Boolean indicando se este evento foi invalidado por uma correção. Correções são sempre novos eventos.';
COMMENT ON COLUMN sleep_events.corrected_by IS 'Referência ao evento de correção que invalidou este (NULL se não foi corrigido). Permite rastrear cadeias de correções.';
COMMENT ON COLUMN sleep_events.synced_at IS 'Timestamp de quando foi sincronizado com backend (NULL = não sincronizado). Permite sincronização incremental.';
COMMENT ON COLUMN sleep_events.metadata IS 'Estrutura flexível para metadados adicionais (timezone, versão app, etc.). Permite extensibilidade sem alterar schema.';
