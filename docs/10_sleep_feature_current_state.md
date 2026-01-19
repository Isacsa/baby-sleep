# Sleep Feature — Current State (MVP Sono) — Offline-first + Multi-device

**Última atualização:** 2026-01-17  
**App:** Flutter (`apps/mobile`) + Supabase (auth + RLS + persistência)  
**Domínio:** tracking parental centrado no bebé (dados sensíveis)

> **Fonte de verdade do domínio/contrato** (não duplicar decisões fora destes ficheiros):
> - `docs/02_core_principles.txt`
> - `docs/06_backend_contract_sleep_mvp.md`
> - `docs/08_auth_and_user_context.md`
> - `docs/09_sleep_feature_handoff.md`

---

## 1) Objetivo e promessa da feature

Permitir registar sono manualmente (incluindo retroativo), com experiência simples “de noite”, mantendo:
- **Offline-first**: funciona sem rede; sync é consistência eventual.
- **Event-based**: persistimos eventos (`SleepStart`, `SleepEnd`), não “estado”.
- **Multi-device/multi-cuidador**: operações em paralelo são esperadas; o cliente converge e não bloqueia.
- **Correções auditáveis**: não apagamos histórico; corrigimos com `is_corrected/corrected_by` + metadados.

---

## 2) Modelo de dados (alto nível)

### 2.1 Eventos
Um registo de sono é um **evento** em `sleep_events`:
- `SleepStart`
- `SleepEnd`

Campos relevantes (ver contrato backend):
- `id` (UUID gerado no cliente; idempotência)
- `baby_id`
- `type`
- `timestamp` (quando ocorreu; **ordem lógica**)
- `created_at` (quando foi criado no dispositivo; **tie-break**)
- `caregiver_id` (obrigatório; pertence a `auth.uid()` e ao `baby_id`)
- `device_id` (auditoria)
- `synced_at` (`NULL` enquanto pendente local)
- `is_corrected` / `corrected_by` (preserva histórico)
- `metadata` (motivos/diagnóstico)

### 2.2 Sessões não são persistidas
Uma “sessão de sono” é um **value object derivado** do timeline (`SleepStart` + `SleepEnd`).

---

## 3) Derivação de estado e sessões (cliente)

### 3.1 Estado atual (SLEEPING/AWAKE)
O estado é derivado apenas de eventos válidos (`is_corrected=false`). Regra operacional:
- último evento válido = `SleepStart` ⇒ **SLEEPING**
- último evento válido = `SleepEnd` ⇒ **AWAKE**

Ordenação canónica: `timestamp DESC`, tie-break `created_at DESC`.

Ficheiro: `apps/mobile/lib/domain/value_objects/sleep_state.dart`

### 3.2 Derivação de sessões
`SleepSession.fromEventList(events)` deriva sessões e aplica guardrails para multi-device:
- **Start duplicado** dentro de uma janela curta (conflito multi-device) não cria “sessão fantasma”; a derivação escolhe um **winner determinístico** (mais recente por `created_at`) para consistência.

Ficheiro: `apps/mobile/lib/domain/value_objects/sleep_session.dart`

---

## 4) UX atual (Home)

Ficheiro principal: `apps/mobile/lib/presentation/pages/home_sleep_page.dart`

### 4.1 Botão principal
- Se **AWAKE**: “Dormir agora” (cria `SleepStart(now)`).
- Se **SLEEPING**: “Acordou” (cria `SleepEnd(now)`).

### 4.2 Quick chips
Ex.: “adormeceu há 5/10/15 min”
- cria `SleepStart(now - Xmin)`; intenção: “começou antes e ainda está a dormir”.
- valida overlap por **intervalo** (ver 4.4).

### 4.3 “Outra hora”
Quando **SLEEPING**:
- mostra bottom-sheet com opções:
  - **Terminar sono agora** (cria `SleepEnd(now)`)
  - **Registar sono completo do passado** (wizard início+fim, grava Start+End em transação)
  - **Cancelar**

Quando **AWAKE**:
- permite escolher hora/dia e registar retroativamente.

### 4.4 Overlap e “Substituir sono existente”
Se o registo pretendido colide com sono já registado:
- UI mostra modal com a(s) sessão(ões) em conflito.
- opção **“Substituir”** executa overwrite atómico:
  - corrige eventos antigos (`is_corrected=true`, `corrected_by=...`)
  - cria eventos de correção (auditável)
  - cria o(s) novo(s) evento(s) pretendidos
  - tudo em **transação SQLite**.

O utilizador recebe feedback por snackbar; em caso de erro, existe **retry**.

---

## 5) Sync (offline-first, consistência eventual)

### 5.1 Componentes
- Provider: `apps/mobile/lib/application/providers/sync_provider.dart`
- Orquestrador push: `apps/mobile/lib/sync/layered_sync_orchestrator.dart`
- Pull incremental: `apps/mobile/lib/sync/sync_strategies/pull_strategy_impl.dart`
- Local DS: `apps/mobile/lib/data/datasources/local/sleep_event_local_datasource_impl.dart`
- Remote DS: `apps/mobile/lib/data/datasources/remote/sleep_event_remote_datasource_impl.dart`

### 5.2 Push (local → Supabase)
Objetivo: enviar entidades locais pendentes (`synced_at=NULL`) respeitando dependências (FK):
1. Babies
2. Caregivers
3. SleepEvents

**Idempotência**: o `id` é client-generated; re-tentativas não podem criar duplicados.

### 5.3 Pull incremental (Supabase → local) com tolerância a clock-skew
Problema estrutural do contrato: `created_at` é **client-provided** ⇒ há clock-skew entre devices.

Mitigação implementada (PullStrategy):
- clamp de `last_synced_at` se estiver no futuro (nunca cursor > now)
- “safety window” (buffer ~ 5 min) para re-buscar eventos recentes
- cursor atualizado como `min(max(created_at recebido), now)` (nunca avança para o futuro)
- se vierem 0 eventos: **não** avançar cursor para `now` (evita “perder” eventos de outros devices)

### 5.4 Merge/upsert local (remoto → SQLite)
Ao receber eventos remotos:
- inserir se não existe local
- se existe: atualizar **apenas campos mutáveis** (`is_corrected`, `corrected_by`, `synced_at`, `metadata`)
- regra importante: não “des-corrigir” local por dados remotos stale (preserva correções locais quando necessário)

---

## 6) Auto-sync após cada ação (caminho recomendado)

Auto-sync foi adotado para reduzir divergência entre devices sem exigir “Sync manual” constante.

### 6.1 Como funciona
Implementado em `SyncProvider`:
- `scheduleSyncAfterLocalChange(babyId)` (debounce 2s)
- `_syncInBackground(babyId)` faz push (layered) + pull e invalida caches no fim
- não bloqueia UI (não muda SyncState para “syncing” durante auto-sync)

Trigger points:
- `SleepEventsNotifier.addEvent()` dispara auto-sync após persistência local.
- operações de correção/overwrite e resolução de conflitos também disparam auto-sync no final.

### 6.2 Transparência para o utilizador
`SyncStatusChip` mostra:
- estado geral de sync
- badge com número de eventos pendentes (“pending”) via provider de contagem (`PendingSyncCount`)

> Mesmo com auto-sync, mantém-se recomendado existir também “sync manual” (forçar sync) para casos de debug/edge.

---

## 7) Resolução de conflitos e correções (multi-device)

### 7.1 Princípios
- conflitos são normais (multi-device/offline)
- a app deve **não bloquear** o utilizador
- resolução é previsível e auditável (last-write-wins + metadata)

### 7.2 Conflitos que tratamos
- **Start duplicado** (2 devices iniciam sono “ao mesmo tempo”): derivação escolhe winner determinístico; existe resolução automática no cliente.
- **Overlap temporal** (registo retroativo cai dentro de sessão existente): UI oferece “substituir” (overwrite atómico).
- **Eventos órfãos no intervalo do overwrite** (ex.: `SleepEnd` isolado): são corrigidos durante o overwrite para evitar que virem “último evento” e flipem o estado.

### 7.3 Como o overwrite preserva histórico
Em vez de apagar:
- evento original é marcado como corrigido (`is_corrected=true`, `corrected_by=...`)
- um novo evento de correção é criado (com `metadata.correction_reason=...`)
- o novo evento pretendido é criado

---

## 8) O que foi corrigido nesta iteração (resumo)

### 8.1 “Sono infinito” / devices divergentes
Principais causas mitigadas:
- clock-skew a afetar pull incremental (cursor a avançar para o futuro)
- derivação/estado a ser influenciado por eventos “órfãos” não corrigidos após “substituir”
- necessidade de propagação rápida de correções entre devices (auto-sync + badge)

### 8.2 UX e fiabilidade
- overlap por intervalo (não só por timestamp pontual)
- overwrite atómico (SQLite transaction)
- retry em erros no overwrite
- contexto de caregiver validado antes de ações

---

## 9) Checklist de regressão (manual)

### A) Quick chip + sync
1. Device A: quick chip “10 min”
2. Confirmar UI muda para “A dormir”
3. Aguardar auto-sync
4. Device B: abrir/app + aguardar ou fazer sync manual
5. Confirmar Device B também está “A dormir” e vê o mesmo timeline

### B) Substituir sono existente
1. Criar sessão curta (ex.: 10:23–10:26)
2. Tentar quick chip que sobrepõe (ex.: 15 min ao fim)
3. Modal de overlap aparece → “Substituir”
4. Confirmar não ficam sessões inconsistentes / estado errado

### C) Multi-device: Start/Start (conflito)
1. Device A: SleepStart
2. Device B: SleepStart quase ao mesmo tempo
3. Sync em ambos
4. Confirmar que não há bloqueio nem “sono infinito”

---

## 10) Limitações conhecidas / hardening futuro (não bloqueante para avançar)

- **Cursor canónico por `synced_at` server-generated** (ideal): reduzir dependência de `created_at` client-provided e clock-skew (ver `docs/09_sleep_feature_handoff.md`, “Fase B”).
- Auto-sync pode evoluir para:
  - triggers por conectividade/resume
  - backoff e classificação de erro permanente vs transitório
- Remoção/limpeza de logs de debug após estabilidade prolongada.

