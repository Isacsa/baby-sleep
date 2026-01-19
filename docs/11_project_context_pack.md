# Project Context Pack (Handoff para Novo Chat)

**Última atualização:** 2026-01-17  
**Stack:** Flutter (mobile) + SQLite (offline-first) + Supabase (Auth + RLS + persistência + partilha)  
**Domínio:** tracking parental centrado no bebé (dados sensíveis)

> **Regra de ouro:** a fonte de verdade do domínio/decisões está em `docs/*.txt` e nos `.md` do contrato. Evitar assumir decisões fora desses ficheiros.

---

## 1) O que é o projeto (TL;DR)

App mobile offline-first para registo manual de sono de bebés:
- Registo com **1–2 toques**, pensado para uso noturno
- **Multi-cuidador** e **multi-device** desde início
- **Estado derivado** no cliente (backend não calcula “a dormir/acordado”)
- Convergência eventual via sync (push/pull)

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
- Correções auditáveis (`is_corrected/corrected_by`, metadata)
- Multi-device: resolução determinística de starts duplicados + correção de eventos órfãos no overwrite
- Sync robusto ao clock-skew (clamp + safety window) + auto-sync após ações (debounce)
- Indicador de pendentes (badge no chip de sync)

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

---

## 9) Mapa rápido de ficheiros (onde mexer para quê)

### UI
- `apps/mobile/lib/presentation/pages/home_sleep_page.dart`
- `apps/mobile/lib/presentation/pages/day_detail_page.dart`
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
- Auto-sync está desenhado para UX “sem esforço”, mas pode evoluir para backoff e triggers por conectividade/resume quando fizer sentido.

