# Supabase Database Schema

This directory contains the database migrations for the Baby Sleep Monitor MVP.

**Baseado em**: Modelo de Dados e Segurança - Especificação Conceitual

## Estrutura

- `migrations/` - Ficheiros SQL de migração em ordem de execução
  - `001_create_tables.sql` - Cria tabelas base (babies, caregivers, sleep_events, devices)
  - `002_create_rls_policies.sql` - Implementa políticas Row Level Security
  - `003_create_indexes.sql` - Cria índices de performance
  - `004_create_triggers.sql` - Cria triggers para atualizações automáticas e validações

## Entidades

### babies
Entidade central do sistema. Representa uma criança real. É o agregador principal de todos os dados.

### caregivers
Relação entre um utilizador autenticado e um bebé. Define permissões (owner, editor, viewer).

### sleep_events
Unidade base de dados do sistema. Representa um acontecimento registado no tempo. Eventos são a unidade base, não estados finais.

### devices (Opcional)
Rastreamento de dispositivos conhecidos para auditoria e segurança avançada.

## Segurança

Todas as tabelas têm Row Level Security (RLS) ativado. Acesso é sempre avaliado por `baby_id` via relação `caregivers`.

### Papéis

- **owner**: Acesso total, pode gerir cuidadores, soft delete do bebé
- **editor**: Pode criar/editar eventos, adicionar cuidadores (viewer/editor apenas)
- **viewer**: Acesso read-only

## Princípios de Design

### Offline-First
- IDs de eventos gerados localmente no Flutter (UUID v4)
- `synced_at` permite sincronização incremental
- Idempotência garantida por UNIQUE constraint em `id`

### Eventos em vez de Estados
- Estados são sempre derivados da sequência de eventos
- Correções são sempre novos eventos (nunca edição)
- Histórico nunca é apagado silenciosamente

### Soft Delete
- Nenhum dado é eliminado fisicamente
- `deleted_at` marca remoções
- RLS esconde dados soft deleted
- Permite recuperação futura (GDPR)

### Extensibilidade
- `metadata` JSONB permite adicionar campos sem alterar schema
- Novos módulos seguem mesmo padrão (Baby, Caregiver, Eventos)
- Core (Baby, Caregiver) permanece estável

## Aplicar Migrações

### Usando Supabase CLI (Recomendado)

> **Nota:** Este projeto está organizado em monorepo. As migrations estão em `backend/supabase/`.

**Opção 1: Usar script wrapper (recomendado)**
```bash
# Da raiz do monorepo
./scripts/apply-migrations.sh
```

**Opção 2: Navegar para o diretório**
```bash
# Navegar para backend/supabase
cd /path/to/baby-sleep/backend/supabase

# Ligar ao projeto Supabase (se ainda não ligado)
supabase link --project-ref your-project-ref

# Aplicar migrações ao remoto
supabase db push
```

**Opção 3: Usar flags explícitos (sem config.toml)**
```bash
# Se não tiver config.toml, usar flags diretamente
supabase db push --project-ref your-project-ref --db-url postgresql://...
```

### Nota sobre config.toml

Este projeto não inclui `config.toml` por padrão. Se preferires usar o Supabase CLI com configuração local:
```bash
cd backend/supabase
supabase init  # Gera config.toml
supabase link --project-ref your-project-ref
```

### Usando Supabase Dashboard

1. Abrir dashboard do projeto Supabase
2. Navegar para **SQL Editor**
3. Executar cada ficheiro de migração por ordem:
   - `001_create_tables.sql`
   - `002_create_rls_policies.sql`
   - `003_create_indexes.sql`
   - `004_create_triggers.sql`

**Importante**: Executar migrações nesta ordem exata!

## Verificação

Após aplicar migrações, verificar a configuração:

```sql
-- Verificar tabelas existem
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('babies', 'caregivers', 'sleep_events', 'devices');

-- Verificar RLS está ativado
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('babies', 'caregivers', 'sleep_events', 'devices');
-- Todos devem mostrar rowsecurity = true

-- Verificar políticas existem
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Verificar índices existem
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN ('babies', 'caregivers', 'sleep_events', 'devices');
```

## Teste Rápido

Criar um bebé de teste e verificar que tudo funciona:

```sql
-- Como utilizador autenticado, criar um bebé
INSERT INTO babies (name, created_by) 
VALUES ('Test Baby', auth.uid())
RETURNING id, name;

-- Verificar primeiro cuidador (owner) foi auto-criado
SELECT c.*, b.name as baby_name
FROM caregivers c
JOIN babies b ON c.baby_id = b.id
WHERE b.name = 'Test Baby';

-- Deve mostrar um cuidador com role 'owner'
```

## Próximos Passos

1. **Configurar Autenticação**: Configurar Supabase Auth com provider preferido
2. **Testar Políticas RLS**: Ver `TESTING.md` para cenários de teste completos
3. **Revisar Implementação**: Ver `IMPLEMENTATION_NOTES.md` para decisões de design
4. **Iniciar Desenvolvimento Flutter**: Schema de base de dados está pronto para integração com app Flutter

## Documentação Adicional

- **Guia de Testes**: `TESTING.md` - Cenários de teste e exemplos SQL
- **Notas de Implementação**: `IMPLEMENTATION_NOTES.md` - Decisões de design e mapeamento
- **Guia Rápido**: `QUICK_START.md` - Guia rápido para aplicar migrações
