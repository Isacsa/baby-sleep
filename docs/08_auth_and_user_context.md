# Fluxo de Autenticação e Contexto do Utilizador (MVP Sono)

## 1) Propósito e Escopo

Este documento define, **sem código**, o fluxo completo de:

- **Autenticação** (Supabase Auth via **Magic Link/OTP**)
- **Contexto do utilizador**: `auth.uid()`, bebés acessíveis, bebé ativo (por dispositivo), `caregiver_id` (por bebé), papel (`owner|editor|viewer`)
- **Regras offline-first**: o produto funciona sem rede e o backend só é usado para sync/partilha

### Fora de escopo (explícito)

- UI, UX visual, navegação
- Resolução de conflitos avançada (o cliente faz last-write-wins; o backend não resolve)
- Alterações ao modelo de domínio ou schema do backend

## 2) Decisões Fechadas (MVP)

### 2.1 Autenticação

- **Método**: Supabase Auth com **Magic Link/OTP por email**.
- **Fonte de identidade**: `auth.uid()` (UUID do Supabase Auth).
- **Regra**: Sem sessão válida → **nenhuma operação remota** deve ser executada.

### 2.2 Bebé ativo

- **Persistência**: **por dispositivo, local** (não sincroniza entre devices).
- **Semântica**: o “bebé ativo” é apenas uma preferência local; **não prova acesso**.

### 2.3 caregiver_id e papéis

- `caregiver_id` é **obrigatório** em `sleep_events` e deve pertencer ao utilizador autenticado.
- `caregiver_id` é **sempre por bebé** (um utilizador pode ter vários caregiver_ids, um por bebé).
- Papéis (`owner|editor|viewer`) são a base das permissões.
- **Fonte de verdade**: backend Supabase (RLS) decide permissões; local é cache.

## 3) Glossário de Contexto (definições operacionais)

### Identidade

- **UserId**: `auth.uid()` quando existe sessão válida.
- **Session**: token(s) mantidos pelo SDK do Supabase; pode expirar e ser renovado.

### Contexto por bebé

- **BabyId**: identificador do bebé.
- **ActiveBabyId**: BabyId selecionado e guardado localmente por device.
- **CaregiverContext (por BabyId)**:
  - `caregiver_id`
  - `role` (`owner|editor|viewer`)
  - origem: tabela `caregivers` filtrada por (`user_id = auth.uid()`, `baby_id`, `deleted_at IS NULL`).

### Device

- **device_id**: string estável por dispositivo (auditoria); não afeta permissões.

## 4) Responsabilidades por Camada (Clean Architecture)

### Domain

- Regras puras: derivação de estado (`SleepState`) a partir de eventos locais válidos.
- Não conhece Supabase, Auth, SQLite, rede, providers.

### Data

- **Local (SQLite)**: cache e fonte imediata (offline-first) de `babies`, `caregivers`, `sleep_events` e estado de sync.
- **Remote (Supabase)**: apenas IO conforme contrato; sem cálculo de estado.
- Mapeamento de erros: rede/transitório, permissão/RLS, validação/constraints.

### Sync

- Orquestra push e pull (idempotência, incremental, sem lógica de domínio).
- Mantém `lastSyncedAt` localmente.
- Nunca apaga eventos; merge é idempotente.

### Application

- Mantém “o que está selecionado/agora”: sessão, bebé ativo (local), e caregiver context do bebé ativo.
- Orquestra chamadas a repos/sync e expõe estado de sync (idle/syncing/success/error).

### Presentation (futuro)

- Só observa providers e aciona intents (login, selecionar bebé, iniciar sync).

## 5) Fluxo Operacional (end-to-end)

### 5.1 Arranque da app (bootstrap)

**Objetivo**: ter estado funcional offline, mesmo sem sessão.

1. Inicializar SQLite.
2. Inicializar Supabase client (config via env).
3. Tentar restaurar sessão do Supabase (se existir).
4. Carregar do storage local:
   - lista de bebés (cache)
   - caregivers (cache)
   - `ActiveBabyId` (preferência local)
5. Construir contexto:
   - `UserId = auth.uid()` se autenticado; caso contrário `null`.
   - `ActiveBabyId` só é válido se o bebé existir localmente.
   - `CaregiverContext` só existe se houver sessão + caregiver local para (`UserId`, `ActiveBabyId`).

**Consequência**:
- Sem `CaregiverContext`, criação de eventos deve ser bloqueada (falta `caregiver_id` válido).
- Leitura e derivação de estado continuam possíveis via SQLite.

### 5.2 Login (Magic Link/OTP)

1. Utilizador pede magic link/OTP.
2. Após confirmação, sessão passa a existir; `auth.uid()` fica disponível.
3. Application layer deve:
   - atualizar contexto de utilizador
   - revalidar bebés acessíveis (via pull quando online)
   - revalidar `CaregiverContext` do bebé ativo (via pull/refresh de caregivers)

### 5.3 Determinar “bebés acessíveis”

**Definição**: bebés onde o utilizador é cuidador ativo (`caregivers.user_id = auth.uid()` e `deleted_at IS NULL`), conforme RLS.

**Regra offline-first**:

1. Mostrar lista de bebés do SQLite (cache).
2. Quando online + autenticado, executar pull/refresh remoto e fazer merge local.

**Observação**: a app pode ter bebés no SQLite que deixaram de ser acessíveis; isso deve ser corrigido após um pull bem sucedido (ver edge cases).

### 5.4 Seleção de bebé ativo (por dispositivo)

**Entrada**: `BabyId` escolhido de entre os bebés acessíveis (local).

**Ações**:

1. Persistir `ActiveBabyId` localmente (device-scoped).
2. Atualizar `CaregiverContext` para esse bebé:
   - tentar resolver via SQLite (`caregivers`)
   - se não existir e online, disparar pull/refresh de caregivers
3. Recarregar timeline local de `sleep_events` do bebé ativo.
4. Recalcular `SleepState` a partir de eventos válidos (`is_corrected = false`).

### 5.5 Resolução de caregiver_id/role para o bebé ativo

**Objetivo**: obter um `caregiver_id` válido para usar em escrita de eventos.

**Ordem**:

1. SQLite: procurar caregiver para (`user_id = auth.uid()`, `baby_id = ActiveBabyId`).
2. Se não encontrado e online: executar operação remota permitida pelo contrato (`GetCaregiversForBaby`) e persistir local.

**Saídas**:

- Encontrado: `CaregiverContext(caregiver_id, role)`.
- Não encontrado: `CaregiverContext = null` (impede escrita de eventos para esse bebé).

### 5.6 Criação de eventos com contexto

**Pré-condições mínimas**:

- `ActiveBabyId != null`
- `CaregiverContext != null` (para obter `caregiver_id`)
- `device_id` disponível

**Comportamento**:

1. Criar evento localmente em SQLite com `synced_at = NULL`.
2. Estado derivado atualiza imediatamente (providers).
3. Push tenta enviar quando online + autenticado.

### 5.7 Sign-out

**Efeito imediato**:

- `UserId = null`
- `CaregiverContext = null`
- operações remotas ficam bloqueadas

**Dados locais**:

- SQLite mantém dados (offline-first).
- `ActiveBabyId` pode permanecer (preferência local), mas **não autoriza escrita** sem `CaregiverContext`.

### 5.8 Sincronização Push (enviar eventos locais para Supabase)

**Objetivo**: enviar eventos criados localmente (`synced_at = NULL`) para o backend.

**Pré-condições**:

- Utilizador autenticado (`auth.uid() != null`)
- Online (conexão de rede disponível)
- Eventos locais com `synced_at = NULL` existem

**Fluxo**:

1. Ler eventos não sincronizados do SQLite para o `baby_id` (ou global):
   - Filtrar por `synced_at IS NULL`
   - Ordenar por `created_at ASC` (mais antigos primeiro)
2. Enviar em batches pequenos (ex: 10-20 eventos por batch)
3. Para cada evento:
   - Tentar inserir no Supabase via `CreateSleepStartEvent` / `CreateSleepEndEvent`
   - Se sucesso: atualizar localmente `synced_at = nowUtc()`
   - Se erro de duplicado (`id` já existe): tratar como sucesso e atualizar `synced_at` (idempotência)
   - Se erro transitório (rede): parar e manter pendente
   - Se erro permanente (RLS, validação): marcar erro em `metadata.sync_error` e não retentar automaticamente
4. Atualizar estado de sync (idle/syncing/success/error)

**Invariantes Push**:

- Nunca apagar eventos locais, mesmo em erro permanente
- Idempotência: reexecutar push não duplica eventos no backend
- Ordem preservada: eventos mais antigos são enviados primeiro
- Estado local é sempre fonte de verdade imediata

**Alinhamento com contrato backend**:

- Usa `CreateSleepStartEvent` / `CreateSleepEndEvent` (secção 4.5, 4.6 do contrato)
- Backend valida RLS e permissões (`can_write`, `caregiver_id` válido)
- Backend garante idempotência via constraint `UNIQUE(id)`
- Erros de permissão (RLS) são permanentes e não devem ser retentados

### 5.9 Sincronização Pull (receber eventos remotos do Supabase)

**Objetivo**: receber eventos criados por outros cuidadores/dispositivos e integrá-los localmente.

**Pré-condições**:

- Utilizador autenticado (`auth.uid() != null`)
- Online (conexão de rede disponível)
- `lastSyncedAt` guardado localmente por `baby_id`

**Fluxo**:

1. Ler `lastSyncedAt` local para o `baby_id` (ou usar timestamp inicial se não existir)
2. Chamar `GetNewRemoteEvents` do backend:
   - Filtrar por `baby_id` e `created_at > lastSyncedAt`
   - Ordenar por `created_at ASC`
3. Para cada evento remoto recebido:
   - Se `id` não existe localmente: inserir novo evento
   - Se `id` já existe localmente: atualizar apenas campos mutáveis (`is_corrected`, `corrected_by`, `synced_at`, `metadata`); nunca alterar campos imutáveis (`id`, `baby_id`, `type`, `timestamp`, `caregiver_id`, `created_at`)
4. Após sucesso total: atualizar `lastSyncedAt = nowUtc()` localmente
5. Se erro transitório: parar e manter `lastSyncedAt` inalterado (retentar depois)
6. Atualizar estado de sync

**Invariantes Pull**:

- Nunca apagar eventos locais durante pull
- Merge é idempotente: reexecutar pull não duplica eventos
- Campos imutáveis são protegidos: eventos locais nunca perdem `timestamp`, `caregiver_id`, `created_at` originais
- Estado derivado recalcula automaticamente após merge (via providers)

**Alinhamento com contrato backend**:

- Usa `GetNewRemoteEvents` (secção 4.10 do contrato)
- Backend retorna apenas eventos acessíveis via RLS
- Backend ordena por `created_at ASC` (contrato não especifica ordenação automática, mas cliente deve solicitar explicitamente)
- Backend não calcula estado; cliente deriva após merge

### 5.10 Sincronização Completa (Push + Pull)

**Objetivo**: sincronização bidirecional completa para um `baby_id` ou todos os bebés acessíveis.

**Fluxo**:

1. Executar **Push** primeiro (enviar eventos locais)
2. Se push bem sucedido (ou parcialmente sucedido), executar **Pull** (receber eventos remotos)
3. Estado de sync reflete o resultado combinado

**Observação**: push e pull são independentes; pull pode executar mesmo se push falhar parcialmente (eventos permanentes não bloqueiam pull).

## 6) Invariantes do Sistema (regras que nunca podem falhar)

### Invariantes de Autenticação

- **I1**: Sem `auth.uid()` válido, nenhuma operação remota (push/pull) pode ser executada.
- **I2**: `auth.uid()` é a única fonte de identidade; não existe "utilizador local" sem sessão Supabase.

### Invariantes de Contexto

- **I3**: `CaregiverContext` só existe se `auth.uid() != null` e existe relação `caregivers` local ou remota válida.
- **I4**: `ActiveBabyId` é sempre device-scoped; não sincroniza entre dispositivos.
- **I5**: `ActiveBabyId` não prova acesso; RLS no backend é a fonte de verdade de permissões.

### Invariantes de Eventos

- **I6**: Eventos nunca são apagados (nem localmente, nem remotamente). Correção = novo evento + marcação de `is_corrected`.
- **I7**: `caregiver_id` é obrigatório em todos os eventos de sono; sem `CaregiverContext`, criação de eventos é bloqueada.
- **I8**: `device_id` é sempre fornecido pelo cliente; backend não valida nem gera.

### Invariantes de Sincronização

- **I9**: Push é idempotente: reexecutar não duplica eventos no backend (backend garante via `UNIQUE(id)`).
- **I10**: Pull é idempotente: reexecutar não duplica eventos localmente (merge verifica `id` existente).
- **I11**: Campos imutáveis (`id`, `baby_id`, `type`, `timestamp`, `caregiver_id`, `created_at`) nunca são alterados durante merge.
- **I12**: Estado local é sempre fonte de verdade imediata; sync reconcilia, não substitui.

### Invariantes de Estado Derivado

- **I13**: `SleepState` é sempre derivado localmente a partir de eventos válidos (`is_corrected = false`).
- **I14**: Backend nunca calcula nem fornece estado derivado; apenas persiste eventos.

### Invariantes de Permissões

- **I15**: RLS no backend é a única fonte de verdade de permissões; cache local pode estar desatualizado.
- **I16**: Erros de permissão (RLS) são permanentes; não devem ser retentados automaticamente.

## 7) Critérios de Aceitação (funcionais e verificáveis)

### Autenticação

- Com sessão válida, `auth.uid()` fica disponível no bootstrap sem interação.
- Sem sessão, qualquer operação remota é bloqueada (ou falha imediatamente de forma consistente).

### Bebés acessíveis

- Em modo offline, a lista é apresentada a partir do SQLite.
- Após login + online + pull, a lista inclui bebés partilhados por outros cuidadores.

### Bebé ativo

- Selecionar bebé ativo persiste localmente e restaura após restart.
- Trocar bebé ativo muda imediatamente timeline local e `SleepState` derivado.

### caregiver_id e role

- Para um bebé acessível, é possível resolver `caregiver_id` + `role` após um pull/refresh bem sucedido.
- Sem `CaregiverContext`, não é possível criar `sleep_events` para esse bebé.

### Sync e estado derivado

- Pull integra eventos criados por outros devices/cuidadores no SQLite.
- Reexecutar pull é idempotente (não duplica).
- `SleepState` reflete novos eventos sem lógica no sync (apenas via providers/derivação).

### Sincronização Push/Pull

- Push envia eventos locais em ordem (`created_at ASC`) e marca `synced_at` após sucesso.
- Pull recebe eventos remotos incrementais (`created_at > lastSyncedAt`) e faz merge idempotente.
- Erros transitórios (rede) param sync mas não corrompem estado local.
- Erros permanentes (RLS) marcam eventos mas não os apagam.

## 8) Edge Cases Offline (documentado e validado com alinhamento ao contrato backend)

### EC1: First install totalmente offline

**Condição**: app instalada sem internet; não existe sessão.

**Comportamento esperado**:

- SQLite inicializa corretamente.
- Lista de bebés está vazia (não há cache local).
- `ActiveBabyId = null`.
- Não é possível criar eventos (não existe `CaregiverContext`; invariante I7).
- Leitura e derivação de estado funcionam (mas não há dados).

**Quando rede volta + login**:

- Pull de bebés/caregivers popula cache local via `GetAccessibleBabies` e `GetCaregiversForBaby` (contrato secção 4.1, 4.3).
- Após pull bem sucedido, `CaregiverContext` pode ser resolvido.
- Passa a ser possível selecionar bebé e criar eventos.

**Validação contra contrato backend**:

- ✅ Backend não valida "recenticidade" de eventos (contrato secção 2: offline-first).
- ✅ RLS garante que apenas bebés acessíveis são retornados (contrato secção 3: RLS).
- ✅ `auth.uid()` é obrigatório para operações remotas (contrato secção 3: auth.uid()).

### EC2: Sessão expirada / refresh falha

**Condição**: havia sessão, mas refresh falha (ex: sem rede, token inválido).

**Comportamento esperado**:

- App continua a funcionar para leitura/derivação local (offline-first; invariante I12).
- Operações remotas (push/pull) são bloqueadas (invariante I1: sem `auth.uid()`, sem operações remotas).
- Escrita de eventos só é permitida se `CaregiverContext` existir localmente (invariante I7).
- Estado local permanece intacto; nenhum dado é apagado.

**Quando login é refeito**:

- `auth.uid()` volta a estar disponível.
- Push/pull retomam automaticamente (se online).
- `CaregiverContext` é revalidado via pull/refresh.

**Validação contra contrato backend**:

- ✅ Backend bloqueia operações se `auth.uid()` é NULL (contrato secção 3: auth.uid()).
- ✅ Cliente mantém dados locais (contrato secção 2: offline-first).
- ✅ RLS valida permissões no momento da operação (contrato secção 3: RLS).

### EC3: Bebé ativo não existe localmente

**Condição**: `ActiveBabyId` guardado, mas o bebé foi removido do SQLite (reset/clear) ou nunca foi cacheado.

**Comportamento esperado**:

- No bootstrap, detetar invalidade: `ActiveBabyId` aponta para bebé inexistente no SQLite.
- Limpar `ActiveBabyId = null` (invariante I4: `ActiveBabyId` é apenas preferência local).
- `CaregiverContext = null` (não há bebé ativo para resolver contexto).
- Não criar eventos até selecionar um bebé válido (invariante I7).

**Se online + autenticado**:

- Tentar pull de bebés acessíveis para repovoar cache.
- Se o bebé ainda for acessível remotamente, será restaurado no cache após pull.

**Validação contra contrato backend**:

- ✅ Backend não mantém estado de "bebé ativo" (contrato secção 3: baby_id ativo).
- ✅ Cliente valida existência local antes de usar `ActiveBabyId` (responsabilidade do cliente).
- ✅ `GetAccessibleBabies` retorna lista atualizada (contrato secção 4.1).

### EC4: Bebé ativo deixou de ser acessível (remoção de caregiver no backend)

**Condição**: o utilizador perde acesso (caregiver soft deleted ou role alterada) enquanto esteve offline.

**Comportamento esperado (offline)**:

- App pode ainda mostrar dados locais (cache; offline-first; invariante I12).
- Operações remotas (push/pull) vão falhar por RLS quando tentar (invariante I15: RLS é fonte de verdade).

**Comportamento esperado (próximo pull online)**:

- `GetCaregiversForBaby` retorna lista vazia (RLS bloqueia; contrato secção 4.3: lista vazia quando não é cuidador).
- `GetAccessibleBabies` não inclui esse bebé (RLS bloqueia; contrato secção 4.1).
- Application layer deve:
  - Remover esse bebé da lista acessível local (corrigir cache).
  - Limpar `ActiveBabyId` se for o ativo (invariante I5: `ActiveBabyId` não prova acesso).
  - Limpar `CaregiverContext` para esse bebé (invariante I3).

**Validação contra contrato backend**:

- ✅ RLS garante que cuidadores soft deleted não têm acesso (contrato secção 3: RLS, secção 6: soft delete).
- ✅ Backend retorna lista vazia, não erro (contrato secção 4.1, 4.3: "Lista vazia (RLS bloqueia)").
- ✅ Cliente deve corrigir cache após pull (responsabilidade do cliente; contrato secção 2: backend não valida offline).

### EC5: Evento criado offline com contexto "stale" (permissão revogada entretanto)

**Condição**: o utilizador tinha `CaregiverContext` local, cria eventos offline, mas perdeu acesso no backend antes do push.

**Comportamento esperado**:

- Push falha por RLS (erro de permissão; invariante I15: RLS é fonte de verdade).
- Evento **não é apagado** (invariante I6: eventos nunca são apagados).
- Evento mantém `synced_at = NULL` e fica marcado localmente com "erro permanente" (ex: em `metadata.sync_error`).
- Erro é classificado como permanente; não deve ser retentado automaticamente (invariante I16).

**Pull subsequente**:

- Pull não deve apagar eventos locais (invariante I11: merge nunca apaga).
- Pull pode trazer novos eventos remotos e atualizar cache de bebés/caregivers.
- Se acesso for restaurado remotamente, push subsequente pode ter sucesso.

**Validação contra contrato backend**:

- ✅ RLS bloqueia INSERT se utilizador não é cuidador ativo (contrato secção 4.5: "RLS bloqueia (erro de permissão)").
- ✅ Backend não valida "recenticidade" de eventos (contrato secção 2: offline-first; secção 5: comportamento offline).
- ✅ Cliente trata erros de permissão como permanentes (contrato secção 7: "Não retentar automaticamente (não é erro transitório)").
- ✅ Backend não apaga eventos; apenas bloqueia criação (contrato secção 1: "O que o backend NÃO faz").

### EC6: Re-login com mudança de user

**Condição**: device faz logout de UserA e login de UserB.

**Comportamento esperado**:

- `UserId` muda (`auth.uid()` muda; invariante I2: `auth.uid()` é única fonte de identidade).
- `CaregiverContext` deve ser recalculado (invariante I3: `CaregiverContext` depende de `auth.uid()`).
- `ActiveBabyId` é apenas preferência local (invariante I4: device-scoped).
- Validar `ActiveBabyId` contra bebés acessíveis do novo utilizador:
  - Se acessível: manter e recalcular `CaregiverContext`.
  - Se não acessível: limpar `ActiveBabyId = null` (invariante I5: não prova acesso).

**Dados locais**:

- SQLite mantém dados de UserA (offline-first; invariante I12).
- UserB pode ver dados de UserA se partilharem bebés (via pull após login).
- Se não partilharem bebés, cache local de UserA fica "órfão" mas não é apagado.

**Validação contra contrato backend**:

- ✅ `auth.uid()` identifica utilizador exclusivamente (contrato secção 3: auth.uid()).
- ✅ RLS garante que UserB só vê bebés onde é cuidador (contrato secção 3: RLS).
- ✅ Backend não mantém estado de "bebé ativo" (contrato secção 3: baby_id ativo).
- ✅ Cliente valida acesso antes de usar `ActiveBabyId` (responsabilidade do cliente).

## 9) Alinhamento explícito com o Contrato Backend

Este documento é consistente e validado contra `docs/06_backend_contract_sleep_mvp.md`:

### Mapeamento de Conceitos

| Conceito | Contrato Backend | Este Documento | Validação |
|----------|------------------|----------------|-----------|
| Identidade | `auth.uid()` (secção 3) | `UserId = auth.uid()` (secção 3) | ✅ Consistente |
| Caregiver ID | Obrigatório, por bebé (secção 3) | `CaregiverContext` por bebé (secção 3) | ✅ Consistente |
| Bebé ativo | Mantido no cliente (secção 3) | `ActiveBabyId` device-scoped (secção 2.2) | ✅ Consistente |
| Offline-first | Eventos criados localmente (secção 2) | SQLite como fonte imediata (secção 4) | ✅ Consistente |
| RLS | Fonte de verdade de permissões (secção 3) | Invariante I15 (secção 6) | ✅ Consistente |
| Push | `CreateSleepStartEvent` / `CreateSleepEndEvent` (secção 4.5, 4.6) | Secção 5.8 | ✅ Consistente |
| Pull | `GetNewRemoteEvents` (secção 4.10) | Secção 5.9 | ✅ Consistente |
| Idempotência | `UNIQUE(id)` garante (secção 2, 5) | Invariantes I9, I10 (secção 6) | ✅ Consistente |
| Estado derivado | Cliente deriva (secção 2) | Invariante I13 (secção 6) | ✅ Consistente |

### Validação de Edge Cases

Todos os edge cases (secção 8) foram validados explicitamente contra o contrato backend:

- **EC1**: ✅ Alinhado com secção 2 (offline-first), secção 3 (auth.uid(), RLS)
- **EC2**: ✅ Alinhado com secção 3 (auth.uid()), secção 2 (offline-first)
- **EC3**: ✅ Alinhado com secção 3 (baby_id ativo), secção 4.1 (GetAccessibleBabies)
- **EC4**: ✅ Alinhado com secção 3 (RLS), secção 4.1, 4.3 (listas vazias), secção 6 (soft delete)
- **EC5**: ✅ Alinhado com secção 4.5 (RLS bloqueia), secção 2 (offline-first), secção 7 (erros permanentes)
- **EC6**: ✅ Alinhado com secção 3 (auth.uid(), RLS, baby_id ativo)

### Garantias do Contrato Respeitadas

- ✅ **Autenticação e autorização**: RLS valida em todas as operações (invariante I15)
- ✅ **Persistência idempotente**: Push/pull são idempotentes (invariantes I9, I10)
- ✅ **Integridade referencial**: Cliente valida `caregiver_id` antes de criar eventos (invariante I7)
- ✅ **Auditoria completa**: `device_id` e `caregiver_id` sempre presentes (invariante I8)
- ✅ **Sincronização incremental**: `lastSyncedAt` e `synced_at` usados corretamente (secção 5.8, 5.9)
- ✅ **Isolamento de dados**: RLS garante acesso exclusivo (invariante I15)
- ✅ **Offline-first**: SQLite é fonte imediata; sync reconcilia (invariante I12)
- ✅ **Event-based**: Estado sempre derivado localmente (invariante I13)
- ✅ **Consistência eventual**: Conflitos resolvidos no cliente (last-write-wins)

### O que o Backend NÃO faz (respeitado)

- ✅ Backend não calcula estado: Cliente deriva `SleepState` localmente (invariante I13)
- ✅ Backend não resolve conflitos: Cliente aplica last-write-wins (secção 5.9: merge)
- ✅ Backend não valida lógica de domínio: Cliente valida antes de enviar
- ✅ Backend não corrige erros: Cliente marca erros permanentes e não retenta (invariante I16)
- ✅ Backend não sincroniza ativamente: Cliente inicia push/pull (secção 5.8, 5.9)

