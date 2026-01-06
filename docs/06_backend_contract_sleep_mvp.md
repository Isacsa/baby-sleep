# Backend Contract: Sleep MVP

## 1. Propósito do Contrato

Este documento define o contrato oficial e imutável entre o frontend Flutter e o backend Supabase para o MVP de tracking manual de sono. Este contrato estabelece as garantias, limitações e responsabilidades de cada camada.

### O que este contrato garante

O backend Supabase garante:

- **Autenticação e autorização**: Validação rigorosa de identidade e permissões via Row Level Security (RLS)
- **Persistência idempotente**: Armazenamento seguro e duplicação-preventiva de eventos
- **Integridade referencial**: Relações entre entidades são sempre válidas e consistentes
- **Auditoria completa**: Rastreamento de autoria, origem e correções para todos os eventos
- **Sincronização incremental**: Suporte eficiente para sincronização parcial baseada em estado de sync
- **Isolamento de dados**: Acesso exclusivo a dados de bebés onde o utilizador é cuidador ativo

### O que o backend faz

- Valida e aplica permissões baseadas em papéis de cuidador (owner, editor, viewer)
- Persiste eventos de sono com garantias de idempotência
- Aplica regras de integridade mínima (validação de timestamps, relações, constraints)
- Mantém histórico completo de eventos, incluindo correções
- Fornece queries eficientes para timeline e sincronização incremental
- Garante que pelo menos um owner existe por bebé
- Cria automaticamente o primeiro cuidador (owner) quando um bebé é criado

### O que o backend NÃO faz

- **Não calcula estados derivados**: O backend não determina se o bebé está a dormir ou acordado
- **Não resolve conflitos lógicos**: Não decide qual evento é "correto" em caso de sobreposições ou inconsistências
- **Não valida lógica de domínio**: Não verifica se SleepStart tem SleepEnd correspondente, ou se eventos fazem sentido temporalmente
- **Não corrige erros humanos**: Não tenta "adivinhar" intenções ou corrigir imprecisões automaticamente
- **Não ordena eventos**: Não fornece ordenação canónica além de índices de performance
- **Não sincroniza ativamente**: Não envia notificações push ou polling; o cliente deve fazer pull
- **Não valida offline**: Não bloqueia operações por falta de rede; RLS é avaliado no momento da operação

## 2. Princípios Fundamentais

### Offline-first

O backend assume que o cliente opera em modo offline-first. Eventos são criados localmente com IDs gerados no cliente antes de qualquer comunicação com o backend. O backend aceita eventos criados no passado (retroativos) e não valida se o timestamp é "recente". A sincronização é sempre iniciada pelo cliente, nunca pelo backend.

### Event-based (eventos, não estados)

O backend armazena exclusivamente eventos (`SleepStart`, `SleepEnd`). Não existe conceito de "sessão de sono" ou "estado atual" no backend. Estados são sempre derivados no cliente a partir da sequência de eventos. O backend não valida se a sequência de eventos faz sentido lógico.

### Estado sempre derivado no cliente

O cliente é responsável por derivar o estado atual do bebé (a dormir ou acordado) a partir da sequência de eventos válidos (`is_corrected = false`). O backend não fornece endpoints ou views que retornam estado derivado. Qualquer cálculo de duração, estatísticas ou resumos é responsabilidade exclusiva do cliente.

### Backend como fonte de verdade de permissões, não de estado

O backend é a única fonte de verdade para permissões e autorização. O cliente deve sempre validar permissões via RLS antes de assumir que uma operação é permitida. O backend não é fonte de verdade para estado do bebé, apenas para os eventos que compõem esse estado.

### Consistência eventual

O backend não garante consistência imediata entre dispositivos. Eventos criados em um dispositivo podem demorar a aparecer em outros. Conflitos são esperados e devem ser resolvidos no cliente usando regras simples (last-write-wins baseado em `created_at`).

### Idempotência

Todas as operações de escrita são idempotentes. O mesmo evento (identificado por `id` único) pode ser enviado múltiplas vezes sem criar duplicados. O backend garante unicidade via constraint `UNIQUE(id)` em `sleep_events`.

## 3. Identidade e Contexto do Utilizador

### auth.uid()

O backend identifica o utilizador autenticado exclusivamente via `auth.uid()`, fornecido pelo sistema de autenticação do Supabase. Este valor está sempre disponível em todas as queries e políticas RLS. Se `auth.uid()` for `NULL`, todas as operações são bloqueadas.

### caregiver_id

Cada utilizador autenticado tem uma ou mais relações de cuidador (`caregivers`), cada uma identificada por um `caregiver_id` único. Um utilizador pode ter múltiplos `caregiver_id` (um por bebé). O `caregiver_id` é obrigatório em todos os eventos de sono e deve pertencer ao `auth.uid()` atual. O backend valida que `caregiver_id.user_id = auth.uid()` em todas as operações de escrita.

### baby_id ativo

O cliente deve manter um `baby_id` ativo selecionado pelo utilizador. Todas as operações de leitura e escrita referem-se a este `baby_id`. O backend não mantém estado de "bebé ativo"; esta é responsabilidade do cliente. O cliente deve verificar que o utilizador é cuidador ativo do `baby_id` antes de qualquer operação.

### device_id

Cada evento deve incluir um `device_id` (string livre) que identifica o dispositivo de origem. O backend não valida formato ou unicidade do `device_id`; é responsabilidade do cliente garantir identificação consistente. O `device_id` é usado exclusivamente para auditoria e não afeta permissões ou lógica de negócio.

### Papel do cuidador (owner/editor/viewer)

Cada relação de cuidador tem um papel associado:

- **owner**: Acesso total. Pode criar, ler, atualizar, soft delete de bebé, adicionar/remover cuidadores, alterar papéis.
- **editor**: Acesso de escrita. Pode criar e atualizar eventos, adicionar cuidadores (exceto owner), não pode soft delete de bebé nem alterar papéis.
- **viewer**: Acesso de leitura. Pode apenas ler dados, não pode criar nem atualizar eventos.

O papel é avaliado pelo backend via RLS em todas as operações. O cliente não deve assumir permissões sem validar via tentativa de operação ou query de verificação.

### Garantias de segurança via RLS

O backend garante que:

- Utilizadores só acedem a bebés onde são cuidadores ativos (`deleted_at IS NULL`)
- Utilizadores só criam eventos com `caregiver_id` que lhes pertence
- Utilizadores só atualizam dados onde têm permissão (owner/editor para escrita, viewer para leitura)
- Bebés soft deleted (`deleted_at IS NOT NULL`) não são visíveis via RLS
- Cuidadores soft deleted não têm acesso, mas eventos históricos mantêm `caregiver_id` para auditoria

## 4. Queries Oficiais Permitidas (Contrato)

### 4.1. Obter bebé(s) acessíveis ao utilizador

**Nome lógico**: `GetAccessibleBabies`

**Quem pode executar**: Qualquer utilizador autenticado que seja cuidador de pelo menos um bebé.

**Input necessário**: Nenhum (utiliza `auth.uid()` implicitamente).

**Output esperado**: Lista de objetos `Baby` onde:
- `id`: UUID do bebé
- `name`: Nome do bebé
- `created_at`: Timestamp de criação
- `created_by`: UUID do utilizador criador
- `birth_date`: Data de nascimento (opcional, pode ser NULL)
- `updated_at`: Timestamp de última atualização
- `deleted_at`: Sempre NULL (bebés soft deleted não são retornados)

**Erros possíveis**:
- `auth.uid()` é NULL: Operação bloqueada por RLS
- Utilizador não é cuidador de nenhum bebé: Lista vazia (não é erro)

**Observações importantes**:
- A query deve filtrar por `deleted_at IS NULL` explicitamente (RLS já garante, mas é boa prática)
- Ordenação é responsabilidade do cliente (sugestão: `ORDER BY created_at DESC`)
- O cliente deve cachear esta lista localmente e atualizar via sincronização incremental

### 4.2. Selecionar bebé ativo

**Nome lógico**: `SelectActiveBaby`

**Quem pode executar**: Qualquer utilizador autenticado que seja cuidador do `baby_id` especificado.

**Input necessário**: `baby_id` (UUID).

**Output esperado**: Objeto `Baby` único (mesma estrutura de `GetAccessibleBabies`) ou NULL se não acessível.

**Erros possíveis**:
- `baby_id` não existe ou está soft deleted: NULL retornado (RLS bloqueia)
- Utilizador não é cuidador: NULL retornado (RLS bloqueia)

**Observações importantes**:
- Esta operação é uma query de validação; o estado de "bebé ativo" é mantido no cliente
- O cliente deve verificar permissões antes de assumir que pode operar no `baby_id`
- Se a query retornar NULL, o cliente deve tratar como erro de permissão e atualizar estado local

### 4.3. Obter cuidadores do bebé

**Nome lógico**: `GetCaregiversForBaby`

**Quem pode executar**: Qualquer utilizador autenticado que seja cuidador do `baby_id` especificado.

**Input necessário**: `baby_id` (UUID).

**Output esperado**: Lista de objetos `Caregiver` onde:
- `id`: UUID do cuidador (caregiver_id)
- `baby_id`: UUID do bebé
- `user_id`: UUID do utilizador autenticado
- `role`: Papel do cuidador ('owner', 'editor', 'viewer')
- `created_at`: Timestamp de criação da relação
- `updated_at`: Timestamp de última atualização
- `invited_by`: UUID do utilizador que convidou (opcional, pode ser NULL)
- `deleted_at`: Sempre NULL (cuidadores soft deleted não são retornados)

**Erros possíveis**:
- `baby_id` não existe ou está soft deleted: Lista vazia (RLS bloqueia)
- Utilizador não é cuidador: Lista vazia (RLS bloqueia)

**Observações importantes**:
- O cliente deve identificar o `caregiver_id` próprio para usar em criação de eventos
- A lista inclui todos os cuidadores do bebé, não apenas o utilizador atual
- Ordenação é responsabilidade do cliente (sugestão: `ORDER BY created_at ASC`)

### 4.4. Obter eventos de sono do bebé (timeline)

**Nome lógico**: `GetSleepEventsTimeline`

**Quem pode executar**: Qualquer utilizador autenticado que seja cuidador do `baby_id` especificado (todos os papéis podem ler).

**Input necessário**: 
- `baby_id` (UUID, obrigatório)
- `include_corrected` (boolean, opcional, default: false)
- `limit` (integer, opcional, para paginação)
- `offset` (integer, opcional, para paginação)

**Output esperado**: Lista de objetos `SleepEvent` ordenados por `timestamp DESC, created_at DESC` onde:
- `id`: UUID do evento (gerado no cliente)
- `baby_id`: UUID do bebé
- `type`: Tipo do evento ('SleepStart' ou 'SleepEnd')
- `timestamp`: Timestamp UTC de quando o evento ocorreu (fonte de verdade para ordem)
- `caregiver_id`: UUID do cuidador que criou o evento
- `device_id`: String identificando o dispositivo de origem
- `created_at`: Timestamp UTC de quando foi criado localmente no dispositivo
- `is_corrected`: Boolean indicando se foi invalidado por correção
- `synced_at`: Timestamp UTC de quando foi sincronizado (NULL = não sincronizado)
- `corrected_by`: UUID do evento de correção que invalidou este (NULL se não foi corrigido)
- `metadata`: JSONB com metadados adicionais (opcional, pode ser NULL)

**Erros possíveis**:
- `baby_id` não existe ou está soft deleted: Lista vazia (RLS bloqueia)
- Utilizador não é cuidador: Lista vazia (RLS bloqueia)

**Observações importantes**:
- Por padrão, apenas eventos com `is_corrected = false` devem ser retornados (eventos válidos)
- Se `include_corrected = true`, incluir também eventos corrigidos (útil para visualização de histórico)
- Ordenação canónica: `timestamp DESC, created_at DESC` (mais recente primeiro)
- O cliente deve usar esta ordenação para derivar estado atual
- Paginação é recomendada para grandes volumes de eventos

### 4.5. Criar SleepStart

**Nome lógico**: `CreateSleepStartEvent`

**Quem pode executar**: Utilizador autenticado com papel `owner` ou `editor` do `baby_id` especificado.

**Input necessário**:
- `id`: UUID gerado no cliente (obrigatório, deve ser único globalmente)
- `baby_id`: UUID do bebé (obrigatório)
- `timestamp`: Timestamp UTC de quando o sono começou (obrigatório)
- `caregiver_id`: UUID do cuidador (obrigatório, deve pertencer a `auth.uid()`)
- `device_id`: String identificando o dispositivo (obrigatório)
- `created_at`: Timestamp UTC de quando foi criado localmente (obrigatório)
- `metadata`: JSONB opcional com metadados adicionais

**Output esperado**: Objeto `SleepEvent` criado (mesma estrutura de `GetSleepEventsTimeline`) ou erro.

**Erros possíveis**:
- `auth.uid()` é NULL: RLS bloqueia (erro de autenticação)
- `baby_id` não existe ou está soft deleted: RLS bloqueia (erro de permissão)
- Utilizador não é `owner` ou `editor`: RLS bloqueia (erro de permissão)
- `caregiver_id` não pertence a `auth.uid()`: RLS bloqueia (erro de segurança)
- `caregiver_id` não pertence ao `baby_id`: Trigger valida e bloqueia
- `id` já existe: Constraint de unicidade bloqueia (idempotência: não é erro, evento já existe)
- `timestamp` > 1 hora no futuro: Trigger valida e bloqueia (ajuste de relógio)
- `type` não é 'SleepStart': Constraint bloqueia

**Observações importantes**:
- O cliente deve gerar `id` localmente (UUID v4) antes de qualquer comunicação com o backend
- `timestamp` pode ser no passado (correções retroativas são permitidas)
- `created_at` deve ser o momento exato de criação local, não `timestamp`
- Se `id` já existe, a operação é idempotente (não cria duplicado, não é erro)
- O cliente deve tratar sucesso como confirmação de persistência, não como criação nova

### 4.6. Criar SleepEnd

**Nome lógico**: `CreateSleepEndEvent`

**Quem pode executar**: Utilizador autenticado com papel `owner` ou `editor` do `baby_id` especificado.

**Input necessário**: Idêntico a `CreateSleepStartEvent`, exceto:
- `type`: Deve ser 'SleepEnd'

**Output esperado**: Idêntico a `CreateSleepStartEvent`.

**Erros possíveis**: Idêntico a `CreateSleepStartEvent`, exceto:
- `type` não é 'SleepEnd': Constraint bloqueia

**Observações importantes**: Idêntico a `CreateSleepStartEvent`.

### 4.7. Criar evento de correção

**Nome lógico**: `CreateCorrectionEvent`

**Quem pode executar**: Utilizador autenticado com papel `owner` ou `editor` do `baby_id` especificado.

**Input necessário**: Idêntico a `CreateSleepStartEvent` ou `CreateSleepEndEvent`, mais:
- `corrected_by`: UUID do evento original que está a ser corrigido (obrigatório)
- `is_corrected`: Deve ser `true` (obrigatório quando `corrected_by` está presente)

**Output esperado**: Objeto `SleepEvent` criado (evento de correção).

**Erros possíveis**: Idêntico a criação de eventos normais, mais:
- `corrected_by` não existe: Foreign key constraint bloqueia
- `is_corrected = false` mas `corrected_by IS NOT NULL`: CHECK constraint bloqueia
- `corrected_by` aponta para evento de outro `baby_id`: Validação de integridade bloqueia

**Observações importantes**:
- Correções são sempre novos eventos, nunca atualizações de eventos existentes
- O evento original deve ser marcado como `is_corrected = true` via operação separada
- Cadeias de correções são permitidas (A corrigido por B, B corrigido por C)
- O cliente é responsável por marcar o evento original como corrigido após criar o evento de correção

### 4.8. Marcar evento como corrigido

**Nome lógico**: `MarkEventAsCorrected`

**Quem pode executar**: Utilizador autenticado com papel `owner` ou `editor` do `baby_id` do evento.

**Input necessário**:
- `id`: UUID do evento a marcar como corrigido (obrigatório)
- `corrected_by`: UUID do evento de correção (obrigatório, deve existir e ser do mesmo `baby_id`)

**Output esperado**: Objeto `SleepEvent` atualizado com `is_corrected = true` e `corrected_by` preenchido.

**Erros possíveis**:
- `id` não existe: Erro de recurso não encontrado
- Utilizador não é `owner` ou `editor`: RLS bloqueia
- Campos imutáveis tentados a alterar (`id`, `baby_id`, `type`, `timestamp`, `caregiver_id`, `created_at`): Trigger bloqueia
- `corrected_by` não existe ou pertence a outro `baby_id`: Validação bloqueia

**Observações importantes**:
- Apenas campos mutáveis podem ser atualizados: `is_corrected`, `corrected_by`, `synced_at`, `metadata`
- Esta operação deve ser executada após criar o evento de correção
- O cliente deve garantir que o evento de correção existe antes de marcar o original como corrigido

### 4.9. Sincronização incremental (eventos não sincronizados)

**Nome lógico**: `GetUnsyncedEvents`

**Quem pode executar**: Qualquer utilizador autenticado que seja cuidador do `baby_id` especificado.

**Input necessário**:
- `baby_id`: UUID do bebé (obrigatório)
- `limit`: Integer opcional para limitar resultados

**Output esperado**: Lista de objetos `SleepEvent` onde `synced_at IS NULL`, ordenados por `created_at ASC` (mais antigos primeiro).

**Erros possíveis**:
- `baby_id` não existe ou está soft deleted: Lista vazia (RLS bloqueia)
- Utilizador não é cuidador: Lista vazia (RLS bloqueia)

**Observações importantes**:
- Esta query é usada pelo cliente para identificar eventos locais que precisam ser enviados ao backend
- O cliente deve marcar `synced_at` após sincronização bem-sucedida
- Ordenação por `created_at ASC` garante que eventos mais antigos são sincronizados primeiro
- O cliente deve processar eventos em batch para eficiência

### 4.10. Sincronização incremental (eventos remotos novos)

**Nome lógico**: `GetNewRemoteEvents`

**Quem pode executar**: Qualquer utilizador autenticado que seja cuidador do `baby_id` especificado.

**Input necessário**:
- `baby_id`: UUID do bebé (obrigatório)
- `last_synced_at`: Timestamp UTC da última sincronização bem-sucedida (obrigatório)
- `limit`: Integer opcional para limitar resultados

**Output esperado**: Lista de objetos `SleepEvent` onde `synced_at > last_synced_at` ou `synced_at IS NOT NULL AND created_at > last_synced_at`, ordenados por `synced_at ASC` ou `created_at ASC`.

**Erros possíveis**:
- `baby_id` não existe ou está soft deleted: Lista vazia (RLS bloqueia)
- Utilizador não é cuidador: Lista vazia (RLS bloqueia)

**Observações importantes**:
- Esta query é usada pelo cliente para receber eventos criados por outros cuidadores ou dispositivos
- O cliente deve manter `last_synced_at` localmente e atualizar após cada sincronização bem-sucedida
- O cliente deve mergear eventos remotos com eventos locais, resolvendo conflitos se necessário
- Ordenação garante que eventos são processados na ordem correta

## 5. Regras de Criação de Eventos

### Quem pode criar

Apenas utilizadores autenticados com papel `owner` ou `editor` podem criar eventos de sono. Utilizadores com papel `viewer` são bloqueados por RLS. O backend valida permissões via função `can_write(baby_id, auth.uid())` em todas as operações de INSERT.

### Como é gerado o ID

O `id` do evento deve ser gerado no cliente (Flutter) antes de qualquer comunicação com o backend. O formato recomendado é UUID v4. O backend não gera IDs para eventos; o cliente é responsável por garantir unicidade global. O backend valida unicidade via constraint `UNIQUE(id)` e trata duplicados como idempotência (não é erro).

### Uso de timestamp vs created_at

- **`timestamp`**: Representa quando o evento ocorreu na realidade (fonte de verdade para ordem lógica). Pode ser no passado (correções retroativas) ou presente. Não pode ser > 1 hora no futuro (trigger bloqueia).
- **`created_at`**: Representa quando o evento foi criado localmente no dispositivo. Deve ser o momento exato de criação, não o `timestamp`. Usado para auditoria e desempate em conflitos quando `timestamp` é idêntico.

O cliente deve sempre fornecer ambos os valores explicitamente. O backend não sobrescreve `created_at`; é sempre o valor fornecido pelo cliente.

### device_id

O `device_id` é uma string livre fornecida pelo cliente. O backend não valida formato, unicidade ou existência. O cliente é responsável por garantir identificação consistente do dispositivo (ex: UUID do dispositivo, nome amigável, etc.). O `device_id` é usado exclusivamente para auditoria e não afeta permissões ou lógica de negócio.

### Comportamento offline

O cliente deve criar eventos localmente mesmo quando offline. O evento deve ser persistido localmente com `synced_at = NULL`. Quando a conexão for restaurada, o cliente deve sincronizar eventos não sincronizados via `GetUnsyncedEvents` e `CreateSleepStartEvent` / `CreateSleepEndEvent`. O backend não valida se o evento foi criado "recentemente"; eventos com `timestamp` no passado são permitidos.

### Idempotência

Todas as operações de criação são idempotentes. Se o cliente enviar o mesmo evento (mesmo `id`) múltiplas vezes, o backend não cria duplicados. A constraint `UNIQUE(id)` garante unicidade. Se `id` já existe, a operação retorna sucesso (evento já persistido) ou erro de constraint (dependendo da implementação do cliente). O cliente deve tratar ambos como sucesso (evento já existe = objetivo alcançado).

## 6. Regras de Leitura

### O que é visível

Utilizadores autenticados podem ver apenas:
- Bebés onde são cuidadores ativos (`deleted_at IS NULL` em `caregivers` e `babies`)
- Eventos de sono de bebés onde são cuidadores ativos
- Cuidadores de bebés onde são cuidadores ativos
- Dispositivos próprios (`user_id = auth.uid()`)

RLS garante que dados de bebés onde o utilizador não é cuidador são completamente invisíveis (queries retornam lista vazia, não erro).

### Eventos corrigidos

Por padrão, eventos com `is_corrected = true` devem ser filtrados nas queries normais. O cliente deve derivar estado apenas de eventos válidos (`is_corrected = false`). Eventos corrigidos podem ser incluídos em queries explícitas para visualização de histórico ou auditoria, mas não participam na derivação de estado.

### Soft delete

Bebés e cuidadores soft deleted (`deleted_at IS NOT NULL`) não são visíveis via RLS. Queries que tentam aceder a dados soft deleted retornam lista vazia ou NULL, não erro. Eventos de bebés soft deleted também não são visíveis. O cliente não precisa filtrar explicitamente por `deleted_at IS NULL`; RLS já garante isso.

### Ordenação canónica

A ordenação canónica para eventos de sono é:
1. `timestamp DESC` (eventos mais recentes primeiro)
2. `created_at DESC` (desempate: eventos criados mais recentemente primeiro)

Esta ordenação garante que o último evento válido (`is_corrected = false`) é sempre o primeiro na lista. O cliente deve usar esta ordenação para derivar estado atual. O backend não fornece ordenação automática; o cliente deve especificar explicitamente na query.

## 7. Erros Esperados e Comportamento do Cliente

### RLS bloqueio

**Erro**: Operação bloqueada por Row Level Security (erro de permissão).

**Causas possíveis**:
- Utilizador não é cuidador do `baby_id`
- Utilizador não tem papel adequado (viewer tentando escrever)
- Bebé ou cuidador está soft deleted
- `caregiver_id` não pertence a `auth.uid()`

**Comportamento do cliente**:
- Tratar como erro de permissão
- Atualizar estado local (remover bebé da lista se não acessível)
- Informar utilizador que não tem permissão
- Não retentar automaticamente (não é erro transitório)

### Tentativas inválidas

**Erro**: Constraint violation, trigger validation, foreign key violation.

**Causas possíveis**:
- `id` duplicado (idempotência: não é erro, tratar como sucesso)
- `timestamp` > 1 hora no futuro (ajuste de relógio)
- `caregiver_id` não pertence ao `baby_id`
- `corrected_by` não existe ou pertence a outro `baby_id`
- `is_corrected = false` mas `corrected_by IS NOT NULL`

**Comportamento do cliente**:
- Validar dados localmente antes de enviar
- Tratar `id` duplicado como sucesso (idempotência)
- Outros erros: corrigir dados e retentar
- Não silenciar erros de validação (são bugs do cliente)

### Conflitos

**Cenário**: Múltiplos eventos com mesmo `timestamp` ou sobreposições lógicas.

**Comportamento do backend**:
- Backend não detecta nem resolve conflitos
- Aceita todos os eventos como válidos
- Não valida lógica de domínio (ex: SleepStart sem SleepEnd)

**Comportamento do cliente**:
- Detectar conflitos localmente após sincronização
- Aplicar regra de resolução: last-write-wins baseado em `created_at`
- Manter todos os eventos (não apagar)
- Derivar estado usando apenas o último evento válido por `timestamp`
- Se `timestamp` idêntico, usar `created_at` como desempate

### Como o Flutter deve reagir (sem UX, apenas lógica)

**Erro de autenticação**:
- Invalidar sessão local
- Redirecionar para login
- Limpar cache local de autenticação

**Erro de permissão**:
- Atualizar lista de bebés acessíveis
- Remover bebé não acessível do estado local
- Notificar utilizador (via estado, não UI direta)

**Erro de validação**:
- Corrigir dados localmente
- Retentar operação
- Se persistir, marcar evento como "erro de validação" no estado local

**Conflito detectado**:
- Aplicar regra de resolução (last-write-wins)
- Manter todos os eventos no estado local
- Atualizar estado derivado usando eventos resolvidos
- Não apagar eventos conflituosos (histórico preservado)

**Falha de rede**:
- Manter evento em fila local de sincronização
- Retentar quando conexão for restaurada
- Não bloquear criação de novos eventos (offline-first)

## 8. O que o Flutter NÃO deve assumir

### Backend não calcula estado

O Flutter não deve assumir que o backend fornece estado derivado (ex: "bebé está a dormir", "duração da última sessão"). O backend armazena apenas eventos. Qualquer cálculo de estado, duração, estatísticas ou resumos é responsabilidade exclusiva do Flutter.

### Backend não resolve conflitos lógicos

O Flutter não deve assumir que o backend detecta ou resolve conflitos lógicos (ex: SleepStart sem SleepEnd correspondente, sobreposições temporais). O backend aceita todos os eventos como válidos e não aplica lógica de domínio. O Flutter é responsável por detectar e resolver conflitos localmente.

### Backend não corrige erros humanos

O Flutter não deve assumir que o backend tenta "adivinhar" intenções ou corrigir imprecisões automaticamente. O backend valida apenas integridade mínima (constraints, foreign keys, timestamps razoáveis). Correções são sempre explícitas via criação de novos eventos e marcação de eventos originais como corrigidos.

### Backend não "adivinha" intenções

O Flutter não deve assumir que o backend infere intenções a partir de padrões ou contexto. O backend não tem conhecimento de lógica de domínio além de validações mínimas. Todas as decisões de negócio (ex: "este evento corrige aquele", "esta sessão está completa") são responsabilidade do Flutter.

## 9. Preparação para Módulos Futuros

### Como este contrato se estende para milestones, feeding, tips

O contrato atual é específico para o módulo de sono (`sleep_events`). Módulos futuros (milestones, feeding, tips) seguirão o mesmo padrão:

- **Nova tabela de eventos**: `milestone_events`, `feeding_events`, etc.
- **Mesma estrutura base**: `id`, `baby_id`, `type`, `timestamp`, `caregiver_id`, `device_id`, `created_at`, `is_corrected`, `corrected_by`, `synced_at`, `metadata`
- **Mesmas políticas RLS**: Acesso baseado em `baby_id` via `caregivers`, permissões por papel (owner/editor/viewer)
- **Mesmos princípios**: Event-based, offline-first, idempotência, estado derivado no cliente

### O que permanece estável

As seguintes entidades e relações permanecem estáveis e não mudam entre módulos:

- **`babies`**: Entidade central, agregador de todos os dados
- **`caregivers`**: Relação utilizador-bebé com permissões
- **Políticas RLS base**: Acesso sempre via `baby_id` e `caregivers`
- **Princípios fundamentais**: Offline-first, event-based, estado derivado no cliente
- **Padrão de correções**: Sempre novos eventos, histórico preservado

### O que pode crescer sem breaking changes

- **Novas tabelas de eventos**: Adicionar `milestone_events`, `feeding_events` não quebra contrato existente
- **Novos tipos de eventos**: Adicionar novos valores em `type` (ex: 'SleepNap', 'SleepNight') não quebra contrato se cliente trata desconhecidos graciosamente
- **Novos campos em `metadata`**: JSONB permite extensibilidade sem alterar schema
- **Novas funções helper**: Adicionar funções RLS não quebra queries existentes
- **Novos índices**: Adicionar índices não quebra queries existentes

### Breaking changes que NÃO devem acontecer

- Alterar estrutura de `babies` ou `caregivers` (campos obrigatórios, constraints)
- Alterar políticas RLS de acesso base (sempre via `baby_id` e `caregivers`)
- Remover suporte a offline-first (idempotência, `id` gerado no cliente)
- Alterar padrão de correções (sempre novos eventos)
- Remover soft delete (dados devem poder ser recuperados)

## 10. Resumo Executivo

### Checklist final de garantias

✅ **Autenticação e autorização**: Backend valida identidade e permissões via RLS em todas as operações.

✅ **Persistência idempotente**: Eventos podem ser enviados múltiplas vezes sem criar duplicados.

✅ **Integridade referencial**: Relações entre entidades são sempre válidas (foreign keys, constraints).

✅ **Auditoria completa**: Todos os eventos rastreiam autoria (`caregiver_id`), origem (`device_id`), e correções (`corrected_by`).

✅ **Sincronização incremental**: Suporte eficiente para sincronização parcial via `synced_at` e `last_synced_at`.

✅ **Isolamento de dados**: Utilizadores só acedem a dados de bebés onde são cuidadores ativos.

✅ **Offline-first**: Eventos podem ser criados localmente e sincronizados depois, sem validação de "recenticidade".

✅ **Event-based**: Backend armazena apenas eventos, não estados derivados.

✅ **Estado derivado no cliente**: Cliente é responsável por calcular estado atual a partir de eventos válidos.

✅ **Consistência eventual**: Conflitos são esperados e resolvidos no cliente.

✅ **Extensibilidade**: Contrato preparado para módulos futuros sem breaking changes.

### Confirmação de que este contrato é suficiente para iniciar Flutter

Este contrato define de forma completa e não ambígua:

1. **O que o backend faz**: Autenticação, autorização, persistência, integridade, auditoria.
2. **O que o backend não faz**: Cálculo de estado, resolução de conflitos, correção de erros, inferência de intenções.
3. **Como o cliente interage**: Queries oficiais, regras de criação, regras de leitura, tratamento de erros.
4. **O que o cliente não deve assumir**: Backend não calcula estado, não resolve conflitos, não corrige erros.
5. **Preparação para futuro**: Extensibilidade sem breaking changes, padrão estável para novos módulos.

Este contrato é **suficiente e completo** para iniciar o desenvolvimento do frontend Flutter sem necessidade de refactors estruturais futuros. Todas as decisões de arquitetura estão fechadas e documentadas. O Flutter pode implementar a camada de estado local, motor de sincronização, e UX com confiança de que o backend suporta todos os requisitos do MVP de sono.

---

**Versão**: 1.0  
**Data**: Após implementação completa do backend (migrações 001-004)  
**Status**: Contrato fechado e imutável para MVP de Sono

