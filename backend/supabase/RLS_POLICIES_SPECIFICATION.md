# Especificação de Políticas Row Level Security (RLS)

Este documento descreve as políticas RLS para o MVP de Sono, alinhadas com o modelo de dados fechado.

## Princípios Base

### Acesso via Caregivers
- **Todas as tabelas têm RLS ativado**
- **Acesso é sempre avaliado por `baby_id` via relação `caregivers`**
- Utilizador só acede a dados se existe `caregiver` ativo (não soft deleted) para o `baby_id`
- Acesso nunca é direto, sempre através da relação `caregiver`

### Autenticação
- Todas as políticas assumem utilizador autenticado (`auth.uid()` disponível)
- Operações sem autenticação são bloqueadas por padrão (RLS bloqueia sem policy)

### Soft Delete
- Dados soft deleted (`deleted_at IS NOT NULL`) não são visíveis via SELECT
- Soft delete é feito via UPDATE (definir `deleted_at`), nunca DELETE físico
- Histórico preservado, mas acesso bloqueado

## Helper Functions Necessárias

### is_active_caregiver(baby_id, user_id)
**Propósito**: Verifica se utilizador é cuidador ativo de um bebé.

**Lógica**:
- Verifica se existe `caregiver` onde:
  - `caregiver.baby_id = baby_id`
  - `caregiver.user_id = user_id`
  - `caregiver.deleted_at IS NULL`

**Uso**: Validação de acesso em todas as políticas SELECT.

**Nota Supabase**: Deve usar `SECURITY DEFINER` para aceder a `caregivers` dentro de RLS.

### can_write(baby_id, user_id)
**Propósito**: Verifica se utilizador pode escrever (owner ou editor).

**Lógica**:
- Verifica se existe `caregiver` onde:
  - `caregiver.baby_id = baby_id`
  - `caregiver.user_id = user_id`
  - `caregiver.role IN ('owner', 'editor')`
  - `caregiver.deleted_at IS NULL`

**Uso**: Validação de permissões de escrita em INSERT e UPDATE.

**Nota Supabase**: Deve usar `SECURITY DEFINER` para aceder a `caregivers` dentro de RLS.

### is_owner(baby_id, user_id)
**Propósito**: Verifica se utilizador é owner do bebé.

**Lógica**:
- Verifica se existe `caregiver` onde:
  - `caregiver.baby_id = baby_id`
  - `caregiver.user_id = user_id`
  - `caregiver.role = 'owner'`
  - `caregiver.deleted_at IS NULL`

**Uso**: Validação de permissões especiais de owner (soft delete, alterar roles).

**Nota Supabase**: Deve usar `SECURITY DEFINER` para aceder a `caregivers` dentro de RLS.

## Políticas por Tabela

### 1. Tabela: babies

#### SELECT (Leitura)
**Policy**: "Users can view babies they care for"

**Validação**:
- `baby.deleted_at IS NULL` (bebé não está soft deleted)
- `is_active_caregiver(baby.id, auth.uid())` (utilizador é cuidador ativo)

**Resultado**:
- Utilizador vê apenas bebés onde é cuidador ativo
- Bebés soft deleted não são visíveis
- Todos os papéis (owner, editor, viewer) podem ver

**Nota Supabase**: `USING` clause valida acesso à linha.

#### INSERT (Criação)
**Policy**: "Users can create babies"

**Validação**:
- `auth.uid() IS NOT NULL` (utilizador autenticado)
- `baby.created_by = auth.uid()` (criador é o utilizador atual)

**Resultado**:
- Qualquer utilizador autenticado pode criar bebé
- `created_by` deve ser obrigatoriamente `auth.uid()`
- Após criação, trigger auto-cria primeiro `caregiver` com `role = 'owner'`

**Nota Supabase**: `WITH CHECK` clause valida dados a inserir.

#### UPDATE (Atualização)
**Policy**: "Owners and editors can update babies"

**Validação USING** (acesso à linha):
- `baby.deleted_at IS NULL` (bebé não está soft deleted)
- `can_write(baby.id, auth.uid())` (utilizador é owner ou editor)

**Validação WITH CHECK** (dados após update):
- `can_write(baby.id, auth.uid())` (mantém permissão)
- `baby.created_by = OLD.created_by` (imutável)
- `baby.created_at = OLD.created_at` (imutável)
- Soft delete permitido apenas se:
  - `baby.deleted_at IS NOT NULL` (está a fazer soft delete)
  - `is_owner(baby.id, auth.uid())` (apenas owner pode soft delete)

**Resultado**:
- Owner e editor podem atualizar campos (exceto `created_by`, `created_at`)
- Apenas owner pode fazer soft delete
- Campos imutáveis protegidos

**Nota Supabase**: `USING` valida acesso, `WITH CHECK` valida dados.

#### DELETE (Eliminação)
**Policy**: Nenhuma (RLS bloqueia por padrão)

**Resultado**:
- DELETE físico nunca permitido
- Soft delete via UPDATE apenas

---

### 2. Tabela: caregivers

#### SELECT (Leitura)
**Policy**: "Users can view their own caregivers or caregivers of their babies"

**Validação**:
- `caregiver.deleted_at IS NULL` (cuidador não está soft deleted)
- E uma das condições:
  - `caregiver.user_id = auth.uid()` (é o próprio cuidador), OU
  - `is_active_caregiver(caregiver.baby_id, auth.uid())` (é cuidador do mesmo bebé)

**Resultado**:
- Utilizador vê seus próprios cuidadores
- Utilizador vê outros cuidadores do mesmo bebé (para coordenação)
- Cuidadores soft deleted não são visíveis
- Todos os papéis podem ver

**Nota Supabase**: Permite ver outros cuidadores do mesmo bebé para coordenação multi-cuidador.

#### INSERT (Criação)
**Policy**: "Owners, editors, or baby creator can add caregivers"

**Validação**:
- `auth.uid() IS NOT NULL` (utilizador autenticado)
- E uma das condições:
  
  **Caso 1: Auto-criação do primeiro cuidador (via trigger)**
  - `caregiver.user_id = auth.uid()` (adicionando-se)
  - `baby.created_by = auth.uid()` (é criador do bebé)
  - Não existem cuidadores ativos ainda (primeiro cuidador)
  - `caregiver.role = 'owner'` (primeiro deve ser owner)
  
  **Caso 2: Owner/editor adiciona novo cuidador**
  - `can_write(caregiver.baby_id, auth.uid())` (é owner ou editor)
  - Se `caregiver.role = 'owner'`, então `is_owner(caregiver.baby_id, auth.uid())` (apenas owner pode adicionar owner)

**Resultado**:
- Criador do bebé pode auto-adicionar-se como primeiro owner (via trigger)
- Owner pode adicionar qualquer papel (owner, editor, viewer)
- Editor pode adicionar apenas editor ou viewer (não owner)
- Utilizador não pode adicionar-se diretamente como owner (exceto via trigger)

**Nota Supabase**: Policy permite trigger criar primeiro cuidador, mas valida adições manuais.

#### UPDATE (Atualização)
**Policy**: "Owners can update caregiver roles, users can update own metadata"

**Validação USING** (acesso à linha):
- `caregiver.deleted_at IS NULL` (não está soft deleted)
- E uma das condições:
  - `is_owner(caregiver.baby_id, auth.uid()) AND caregiver.user_id != auth.uid()` (owner alterando outro), OU
  - `caregiver.user_id = auth.uid()` (alterando próprio)

**Validação WITH CHECK** (dados após update):
- Mantém mesma condição de acesso (owner ou próprio)
- Soft delete permitido apenas se:
  - `caregiver.deleted_at IS NOT NULL` (está a fazer soft delete)
  - `is_owner(caregiver.baby_id, auth.uid())` (apenas owner)
  - `caregiver.user_id != auth.uid()` (não pode remover-se)

**Resultado**:
- Owner pode alterar `role` de outros cuidadores
- Utilizador pode atualizar seus próprios metadados (mas não `role`)
- Apenas owner pode fazer soft delete de outros cuidadores
- Utilizador não pode remover-se (soft delete próprio)
- Trigger impede remoção do último owner

**Nota Supabase**: Policy permite owner alterar roles, mas trigger garante mínimo de owners.

#### DELETE (Eliminação)
**Policy**: Nenhuma (RLS bloqueia por padrão)

**Resultado**:
- DELETE físico nunca permitido
- Soft delete via UPDATE apenas

---

### 3. Tabela: sleep_events

#### SELECT (Leitura)
**Policy**: "Users can view events for babies they care for"

**Validação**:
- `is_active_caregiver(event.baby_id, auth.uid())` (utilizador é cuidador ativo do bebé)

**Resultado**:
- Utilizador vê eventos se é cuidador ativo do `baby_id` do evento
- Eventos de bebés soft deleted não são visíveis (via RLS em `babies`)
- Todos os papéis (owner, editor, viewer) podem ver eventos
- Eventos corrigidos (`is_corrected = true`) são visíveis (filtrados na aplicação)

**Nota Supabase**: Não precisa verificar `deleted_at` em `babies` aqui, RLS em `babies` já bloqueia acesso.

#### INSERT (Criação)
**Policy**: "Owners and editors can create events"

**Validação**:
- `auth.uid() IS NOT NULL` (utilizador autenticado)
- `can_write(event.baby_id, auth.uid())` (utilizador é owner ou editor do bebé)
- Existe `caregiver` onde:
  - `caregiver.id = event.caregiver_id`
  - `caregiver.user_id = auth.uid()` (caregiver_id corresponde ao utilizador atual)
  - `caregiver.deleted_at IS NULL` (caregiver está ativo)

**Resultado**:
- Apenas owner e editor podem criar eventos (viewer não pode)
- `caregiver_id` deve corresponder a uma relação válida do utilizador atual
- Garante que eventos só podem ser criados pelo próprio cuidador
- `id` deve ser único (idempotência)
- `timestamp` pode ser no passado (correções retroativas) ou presente
- `created_at` é fornecido pelo cliente (não tem default)

**Nota Supabase**: Validação explícita de `caregiver.user_id = auth.uid()` garante que utilizador não pode criar eventos com `caregiver_id` de outro utilizador.

#### UPDATE (Atualização)
**Policy**: "Owners and editors can update events"

**Validação USING** (acesso à linha):
- `can_write(event.baby_id, auth.uid())` (utilizador é owner ou editor do bebé)

**Validação WITH CHECK** (dados após update):
- `can_write(event.baby_id, auth.uid())` (mantém permissão)
- Campos imutáveis não podem mudar:
  - `event.id = OLD.id`
  - `event.baby_id = OLD.baby_id`
  - `event.type = OLD.type`
  - `event.timestamp = OLD.timestamp`
  - `event.caregiver_id = OLD.caregiver_id`
  - `event.created_at = OLD.created_at`
- Marcar como corrigido (`is_corrected = true`) apenas se:
  - `event.is_corrected = OLD.is_corrected` (não muda), OU
  - `event.is_corrected = true` E uma das condições:
    - Criador original: existe `caregiver` onde `caregiver.id = OLD.caregiver_id AND caregiver.user_id = auth.uid()`, OU
    - Owner: `is_owner(event.baby_id, auth.uid())`

**Resultado**:
- Owner e editor podem atualizar campos mutáveis (`synced_at`, `is_corrected`, `corrected_by`, `metadata`)
- Campos imutáveis protegidos (nunca podem mudar após criação)
- Apenas criador original ou owner pode marcar como `is_corrected = true`
- `synced_at` é atualizado automaticamente pelo sistema após sync

**Nota Supabase**: Campos imutáveis protegidos via `WITH CHECK` comparando com `OLD`.

#### DELETE (Eliminação)
**Policy**: Nenhuma (RLS bloqueia por padrão)

**Resultado**:
- DELETE físico nunca permitido
- Invalidação via `is_corrected = true` apenas

---

### 4. Tabela: devices

#### SELECT (Leitura)
**Policy**: "Users can view their own devices"

**Validação**:
- `device.user_id = auth.uid()` (dispositivo pertence ao utilizador)

**Resultado**:
- Utilizador vê apenas seus próprios dispositivos
- Não há relação com `baby_id` (dispositivo é do utilizador, não do bebé)

**Nota Supabase**: Policy simples, sem necessidade de helper functions.

#### INSERT (Criação)
**Policy**: "Users can create their own devices"

**Validação**:
- `device.user_id = auth.uid()` (dispositivo pertence ao utilizador)

**Resultado**:
- Utilizador pode criar seus próprios dispositivos
- Dispositivos podem ser auto-criados via trigger quando usado em evento

**Nota Supabase**: Policy simples, sem necessidade de helper functions.

#### UPDATE (Atualização)
**Policy**: "Users can update their own devices"

**Validação USING** (acesso à linha):
- `device.user_id = auth.uid()` (dispositivo pertence ao utilizador)

**Validação WITH CHECK** (dados após update):
- `device.user_id = auth.uid()` (mantém ownership)

**Resultado**:
- Utilizador pode atualizar seus próprios dispositivos
- `user_id` não pode mudar

**Nota Supabase**: Policy simples, sem necessidade de helper functions.

#### DELETE (Eliminação)
**Policy**: Nenhuma (RLS bloqueia por padrão)

**Resultado**:
- DELETE físico nunca permitido (opcional no MVP)

---

## Diferenças de Permissões por Papel

### Papel: owner
**Permissões**:
- ✅ Ver todos os dados do bebé (SELECT)
- ✅ Criar/editar eventos (INSERT/UPDATE em `sleep_events`)
- ✅ Marcar eventos como corrigidos (UPDATE `is_corrected = true`)
- ✅ Adicionar/remover cuidadores (INSERT/UPDATE soft delete em `caregivers`)
- ✅ Alterar papéis de outros cuidadores (UPDATE `role` em `caregivers`)
- ✅ Soft delete do bebé (UPDATE `deleted_at` em `babies`)
- ✅ Atualizar dados do bebé (UPDATE em `babies`)

**Restrições**:
- ❌ Não pode remover último owner (garantido por trigger)
- ❌ Não pode alterar `created_by` do bebé (imutável)
- ❌ Não pode fazer DELETE físico (apenas soft delete)

### Papel: editor
**Permissões**:
- ✅ Ver todos os dados do bebé (SELECT)
- ✅ Criar/editar eventos (INSERT/UPDATE em `sleep_events`)
- ✅ Marcar eventos como corrigidos (UPDATE `is_corrected = true`)
- ✅ Adicionar cuidadores (INSERT em `caregivers`, apenas `viewer` ou `editor`, não `owner`)
- ✅ Atualizar dados do bebé (UPDATE em `babies`, exceto soft delete)

**Restrições**:
- ❌ Não pode remover cuidadores (soft delete)
- ❌ Não pode alterar papéis de outros cuidadores
- ❌ Não pode adicionar `owner` (apenas owner pode)
- ❌ Não pode soft delete do bebé
- ❌ Não pode fazer DELETE físico

### Papel: viewer
**Permissões**:
- ✅ Ver todos os dados do bebé (SELECT em todas as tabelas)

**Restrições**:
- ❌ Não pode criar/editar eventos (INSERT/UPDATE bloqueado)
- ❌ Não pode adicionar/remover cuidadores
- ❌ Qualquer ação de escrita é bloqueada

---

## Como Soft Delete Afeta Visibilidade

### Princípio Geral
- Dados com `deleted_at IS NOT NULL` não são visíveis via SELECT
- Soft delete é feito via UPDATE (definir `deleted_at`), nunca DELETE físico
- Histórico preservado, mas acesso bloqueado

### Por Tabela

#### babies
- Bebé soft deleted: `baby.deleted_at IS NOT NULL`
- **Efeito**: Bebé não aparece em SELECT
- **Cascata**: Todos os dados relacionados (caregivers, events) ficam inacessíveis via RLS
- **Razão**: RLS em `caregivers` e `sleep_events` verifica `is_active_caregiver`, que não encontra cuidadores ativos de bebé soft deleted

#### caregivers
- Cuidador soft deleted: `caregiver.deleted_at IS NOT NULL`
- **Efeito**: Cuidador não aparece em SELECT
- **Cascata**: Utilizador perde acesso a todos os dados do bebé
- **Razão**: Helper functions (`is_active_caregiver`, `can_write`, `is_owner`) verificam `deleted_at IS NULL`
- **Histórico**: Eventos mantêm `caregiver_id` (histórico preservado), mas cuidador não é visível

#### sleep_events
- Eventos nunca são soft deleted diretamente
- **Invalidação**: Via `is_corrected = true` (não é soft delete)
- **Efeito**: Eventos corrigidos são visíveis, mas filtrados na aplicação
- **Razão**: RLS não filtra por `is_corrected`, aplicação decide

#### devices
- Dispositivos não têm soft delete no MVP
- **Efeito**: Sem efeito de soft delete

---

## Garantia: Eventos Só Podem Ser Criados pelo Próprio Cuidador

### Validação em INSERT Policy
**Policy**: "Owners and editors can create events"

**Validação explícita**:
```
EXISTS (
    SELECT 1 FROM caregivers
    WHERE id = event.caregiver_id
      AND user_id = auth.uid()
      AND deleted_at IS NULL
)
```

**Lógica**:
1. `event.caregiver_id` deve existir em `caregivers`
2. `caregiver.user_id` deve ser `auth.uid()` (utilizador atual)
3. `caregiver.deleted_at IS NULL` (cuidador está ativo)

**Resultado**:
- Utilizador não pode criar evento com `caregiver_id` de outro utilizador
- Utilizador não pode criar evento com `caregiver_id` inexistente
- Utilizador não pode criar evento com `caregiver_id` soft deleted
- Garante que `event.caregiver_id` corresponde sempre ao utilizador que cria

**Nota Supabase**: Validação explícita na policy, não apenas foreign key constraint.

---

## Pontos de Atenção Específicos do Supabase

### 1. auth.uid()
**Comportamento**:
- `auth.uid()` retorna UUID do utilizador autenticado
- `auth.uid()` é `NULL` se utilizador não está autenticado
- Disponível em todas as policies

**Uso**:
- Sempre verificar `auth.uid() IS NOT NULL` em INSERT
- Usar `auth.uid()` para comparar com `user_id` e `created_by`

**Nota**: Se `auth.uid()` é `NULL`, RLS bloqueia por padrão (sem policy permite).

### 2. SECURITY DEFINER em Helper Functions
**Problema**:
- Helper functions (`is_active_caregiver`, `can_write`, `is_owner`) precisam aceder a `caregivers`
- Se `caregivers` tem RLS ativado, função pode não conseguir aceder

**Solução**:
- Helper functions devem usar `SECURITY DEFINER`
- Função executa com privilégios do criador, não do chamador
- Permite função aceder a `caregivers` mesmo com RLS ativado

**Nota**: Funções apenas leem dados, nunca modificam, então seguro.

### 3. USING vs WITH CHECK
**USING** (clause):
- Valida acesso à linha existente
- Usado em SELECT (quais linhas pode ver) e UPDATE (quais linhas pode atualizar)
- Executa antes de ler/atualizar linha

**WITH CHECK** (clause):
- Valida dados após operação
- Usado em INSERT (dados a inserir) e UPDATE (dados após update)
- Executa após operação, antes de commit

**Uso**:
- SELECT: apenas `USING`
- INSERT: apenas `WITH CHECK`
- UPDATE: `USING` (acesso) + `WITH CHECK` (dados)

**Nota**: Em UPDATE, `USING` valida acesso, `WITH CHECK` valida dados finais.

### 4. Joins em RLS Policies
**Problema**:
- Policies podem precisar fazer JOIN com outras tabelas
- JOINs podem ser lentos ou complexos

**Solução**:
- Usar helper functions (`SECURITY DEFINER`) para validações complexas
- Helper functions fazem JOINs internamente
- Policies ficam simples e performantes

**Exemplo**:
- Policy: `is_active_caregiver(baby_id, auth.uid())`
- Helper function faz JOIN com `caregivers` internamente

### 5. Performance de Helper Functions
**Consideração**:
- Helper functions são chamadas para cada linha avaliada
- Múltiplas chamadas podem ser lentas

**Otimização**:
- Helper functions usam `EXISTS` (para quando possível)
- Índices em `caregivers(user_id, baby_id, deleted_at)` otimizam queries
- Funções são simples e rápidas

**Nota**: Monitorizar performance em produção, considerar cache se necessário.

### 6. RLS e Foreign Keys
**Comportamento**:
- Foreign keys funcionam normalmente com RLS
- RLS não bloqueia validação de foreign keys
- Foreign keys verificam existência, RLS verifica acesso

**Exemplo**:
- `sleep_events.caregiver_id REFERENCES caregivers(id)`
- Foreign key valida que `caregiver_id` existe
- RLS valida que utilizador pode aceder a esse `caregiver_id`

**Nota**: Foreign keys e RLS trabalham em conjunto, não conflitam.

### 7. Triggers e RLS
**Comportamento**:
- Triggers executam com privilégios do utilizador que disparou
- Triggers respeitam RLS (se tabela tem RLS)
- Triggers podem usar `SECURITY DEFINER` para bypass RLS se necessário

**Exemplo**:
- Trigger `create_first_caregiver_trigger` cria `caregiver` após criar `baby`
- Trigger precisa aceder a `caregivers` para inserir
- Se `caregivers` tem RLS, trigger pode falhar
- Solução: Trigger function usa `SECURITY DEFINER` ou policy permite inserção

**Nota**: Verificar que triggers têm acesso necessário às tabelas.

### 8. Validação de Campos Imutáveis
**Problema**:
- Alguns campos não devem mudar após criação (`created_by`, `created_at`, etc.)
- RLS não valida mudanças de valores

**Solução**:
- Usar `WITH CHECK` em UPDATE para comparar com `OLD`
- `NEW.field = OLD.field` garante campo não muda
- Aplicar a todos os campos imutáveis

**Exemplo**:
```
WITH CHECK (
    created_by = OLD.created_by AND
    created_at = OLD.created_at
)
```

**Nota**: `OLD` está disponível apenas em UPDATE, não em INSERT.

### 9. Soft Delete e RLS
**Comportamento**:
- Dados soft deleted (`deleted_at IS NOT NULL`) devem ser invisíveis
- RLS pode filtrar por `deleted_at IS NULL` em `USING`

**Padrão**:
- Todas as policies SELECT verificam `deleted_at IS NULL`
- Helper functions verificam `deleted_at IS NULL`
- Garante consistência em todas as tabelas

**Nota**: Soft delete é padrão em todas as tabelas principais.

### 10. Idempotência e RLS
**Comportamento**:
- Eventos têm `id` único (gerado no cliente)
- INSERT pode tentar inserir mesmo `id` múltiplas vezes
- RLS não previne duplicados, UNIQUE constraint sim

**Solução**:
- UNIQUE constraint em `sleep_events.id` previne duplicados
- RLS valida permissões, constraint valida unicidade
- Cliente pode tentar inserir mesmo evento múltiplas vezes (idempotência)

**Nota**: RLS e constraints trabalham em conjunto.

---

## Resumo de Validações por Operação

### SELECT
- Verifica `is_active_caregiver` (acesso via caregivers)
- Verifica `deleted_at IS NULL` (não soft deleted)
- Todos os papéis podem ver (owner, editor, viewer)

### INSERT
- Verifica `auth.uid() IS NOT NULL` (autenticado)
- Verifica permissões de escrita (`can_write` ou específico)
- Valida relações (ex: `caregiver_id` corresponde ao utilizador)
- Valida campos obrigatórios (ex: `created_by = auth.uid()`)

### UPDATE
- Verifica acesso à linha (`USING`)
- Verifica permissões de escrita (`can_write` ou específico)
- Valida campos imutáveis (`WITH CHECK` comparando com `OLD`)
- Valida soft delete (apenas owner quando aplicável)

### DELETE
- Nunca permitido (sem policy, RLS bloqueia)
- Soft delete via UPDATE apenas

---

## Checklist de Implementação

Antes de escrever SQL, verificar:

- [ ] Helper functions definidas (`is_active_caregiver`, `can_write`, `is_owner`)
- [ ] Helper functions usam `SECURITY DEFINER`
- [ ] Todas as policies verificam autenticação (`auth.uid() IS NOT NULL` quando necessário)
- [ ] SELECT policies verificam `deleted_at IS NULL`
- [ ] SELECT policies verificam acesso via `is_active_caregiver`
- [ ] INSERT policies validam `created_by = auth.uid()` quando aplicável
- [ ] INSERT policies validam relações (ex: `caregiver_id` corresponde ao utilizador)
- [ ] UPDATE policies têm `USING` (acesso) e `WITH CHECK` (dados)
- [ ] UPDATE policies protegem campos imutáveis
- [ ] UPDATE policies validam soft delete (apenas owner quando aplicável)
- [ ] Nenhuma policy DELETE (RLS bloqueia por padrão)
- [ ] Índices em `caregivers` otimizam helper functions
- [ ] Triggers têm acesso necessário (via `SECURITY DEFINER` se necessário)

---

## Próximos Passos

Após esta especificação, escrever SQL das RLS policies será mecânico:

1. Criar helper functions com `SECURITY DEFINER`
2. Criar policies SELECT com `USING` clause
3. Criar policies INSERT com `WITH CHECK` clause
4. Criar policies UPDATE com `USING` e `WITH CHECK` clauses
5. Não criar policies DELETE (RLS bloqueia por padrão)
6. Testar cada policy com diferentes papéis e cenários

Todas as decisões de segurança estão definidas. Implementação SQL será tradução direta desta especificação.

