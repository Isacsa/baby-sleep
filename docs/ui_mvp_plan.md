# Baby Sleep Monitor - MVP Plan

## Visão Geral

App mobile offline-first para tracking de sono de bebés, focado em simplicidade e fiabilidade.

## Prioridades de Features

### P0 - MVP Core (Must Have)

| Feature | Status | Descrição |
|---------|--------|-----------|
| Login/Auth | Implementado | Magic Link via Supabase |
| Lista de Babies | Implementado | Pull global + criar local |
| Selecionar Baby Ativo | Implementado | Persiste localmente |
| Home com Estado Derivado | Implementado | SLEEPING/AWAKE baseado em eventos |
| Start/End Sleep | Implementado | Offline-first, funciona sem rede |
| Caregiver Context Auto | Implementado | Pull automático ao selecionar baby |
| Timeline de Eventos | Implementado | Lista cronológica |
| Sync Manual | Implementado | Push/pull por baby |

### P1 - MVP Útil (Should Have)

| Feature | Status | Descrição |
|---------|--------|-----------|
| Insights Básicos | Não iniciado | Duração média, última semana |
| Correção de Eventos | Não iniciado | Criar evento de correção |
| Notificações | Não iniciado | Lembrar de registar sono |
| Dark Mode | Parcial | Tema do sistema |

### P2 - Pós-MVP (Nice to Have)

| Feature | Status | Descrição |
|---------|--------|-----------|
| Gráficos de Sono | Não iniciado | Visualização semanal/mensal |
| Partilhar Baby | Não iniciado | Convites para outros cuidadores |
| Export de Dados | Não iniciado | CSV/JSON |
| Multi-idioma | Não iniciado | PT/EN |

## Páginas MVP

| Página | Rota | Status | Features |
|--------|------|--------|----------|
| LoginPage | `/` | Implementado | Magic Link, validação email |
| BabiesPage | `/babies` | Implementado | Lista, pull global, criar local |
| BabyHomePage | `/baby` | Implementado | Estado, Start/End, Sync status |
| TimelinePage | `/timeline` | Implementado | Lista eventos com type/timestamp |
| DebugPage | `/debug` | Implementado | Apenas em debug mode |
| InsightsPage | `/insights` | Não iniciado | P1 - estatísticas |

## User Flows Principais

### Flow 1: Device Novo (Primeira Vez)

```
Login (Magic Link)
    ↓
Pull Babies (Global)
    ↓
Selecionar Baby
    ↓
[Auto: Pull Caregivers]
    ↓
Home → Start/End disponível
```

**Critério de sucesso:** Utilizador consegue começar a registar sono em menos de 1 minuto após login.

### Flow 2: Criar Baby Local

```
Login
    ↓
Criar Baby (offline)
    ↓
[Auto: Caregiver Owner criado]
    ↓
Selecionar Baby
    ↓
Home → Start/End disponível (offline)
```

**Critério de sucesso:** Baby criado localmente permite Start/End imediatamente, mesmo sem rede.

### Flow 3: Logging de Sono

```
Home → Ver estado (SLEEPING/AWAKE)
    ↓
Clicar Start Sleep
    ↓
Evento criado localmente (instant)
    ↓
Estado muda para SLEEPING
    ↓
[Tempo passa...]
    ↓
Clicar End Sleep
    ↓
Estado muda para AWAKE
    ↓
Timeline atualiza
    ↓
[Opcional] Sync Now → envia para backend
```

**Critério de sucesso:** Criar evento leva < 100ms, funciona offline.

### Flow 4: Multi-Device

```
Device A: Criar eventos offline
    ↓
Device A: Sync Now → push eventos
    ↓
Device B: Sync Now → pull eventos
    ↓
Device B: Mesmos eventos visíveis
```

**Critério de sucesso:** Eventos sincronizam entre devices sem conflitos.

### Flow 5: Offline → Online

```
Criar eventos offline (múltiplos)
    ↓
Sem rede (indicador visual)
    ↓
Liga rede
    ↓
Sync Now → push todos os pending
    ↓
Eventos no backend
```

**Critério de sucesso:** Eventos offline não se perdem, sync é idempotente.

## Estados UI Importantes

### Caregiver Context

| Estado | UI | Botão Start/End |
|--------|----|--------------| 
| Initial | - | Disabled |
| Loading | "A preparar permissões..." | Disabled |
| Ready | - | Enabled |
| OfflineNoCaregiver | CTA "Precisas de estar online 1x" | Disabled |
| Error | Mensagem de erro + Retry | Disabled |

### Sync Status

| Estado | Chip | Ação |
|--------|------|------|
| Idle | - | Sync Now disponível |
| Syncing | Spinner | Sync Now disabled |
| Success | Check verde | - |
| Error | X vermelho | Retry disponível |

## Critérios de Sucesso MVP

### Funcionalidade

- [ ] Pais conseguem criar baby e começar a registar sono imediatamente
- [ ] App funciona offline (criar eventos sem rede)
- [ ] Sync é opcional (não bloqueia uso)
- [ ] Multi-device funciona (mesma conta, múltiplos devices)
- [ ] Erros são visíveis e acionáveis (nunca silenciosos)

### UX

- [ ] Fluxo claro: Login → Selecionar Baby → Começar a registar
- [ ] Estados visíveis (SLEEPING/AWAKE)
- [ ] Timeline mostra histórico
- [ ] Erros têm CTAs claros (ex: "Tentar novamente")
- [ ] Loading states em todas as operações assíncronas

### Performance

- [ ] App abre rápido (< 2s até interativo)
- [ ] Criar evento é instantâneo (< 100ms)
- [ ] Sync não bloqueia UI
- [ ] Pull de babies/caregivers é rápido (< 3s com boa rede)

### Fiabilidade

- [ ] Eventos offline nunca se perdem
- [ ] Sync é idempotente (pode repetir sem duplicar)
- [ ] Conflitos são resolvidos automaticamente
- [ ] App recupera de erros de rede graciosamente

## Arquitetura (Resumo)

```
┌──────────────────────────────────────────────────────┐
│                    Presentation                       │
│  LoginPage, BabiesPage, BabyHomePage, TimelinePage   │
└───────────────────────┬──────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────┐
│                    Application                        │
│  Providers (Riverpod): Auth, Babies, Caregivers,     │
│  SleepEvents, SleepState, Sync, CaregiverContext     │
└───────────────────────┬──────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────┐
│                      Domain                           │
│  Entities, Use Cases, Repositories (interfaces)       │
└───────────────────────┬──────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────┐
│                       Data                            │
│  SQLite (offline-first), Supabase (sync)             │
└──────────────────────────────────────────────────────┘
```

## Próximos Passos

1. **Testar flow completo** em device físico
2. **Adicionar Insights básicos** (P1)
3. **Melhorar error handling** com mensagens localizadas
4. **Adicionar testes** (widget + integration)
5. **Preparar release** (ícones, splash, app store metadata)
