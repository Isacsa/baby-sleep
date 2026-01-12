# Mapeamento: Especificação Conceitual → Implementação SQL

Este documento mapeia cada secção da especificação conceitual para a implementação SQL correspondente.

## 1. Entidades Persistidas

### 1.1 Baby (Bebé)
**Especificação**: Secção 1.1  
**Implementação**: `001_create_tables.sql` - Tabela `babies`

| Campo Especificado | Campo SQL | Status |
|-------------------|-----------|--------|
| `id` (obrigatório) | `id UUID PRIMARY KEY` | ✅ |
| `name` (obrigatório) | `name TEXT NOT NULL` | ✅ |
| `created_at` (obrigatório) | `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` | ✅ |
| `created_by` (obrigatório) | `created_by UUID NOT NULL REFERENCES auth.users(id)` | ✅ |
| `birth_date` (opcional) | `birth_date DATE` | ✅ |
| `updated_at` (opcional) | `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` | ✅ |
| `deleted_at` (opcional) | `deleted_at TIMESTAMPTZ` | ✅ |

**Regras de Negócio**:
- ✅ Soft delete obrigatório (sem DELETE físico)
- ✅ Pelo menos um cuidador owner (garantido por trigger)
- ✅ Criador torna-se primeiro owner (trigger `create_first_caregiver_trigger`)

### 1.2 Caregiver (Cuidador)
**Especificação**: Secção 1.2  
**Implementação**: `001_create_tables.sql` - Tabela `caregivers`

| Campo Especificado | Campo SQL | Status |
|-------------------|-----------|--------|
| `id` (obrigatório) | `id UUID PRIMARY KEY` | ✅ |
| `baby_id` (obrigatório) | `baby_id UUID NOT NULL REFERENCES babies(id)` | ✅ |
| `user_id` (obrigatório) | `user_id UUID NOT NULL REFERENCES auth.users(id)` | ✅ |
| `role` (obrigatório) | `role TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer'))` | ✅ |
| `created_at` (obrigatório) | `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` | ✅ |
| `updated_at` (obrigatório) | `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` | ✅ |
| `invited_by` (opcional) | `invited_by UUID REFERENCES auth.users(id)` | ✅ |
| `deleted_at` (opcional) | `deleted_at TIMESTAMPTZ` | ✅ |

**Regras de Negócio**:
- ✅ UNIQUE(baby_id, user_id) - um utilizador por bebé
- ✅ Não pode haver zero owners (trigger `ensure_at_least_one_owner_trigger`)
- ✅ Soft delete apenas

### 1.3 SleepEvent (Evento de Sono)
**Especificação**: Secção 1.3  
**Implementação**: `001_create_tables.sql` - Tabela `sleep_events`

| Campo Especificado | Campo SQL | Status |
|-------------------|-----------|--------|
| `id` (obrigatório, gerado localmente) | `id UUID PRIMARY KEY` | ✅ |
| `baby_id` (obrigatório) | `baby_id UUID NOT NULL REFERENCES babies(id)` | ✅ |
| `type` (obrigatório) | `type TEXT NOT NULL CHECK (type IN ('SleepStart', 'SleepEnd'))` | ✅ |
| `timestamp` (obrigatório) | `timestamp TIMESTAMPTZ NOT NULL` | ✅ |
| `caregiver_id` (obrigatório) | `caregiver_id UUID NOT NULL REFERENCES caregivers(id)` | ✅ |
| `device_id` (obrigatório) | `device_id TEXT NOT NULL` | ✅ |
| `created_at` (obrigatório) | `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` | ✅ |
| `is_corrected` (obrigatório) | `is_corrected BOOLEAN NOT NULL DEFAULT false` | ✅ |
| `synced_at` (opcional) | `synced_at TIMESTAMPTZ` | ✅ |
| `corrected_by` (opcional) | `corrected_by UUID REFERENCES sleep_events(id)` | ✅ |
| `metadata` (opcional) | `metadata JSONB` | ✅ |

**Regras de Negócio**:
- ✅ UNIQUE(id) - idempotência
- ✅ `timestamp` é fonte de verdade (não `created_at`)
- ✅ Correções criam novo evento
- ✅ Múltiplos eventos com mesmo `timestamp` permitidos
- ✅ Nunca DELETE físico

### 1.4 Device (Dispositivo)
**Especificação**: Secção 1.4  
**Implementação**: `001_create_tables.sql` - Tabela `devices`

| Campo Especificado | Campo SQL | Status |
|-------------------|-----------|--------|
| `id` (obrigatório) | `id UUID PRIMARY KEY` | ✅ |
| `device_id` (obrigatório) | `device_id TEXT UNIQUE NOT NULL` | ✅ |
| `user_id` (obrigatório) | `user_id UUID NOT NULL REFERENCES auth.users(id)` | ✅ |
| `last_seen_at` (obrigatório) | `last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` | ✅ |
| `created_at` (obrigatório) | `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` | ✅ |
| `name` (opcional) | `name TEXT` | ✅ |

## 2. Relações entre Entidades

**Especificação**: Secção 2  
**Implementação**: Foreign Keys em `001_create_tables.sql`

| Relação Especificada | Implementação SQL | Status |
|---------------------|------------------|--------|
| auth.users → Caregiver (1:N) | `caregivers.user_id REFERENCES auth.users(id)` | ✅ |
| Caregiver → Baby (N:1) | `caregivers.baby_id REFERENCES babies(id)` | ✅ |
| Baby → SleepEvent (1:N) | `sleep_events.baby_id REFERENCES babies(id)` | ✅ |
| Caregiver → SleepEvent (1:N) | `sleep_events.caregiver_id REFERENCES caregivers(id)` | ✅ |
| SleepEvent → SleepEvent (self-ref) | `sleep_events.corrected_by REFERENCES sleep_events(id)` | ✅ |

**Integridade Referencial**:
- ✅ Nenhum CASCADE DELETE (soft delete obrigatório)
- ✅ FK obrigatórias (sem NULL)
- ✅ Histórico preservado quando soft deleted

## 3. Campos Obrigatórios

**Especificação**: Secção 3  
**Implementação**: Campos `NOT NULL` em `001_create_tables.sql`

✅ Todos os campos obrigatórios especificados estão marcados como `NOT NULL`  
✅ Todos os campos opcionais estão como `NULL` ou com `DEFAULT`

## 4. Estratégia de Row Level Security

**Especificação**: Secção 4  
**Implementação**: `002_create_rls_policies.sql`

### 4.1 Princípio Base
✅ Todas as tabelas têm RLS ativado (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`)  
✅ Acesso sempre avaliado por `baby_id` via relação `caregivers`

### 4.2 Helper Functions
✅ `is_active_caregiver(baby_uuid, user_uuid)` - Secção 9.4  
✅ `can_write(baby_uuid, user_uuid)` - Secção 9.4  
✅ `is_owner(baby_uuid, user_uuid)` - Secção 9.4  
✅ Todas usam `SECURITY DEFINER` para aceder a `caregivers` dentro de RLS

### 4.3 Políticas por Entidade

#### babies (Secção 4.3.1)
✅ SELECT: Utilizador vê se é caregiver ativo  
✅ INSERT: Utilizador autenticado pode criar, `created_by = auth.uid()`  
✅ UPDATE: Apenas owner/editor, campos imutáveis protegidos, soft delete apenas por owner  
✅ DELETE: Não permitido (apenas soft delete)

#### caregivers (Secção 4.3.2)
✅ SELECT: Próprio ou compartilha mesmo baby_id  
✅ INSERT: Owner/editor pode adicionar, criador pode adicionar primeiro  
✅ UPDATE: Owner altera roles, utilizador atualiza próprios metadados  
✅ DELETE: Não permitido (apenas soft delete)

#### sleep_events (Secção 4.3.3)
✅ SELECT: Caregiver ativo do baby_id  
✅ INSERT: Owner/editor pode criar, validações aplicadas  
✅ UPDATE: Apenas owner/editor, campos imutáveis, apenas criador/owner marca como corrigido  
✅ DELETE: Não permitido (invalidação via `is_corrected`)

### 4.4 Regras por Papel (Secção 4.4)
✅ owner: Permissões totais implementadas  
✅ editor: Permissões limitadas implementadas  
✅ viewer: Apenas read-only implementado

## 5. Representação de Correções e Invalidações

**Especificação**: Secção 5  
**Implementação**: Campos `is_corrected` e `corrected_by` em `sleep_events`

✅ Correções são sempre novos eventos (não edição)  
✅ `is_corrected` marca eventos invalidados  
✅ `corrected_by` rastreia cadeias de correções  
✅ Histórico preservado (nunca DELETE)

## 6. Preparação para Módulos Futuros

**Especificação**: Secção 6  
**Implementação**: Padrão estabelecido, `metadata` JSONB para extensibilidade

✅ Padrão para novos módulos definido  
✅ `metadata` JSONB permite extensibilidade sem alterar schema  
✅ Core (Baby, Caregiver) estável  
✅ Tabelas específicas por módulo (MVP)

## 7. Considerações para Produção

**Especificação**: Secção 7

### 7.1 Idempotência
✅ `id` gerado localmente (UUID v4)  
✅ UNIQUE constraint em `id`  
✅ Sync pode tentar inserir mesmo `id` múltiplas vezes sem duplicar

### 7.2 Sincronização Incremental
✅ `synced_at` permite identificar eventos não sincronizados  
✅ Índice em `synced_at` para queries incrementais

### 7.3 Conflitos
✅ Múltiplos eventos com mesmo `timestamp` permitidos  
✅ Cliente resolve usando `created_at` como desempate

### 7.4 Auditoria Completa
✅ Todos os eventos têm: `caregiver_id`, `created_at`, `device_id`  
✅ Correções rastreáveis via `corrected_by`  
✅ Histórico completo preservado

### 7.5 Soft Delete
✅ `deleted_at` marca remoções  
✅ RLS esconde dados soft deleted  
✅ Permite recuperação futura (GDPR)

### 7.6 Extensibilidade
✅ `metadata` JSONB permite adicionar campos  
✅ Novos módulos seguem padrão estabelecido

## 8. Decisões de Domínio Explícitas

**Especificação**: Secção 8

### 8.1 Geração de IDs
✅ `sleep_event.id` gerado no Flutter (não no backend)  
✅ UUID v4 para unicidade global

### 8.2 Timestamp vs Created At
✅ `timestamp`: Quando ocorreu (fonte de verdade)  
✅ `created_at`: Quando foi criado (auditoria e desempate)

### 8.3 Device ID
✅ String livre (sem validação de formato)  
✅ Cliente garante unicidade

### 8.4 Primeiro Cuidador
✅ Trigger `create_first_caregiver_trigger` auto-cria primeiro owner  
✅ Não requer ação explícita do utilizador

### 8.5 Mínimo de Owners
✅ Trigger `ensure_at_least_one_owner_trigger` impede remoção do último owner

### 8.6 Correções
✅ Sempre novos eventos (nunca edição)  
✅ Histórico preservado  
✅ Rastreável via `corrected_by`  
✅ Filtrado via `is_corrected`

## 9. Pontos de Atenção para Implementação SQL

**Especificação**: Secção 9

### 9.1 Constraints
✅ UNIQUE em `caregiver(baby_id, user_id)`  
✅ UNIQUE em `sleep_event.id`  
✅ CHECK em `caregiver.role`  
✅ CHECK em `sleep_event.type`  
✅ FK obrigatórias (sem NULL)

### 9.2 Índices Críticos
✅ `sleep_event(baby_id, timestamp)` - `idx_sleep_events_baby_timestamp`  
✅ `sleep_event(baby_id, is_corrected, timestamp)` - `idx_sleep_events_baby_valid`  
✅ `caregiver(user_id, deleted_at)` - `idx_caregivers_user_active`  
✅ `caregiver(baby_id, deleted_at)` - `idx_caregivers_baby_active`  
✅ `sleep_event(synced_at)` - `idx_sleep_events_synced_at`

### 9.3 Triggers Necessários
✅ Auto-criar primeiro `caregiver` - `create_first_caregiver_trigger`  
✅ Auto-atualizar `updated_at` - `update_babies_updated_at`, `update_caregivers_updated_at`  
✅ Validar timestamp - `validate_sleep_event_trigger`  
✅ Prevenir remoção do último `owner` - `ensure_at_least_one_owner_trigger`  
✅ Atualizar `synced_at` - via aplicação (não trigger)

### 9.4 Funções Helper para RLS
✅ `is_active_caregiver` - `SECURITY DEFINER`  
✅ `can_write` - `SECURITY DEFINER`  
✅ `is_owner` - `SECURITY DEFINER`

## 10. Validações de Negócio

**Especificação**: Secção 10

### 10.1 Validações no Backend
✅ `baby_id` existe e não está soft deleted - `validate_sleep_event()`  
✅ `caregiver_id` existe, está ativo, e pertence ao `baby_id` - `validate_sleep_event()`  
✅ `caregiver_id.user_id = auth.uid()` - RLS policy  
✅ `type` é válido - CHECK constraint  
✅ `timestamp` é razoável - `validate_sleep_event()` (1 hora futuro, 1 ano passado)

### 10.2 Validações NÃO no Backend
✅ Consistência lógica - cliente decide  
✅ Ordem temporal - cliente ordena  
✅ Duplicados lógicos - permitidos (correções)  
✅ Estado derivado - cliente calcula

## 11. Mapeamento para Requisitos dos Docs

**Especificação**: Secção 11

✅ 01_domain_model.txt - Sistema centrado no bebé, eventos como unidade base  
✅ 02_core_principles.txt - Offline-first, eventos em vez de estados  
✅ 04_data_and_security.txt - RLS por baby_id, auditoria completa  
✅ 03_architecture_overview.txt - Backend não calcula estados, avalia permissões

## 12. Resumo Executivo

**Especificação**: Secção 12

✅ Entidades Core implementadas  
✅ Relações implementadas  
✅ Segurança (RLS) implementada  
✅ Correções implementadas  
✅ Extensibilidade preparada  
✅ **Pronto para SQL**: Todas as decisões de domínio definidas, implementação SQL completa

## Status Final

✅ **100% Alinhado**: Toda a especificação conceitual foi implementada em SQL  
✅ **Sem Ambiguidades**: Todas as decisões de domínio estão explícitas  
✅ **Pronto para Produção**: Schema completo e testado

