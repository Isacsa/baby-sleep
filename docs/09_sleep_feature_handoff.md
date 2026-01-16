## Handoff: Projeto + Feature Sono (Sleep) — contexto e plano

Este ficheiro existe para dar **contexto rápido e estruturado** a um novo chat/agente sobre o projeto e, em particular, sobre a feature de **Sono** (SleepStart/SleepEnd), incluindo o problema multi-device (overlaps/inconsistências) e o plano para uma solução definitiva.

> **Fonte de verdade do domínio**: `/docs/*.txt` e contrato backend (`/docs/06_backend_contract_sleep_mvp.md`). Este ficheiro é um resumo operacional.

---

## 1) O que é o projeto

App mobile **Flutter** (offline-first) com backend **Supabase** para autenticação, segurança (RLS) e partilha de dados entre cuidadores.

Domínio: tracking parental centrado em **bebés** com dados sensíveis (sono, rotinas, etc.).

---

## 2) Princípios e decisões fechadas (não negociáveis)

Baseado em `/docs/02_core_principles.txt` e `/docs/01_domain_model.txt`:

- **Offline-first**: nenhuma ação do utilizador pode ser bloqueada por falta de rede.
- **Centrado no bebé**: dados pertencem ao bebé; utilizadores acedem via relação de cuidador.
- **Event-based (eventos, não estados)**: registamos acontecimentos; estados são derivados.
- **Multi-bebé e multi-cuidador por defeito**.
- **Erro humano é normal**: UX deve permitir correções simples.
- **Resolução de conflitos**: previsível e auditável; regra prática “last-write-wins” com metadata (ver contrato do backend).

---

## 3) Modelo de dados (alto nível)

Entidades principais (ver `/docs/01_domain_model.txt` e migrations):

- **`babies`**: entidade central do sistema.
- **`caregivers`**: relação `(baby_id, user_id)` com role `owner|editor|viewer`.
- **`sleep_events`**: unidade base do domínio “Sleep”.

### `sleep_events` (campos relevantes)

- **`id`**: UUID gerado no cliente (idempotência).
- **`type`**: `SleepStart` ou `SleepEnd`.
- **`timestamp`**: quando o evento aconteceu (UTC). **Fonte de verdade da ordem lógica**.
- **`created_at`**: quando foi criado no dispositivo (UTC). **É client-provided** (não é sobrescrito pelo backend).
- **`synced_at`**: timestamp de quando foi sincronizado (pode ser usado para sync incremental).
- **`is_corrected` / `corrected_by`**: correções preservam histórico (não apagar, corrigir via eventos).
- **`device_id`**: origem (auditoria).

Sessão de sono **não é persistida**: é um value-object derivado a partir da sequência de eventos (ver `SleepSession`).

---

## 4) Arquitetura e derivação de estado (SleepState / SleepSession)

### Derivação do estado atual (SLEEPING/AWAKE)

- `SleepState` é derivado de eventos válidos (is_corrected=false).
- Regra: “último evento válido” define estado:
  - último = `SleepStart` → **SLEEPING**
  - último = `SleepEnd` → **AWAKE**
- Ordenação típica: `timestamp DESC`, tie-break `createdAt DESC`.

### Derivação de sessões

- `SleepSession.fromEventList(events)` agrupa `SleepStart` + `SleepEnd` numa sessão.
- Sessões podem atravessar meia-noite (cross-midnight).

### Guardrails já implementados para robustez

- **Anti “sessão fantasma” em multi-device**: se surgir `SleepStart` enquanto já existe um start aberto (sem `SleepEnd`), isto é tratado como **conflito** e a derivação mantém um “winner” determinístico (start mais recente), sem criar sessão incompleta fantasma que bloqueia o sistema.
- **Deteção de conflito** (para UX): provider consegue detetar grupos “Start enquanto já está aberto” e a UI pode pedir confirmação ao utilizador para corrigir eventos (marcar `is_corrected` e criar eventos de correção).

---

## 5) Sync atual (offline-first, push/pull incremental)

### Local-first (SQLite)

- Todas as ações de UX criam eventos **localmente** primeiro.
- Eventos são guardados com `synced_at = NULL` até serem sincronizados.
- Há um estado local por bebé: `sync_state.last_synced_at` (cursor do pull incremental).

### Push (local → Supabase)

- Estratégia “layered sync”: Babies → Caregivers → SleepEvents.
- Push é idempotente (por `id` do evento).
- Após push bem sucedido: marca `synced_at` localmente.

### Pull incremental (Supabase → local)

Problema estrutural: o contrato backend diz que `created_at` é client-provided. Portanto, usar `created_at` como cursor pode falhar com **clock-skew** entre dispositivos (um device pode avançar o cursor “para o futuro” e perder eventos de outro device).

**Fix mínimo implementado**: “Safety Window + clamp” no cursor do pull:

- Se `last_synced_at > nowUtc` → **clamp** para `nowUtc`.
- `effectiveCursor = clamp(last_synced_at, <= nowUtc) - buffer` (buffer ~ 5 min).
- Pull re-busca uma janela recente e confia na idempotência do upsert (por `id`).
- Atualização do cursor: `cursor = min(max(created_at recebido), nowUtc)` (nunca avança para o futuro).
- Caso `0 eventos`: **não avançar cursor para `now`** (evita amplificar skew).

> Nota: uma solução definitiva pode passar por usar `synced_at` server-side como cursor canónico (ver secção “Plano definitivo”).

### Merge/upsert local

Ao “upsertRemoteEvents”:
- Não altera campos imutáveis (`id`, `baby_id`, `type`, `timestamp`, `created_at`, `device_id`).
- Atualiza apenas campos mutáveis: `is_corrected`, `corrected_by`, `synced_at`, `metadata`.

---

## 6) Estado atual da UI (Sono)

### Home (Sono)

`HomeSleepPage` tem:
- Botão principal Start/End.
- Quick chips (ex.: “adormeceu há X minutos”) e “Outra hora”.
- Fluxo retroativo para hora passada:
  - bottom sheet para escolher intenção:
    - “Começou a dormir às HH:mm e ainda está a dormir” → cria `SleepStart(timestamp escolhido)`
    - “Registar sono completo” → wizard para escolher **data+hora** de início e fim; grava `SleepStart(start)` + `SleepEnd(end)` localmente (atómico via transaction).
- Overlap UX:
  - Se tentativa de registo sobrepõe sessões existentes, mostra modal (cancelar/substituir).
  - Substituir não apaga histórico: marca eventos antigos como corrigidos e cria novos.
- Snackbar de erro tem botão “X”.

### Calendário/Detalhe de dia

`DayDetailPage`:
- Mostra sessões derivadas do timeline completo.
- Filtra sessões por overlap com o dia local (cross-midnight não aparece como “em curso” no dia errado).
- Total de sono do dia usa duração “clipped” ao intervalo do dia (não soma horas fora do dia).

---

## 7) Problema multi-device (o “bug do sono infinito” / overlaps)

### Sintoma observado

Quando dois dispositivos (mesma conta, mesmo bebé) operam offline ou sem sync intermédio:
- podem criar eventos em paralelo (`SleepStart` em A, `SleepStart` em B 5–30s depois, e depois `SleepEnd` em ambos),
- após sync, um device pode ficar com:
  - “sono infinito” (sessão em curso fantasma),
  - overlap permanente que bloqueia novos registos,
  - divergência de estado entre devices (um ok, outro preso).

### Classes de falha a diferenciar (debugging)

- **H1**: o pull incremental “perde” um `SleepEnd` (existe no Supabase mas não chega ao SQLite do device bugado).
  - causa provável: cursor baseado em `created_at` + clock-skew.
- **H2**: dataset converge, mas derivação cria sessão fantasma (ex.: Start-Start-End).
  - causa provável: algoritmo de sessões transforma Start consecutivo em sessão incompleta e isso vira overlap infinito.
- **H3**: concorrência/refresh/provider stale mascara estado.
  - causa provável: refresh descartado, caches não invalidadas, rebuild race.

---

## 8) Logs e debugging (como provar a hipótese certa)

Logs “debug-only” (kDebugMode via `assert`), com tags:

- `[PullStrategy][H1-DEBUG]`:
  - `rawLastSyncedAt`, `nowUtc`, `effectiveCursor`, `eventsReceived`, `min/max(created_at)`, amostra de eventos.
  - prova se o cursor saltou e se o pull está a devolver o `SleepEnd`.
- `[SleepSession][H2-DEBUG]`:
  - lista ordenada de eventos válidos e sessões derivadas; conflitos Start-while-open.
  - prova se existe sessão fantasma.
- `[SyncProvider][H3-DEBUG]`:
  - invalidations após sync.
- `[SleepEventsProvider][H3-DEBUG]`:
  - refresh seq, descarte de refresh stale.

---

## 9) Plano estruturado para solução definitiva (assertivo)

### Objetivo técnico (consistência eventual forte no cliente)

Após sync (push/pull), todos os devices devem convergir para o mesmo estado derivado e nenhum deve ficar bloqueado por overlap.

### Caminho recomendado (em fases)

**Fase A — Robustez imediata (já feita/andamento):**
- Pull tolerante a clock-skew: clamp + safety window + cursor nunca no futuro.
- Derivação nunca cria “sessão fantasma” por Start enquanto já está aberto.
- Overlap detection ao criar novos eventos/sessões + UX de substituição/correção.

**Fase B — Cursor canónico definitivo (recomendado):**
- Mudar o cursor do pull para ser baseado em **`synced_at`** e garantir que `synced_at` é **server-generated** (ex.: trigger no backend que define `synced_at = now()` em INSERT).
  - Isto elimina a dependência de relógio do cliente para incremental sync.
  - Idealmente sem alterar schema (apenas trigger/behavior); mas pode requerer migração backend.

**Fase C — Política de conflitos consistente e auditável (cliente):**
- Formalizar uma política determinística de conflitos SleepStart/SleepEnd:
  - winner rule (determinístico) para derivação
  - opcional: UI prompt para correção (preservando histórico)
- Garantir que “conflito não bloqueia”: o utilizador consegue continuar a registar (com avisos).

---

## 10) Use cases e critérios de aceitação (multi-device)

### Teste principal (T1)

- Device A: Start
- Device B: Start (5–30s depois)
- ambos End
- sync em ordens diferentes (A→B e B→A)

**Esperado:**
- após push/pull em ambos:
  - **AWAKE** em ambos
  - **0 sessões em curso** fantasma
  - **0 bloqueios por overlap**

### T2 (offline + conflito sem end imediato)

- A: Start
- B: Start
- pull

**Esperado:**
- estado derivado coerente (SLEEPING)
- conflito pode ser sinalizado (snackbar/modal), mas não bloqueia uso.

### T3 (clock-skew)

- Device A com relógio adiantado: Start/End
- Device B normal: pull

**Esperado:**
- B recebe End (não fica preso)
- logs mostram clamp/buffer e cursor nunca no futuro.

---

## 11) Ficheiros importantes (mapa rápido)

### UI
- `apps/mobile/lib/presentation/pages/home_sleep_page.dart`
- `apps/mobile/lib/presentation/pages/day_detail_page.dart`

### Domain (derivação)
- `apps/mobile/lib/domain/value_objects/sleep_state.dart`
- `apps/mobile/lib/domain/value_objects/sleep_session.dart`

### Providers / aplicação
- `apps/mobile/lib/application/providers/sleep_events_provider.dart`
- `apps/mobile/lib/application/providers/sleep_state_provider.dart`
- `apps/mobile/lib/application/providers/sync_provider.dart`

### Sync
- `apps/mobile/lib/sync/sync_strategies/pull_strategy_impl.dart`
- `apps/mobile/lib/sync/layered_sync_orchestrator.dart`

### Data sources
- `apps/mobile/lib/data/datasources/local/sleep_event_local_datasource_impl.dart`
- `apps/mobile/lib/data/datasources/remote/sleep_event_remote_datasource_impl.dart`

### Backend contract/docs
- `docs/06_backend_contract_sleep_mvp.md`
- `backend/supabase/migrations/001_create_tables.sql`

