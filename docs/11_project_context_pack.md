# Project Context Pack (Handoff para Novo Chat)

**Última atualização:** 2026-01-19
**Stack:** Flutter (mobile) + SQLite (offline-first) + Supabase (Auth + RLS + persistência + partilha)
**Domínio:** tracking parental centrado no bebé (dados sensíveis)

> **Regra de ouro:** a fonte de verdade do domínio/decisões está em `docs/*.txt` e nos `.md` do contrato. Evitar assumir decisões fora desses ficheiros.

---

## 1) O que é o projeto (TL;DR)

App mobile offline-first para registo manual de sono de bebés:
- Registo com **1–2 toques**, pensado para uso noturno
- **Multi-cuidador** e **multi-device** desde início
- **Estado derivado** no cliente (backend não calcula “a dormir/acordado”)
- Convergência eventual via sync (push/pull) + **auto-sync/auto-pull** no cliente

Fontes:
- `docs/00_product_vision.txt`
- `docs/02_core_principles.txt`
- `docs/06_backend_contract_sleep_mvp.md`

---

## 2) Princípios e decisões não negociáveis

Fontes: `docs/02_core_principles.txt`, `docs/01_domain_model.txt`, `docs/04_data_and_security.txt`

- **Offline-first**: nenhuma ação do utilizador pode ser bloqueada por ausência de rede.
- **Centrado no bebé**: dados pertencem ao bebé; utilizadores acedem via relação de cuidador.
- **Event-based**: guardamos acontecimentos (eventos), não estados finais.
- **Multi-bebé e multi-cuidador** por defeito.
- **Erro humano é normal**: UX deve permitir correções simples e auditáveis.
- **Resolução de conflitos**: previsível e auditável (regra prática: last-write-wins + metadata).

Segurança:
- Dados são sensíveis; evitar PII em logs e metadados.
- Permissões e isolamento de dados são garantidos por RLS no Supabase.

---

## 3) Modelo de domínio (alto nível)

Fonte: `docs/01_domain_model.txt`

Entidades conceptuais:
- **Baby**: agregador principal do sistema.
- **Caregiver**: relação `(baby_id, user_id)` com papel (`owner|editor|viewer`), usada para autoria/auditoria e permissões.
- **Event**: unidade base de dados (sono e outros módulos).

Sono:
- Persistimos **apenas eventos**: `SleepStart`, `SleepEnd`.
- “Sessão de sono” é derivada, não persistida.
- Correções são novos eventos + marcação do original como corrigido.

---

## 4) Contrato Backend (Supabase) — o que assumir / o que NÃO assumir

Fonte: `docs/06_backend_contract_sleep_mvp.md`

O backend garante:
- Auth + RLS (permissões)
- Persistência idempotente por `id`
- Integridade referencial (FK/constraints) e auditoria
- Sync incremental (suporta cursor/estado de sync)

O backend NÃO faz:
- Não calcula estados derivados (SLEEPING/AWAKE, sessões, estatísticas)
- Não resolve conflitos lógicos (overlaps, Start-Start, etc.)
- Não “adivinha” intenções nem corrige erros humanos

Notas importantes do contrato:
- `timestamp` é a **ordem lógica** do evento.
- `created_at` é **client-provided** (impacta clock-skew em incremental pull).

---

## 5) Arquitetura (visão operacional)

Fonte: `docs/03_architecture_overview.txt`

Camadas:
- **Presentation (Flutter UI)**: UX e estado imediato; não fala diretamente com o backend.
- **Application (Riverpod providers)**: coordena fluxos e expõe estado para UI.
- **Domain**: regras puras (derivação de estado/sessões), use cases e interfaces.
- **Data**: SQLite (local) + Supabase (remote).
- **Sync engine**: push/pull incremental, idempotência, merge e invalidation.

---

## 6) Contexto do utilizador e permissões (crítico para evitar bugs)

Fonte: `docs/08_auth_and_user_context.md`

Conceitos:
- `auth.uid()` é a identidade do user (se não existir sessão, **nenhuma operação remota** deve ser executada).
- `ActiveBabyId` é **device-scoped** (não sincroniza entre dispositivos).
- Para escrever eventos no backend é obrigatório um `caregiver_id` válido (por bebé), pertencente ao `auth.uid()`.

Invariante operacional:
- Sem `CaregiverContext` (caregiver_id + role) → criação de eventos deve ser bloqueada (porque não há `caregiver_id` válido).

---

## 7) Estado atual: Feature Sono (Sleep)

Documento de snapshot (detalhe técnico + UX + sync + conflitos):
- `docs/10_sleep_feature_current_state.md`

Handoff operacional (contexto + problemas multi-device + estratégia):
- `docs/09_sleep_feature_handoff.md`

Resumo do que está implementado e estável:
- Registo Start/End (inclui retroativo via quick chips e “Outra hora”)
- Derivação de estado e sessões no cliente
- Detecção de overlap por **intervalo** + fluxo “Substituir” (overwrite atómico SQLite)
- Correções auditáveis (histórico preservado via `is_corrected` + `corrected_by` quando aplicável + `metadata`)
- Multi-device: resolução determinística de starts duplicados + correção de eventos órfãos no overwrite
- Sync robusto ao clock-skew (clamp + safety window) + auto-sync após ações (debounce)
- **Auto-pull** em foreground + on-resume (para reduzir divergência entre devices sem esforço)
- Indicador de pendentes (badge no chip de sync)
- **Histórico (DayDetail)**: editar/eliminar **sessões completas** (com validação de overlap + correção auditável; não é hard delete)

Notas importantes (implementação atual):
- **“Eliminar” nunca apaga silenciosamente**: é uma correção (event-based). O histórico é preservado; o que some do UI normal é o evento/sessão por ficar `is_corrected=true`.
- **Correções push-safe**: para evitar dependências FK/ciclos em push offline-first, a implementação usa `metadata['corrects_event_id']` no evento de correção, e o `corrected_by` no evento original é preenchido quando é seguro (ver `SleepEventsNotifier._markOriginalCorrectedForLocal`). Isto mantém convergência sem bloquear o utilizador.

---

## 8) Fluxos essenciais (para regressão rápida)

### 8.1 Multi-device convergência (mínimo)
- Device A: quick chip “10 min” → UI muda para “A dormir”
- Aguardar auto-sync
- Device B: abrir + sync → deve convergir para o mesmo estado/timeline

### 8.2 Substituir sono existente
- Registar sono curto
- Tentar registo retroativo que sobrepõe → modal → “Substituir”
- Confirmar que não há “sono infinito” e que ambos devices convergem após sync

### 8.3 Start/Start (conflito multi-device)
- Iniciar sono em dois dispositivos quase ao mesmo tempo
- Sync em ambos
- Confirmar que não bloqueia e converge

### 8.4 Editar sessão (com e sem overlap)
- Ir ao detalhe do dia (`DayDetailPage`) e abrir uma sessão completa
- “Editar” → alterar início/fim
- Caso **sem overlap**: guardar e confirmar que ambos devices convergem após auto-sync/auto-pull
- Caso **com overlap**: confirmar que aparece aviso e que “Substituir” corrige sessões sobrepostas e converge

### 8.5 Eliminar sessão (correção)
- `DayDetailPage` → “Eliminar” numa sessão completa
- Confirmar que desaparece do histórico normal e converge nos outros dispositivos

---

## 9) Mapa rápido de ficheiros (onde mexer para quê)

### UI
- `apps/mobile/lib/presentation/pages/home_sleep_page.dart`
- `apps/mobile/lib/presentation/pages/day_detail_page.dart`
- `apps/mobile/lib/presentation/pages/main_scaffold.dart` (lifecycle: auto-pull on resume/foreground)
- `apps/mobile/lib/presentation/widgets/sync_status_chip.dart`

### Domain (derivação)
- `apps/mobile/lib/domain/value_objects/sleep_state.dart`
- `apps/mobile/lib/domain/value_objects/sleep_session.dart`

### Application (providers)
- `apps/mobile/lib/application/providers/sleep_events_provider.dart`
- `apps/mobile/lib/application/providers/sleep_state_provider.dart`
- `apps/mobile/lib/application/providers/sync_provider.dart`
- `apps/mobile/lib/application/providers/caregiver_context_provider.dart`
- `apps/mobile/lib/application/providers/active_baby_provider.dart`

### Sync
- `apps/mobile/lib/sync/sync_strategies/pull_strategy_impl.dart`
- `apps/mobile/lib/sync/layered_sync_orchestrator.dart`

### Data sources
- `apps/mobile/lib/data/datasources/local/sleep_event_local_datasource_impl.dart`
- `apps/mobile/lib/data/datasources/remote/sleep_event_remote_datasource_impl.dart`

---

## 10) Como estender para novas features (padrão recomendado)

Fonte: `docs/01_domain_model.txt`, `docs/06_backend_contract_sleep_mvp.md` (secção “Preparação para módulos futuros”)

Padrão sugerido para novos módulos (ex.: diário/contexto, feeding, milestones):
- Novo tipo/tabela de eventos com o mesmo shape base:
  - `id`, `baby_id`, `type`, `timestamp`, `caregiver_id`, `device_id`, `created_at`, `synced_at`, `is_corrected`, `corrected_by`, `metadata`
- Derivação/insights no cliente (value objects / services)
- Sync reusa o motor (idempotente, push/pull incremental)
- Correções sempre preservam histórico (nunca apagar silenciosamente)

---

## 11) Limitações conhecidas (não bloqueantes, mas relevantes)

- Como `created_at` é client-provided, clock-skew nunca fica “perfeito” só com heurísticas; o pull atual mitiga com clamp/buffer. Uma melhoria futura é migrar incremental pull para cursor canónico baseado em `synced_at` server-generated (ver `docs/09_sleep_feature_handoff.md`).
- Auto-sync/auto-pull está desenhado para UX “sem esforço”, mas pode evoluir para backoff e triggers por conectividade quando fizer sentido.

---

## 12) Próxima feature: Análise do Sono + Insights + Guia para Pais (novo trabalho)

### 12.1 Objetivo do módulo
Com base **apenas** no sono de cada bebé (eventos e sessões derivadas), gerar:
- **Insights detalhados** sobre o padrão daquele bebé (sempre em tom positivo/educado).
- **Planos/Guias práticos** (ex.: sugestões de rotina, consistência, próximos passos) sem culpabilizar os pais.

### 12.2 Regras não negociáveis (herdadas do core)
- **Offline-first**: insights funcionam sem rede (tudo o que der para calcular deve ser local).
- **Centrado no bebé**: o output é por `baby_id` (multi-bebé desde início).
- **Event-based**: insights são derivados do timeline (não criar “estado” persistido como fonte de verdade).
- **Privacidade**: evitar PII em logs; evitar “comparação entre utilizadores”. Se houver “referências”, devem ser **genéricas** (ex.: ranges públicos por idade), nunca dados de outros utilizadores.

### 12.3 Inputs/Outputs (proposta operacional para começar sem risco)
- **Input**: lista de `SleepEvent` (válidos) → `SleepSession` derivadas → agregados por dia/semana.
- **Output**: objetos de UI “read-only” (ex.: `SleepInsightCard`, `SleepSummary`, “Guia de hoje”), calculados on-device.
- **Importante**: este módulo **não deve escrever** na DB nem alterar eventos; apenas ler e derivar.

### 12.4 Estratégia de implementação (para novo chat começar rápido)
- Criar uma camada “analysis” no **Domain** (serviço puro) que recebe eventos/sessões e devolve:
  - métricas (ex.: total por dia, consistência, hora média de início, variabilidade)
  - insights (mensagens com prioridade/categoria)
  - sugestões (passos pequenos, tom positivo)
- Criar providers na **Application** que:
  - observam `sleepEventsNotifierProvider`
  - calculam insights em background (sem bloquear UI)
  - cacheiam resultados por `baby_id` e janela temporal
- Criar UI dedicada (ex.: página “Insights”) com cards, e um resumo leve na Home.

### 12.5 Guardrails de produto (para “mundo real”)
- Evitar linguagem médica/diagnóstica (“insónia”, “distúrbio”, etc.). Preferir: “padrão”, “tendência”, “pode ajudar”.
- Sempre oferecer explicações simples e acionáveis; nunca alarmista.
- Não expor dados sensíveis em logs/analytics; qualquer telemetry deve ser opt-in e agregada.
