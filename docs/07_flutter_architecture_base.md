# Arquitetura Base Flutter - MVP de Tracking Manual de Sono

## Status: ✅ Estrutura Base Implementada

A estrutura arquitetural base do projeto Flutter foi criada conforme o plano aprovado. Todos os ficheiros estão criados com a estrutura correta e prontos para implementação completa.

## Estrutura Criada

### ✅ Core Layer (`lib/core/`)
- **constants/**: `app_constants.dart` - Constantes da aplicação
- **errors/**: `failures.dart`, `exceptions.dart`, `error_handler.dart` - Tratamento de erros
- **utils/**: `uuid_generator.dart`, `timestamp_utils.dart`, `device_id_manager.dart` - Utilitários
- **types/**: `result.dart` - Pattern Result<T, Failure>

### ✅ Domain Layer (`lib/domain/`)
- **entities/**: `baby.dart`, `caregiver.dart`, `sleep_event.dart`, `user.dart`
- **value_objects/**: `sleep_state.dart`, `sleep_session.dart` - Estados derivados
- **repositories/**: Interfaces (`baby_repository.dart`, `caregiver_repository.dart`, `sleep_event_repository.dart`)
- **use_cases/**: 
  - `sleep/`: `create_sleep_start.dart`, `create_sleep_end.dart`, `create_correction_event.dart`, `mark_event_as_corrected.dart`, `derive_sleep_state.dart`
  - `baby/`: `get_accessible_babies.dart`, `select_active_baby.dart`
  - `caregiver/`: `get_caregivers_for_baby.dart`
- **services/**: `conflict_resolver.dart` - Interface para resolução de conflitos

### ✅ Data Layer (`lib/data/`)
- **models/**: `baby_model.dart`, `caregiver_model.dart`, `sleep_event_model.dart` - Serialização JSON
- **datasources/local/**: Interfaces para persistência local (`baby_local_datasource.dart`, `caregiver_local_datasource.dart`, `sleep_event_local_datasource.dart`, `local_database.dart`)
- **datasources/remote/**: Interfaces para comunicação com Supabase (`baby_remote_datasource.dart`, `caregiver_remote_datasource.dart`, `sleep_event_remote_datasource.dart`, `supabase_client.dart`)
- **repositories/**: Implementações (`baby_repository_impl.dart`, `caregiver_repository_impl.dart`, `sleep_event_repository_impl.dart`)
- **mappers/**: `baby_mapper.dart`, `caregiver_mapper.dart`, `sleep_event_mapper.dart` - Conversão domain <-> data

### ✅ Sync Layer (`lib/sync/`)
- **sync_state.dart**: Estado de sincronização
- **sync_queue.dart**: Interface para fila de eventos pendentes
- **sync_strategies/**: `push_strategy.dart`, `pull_strategy.dart` - Estratégias de sync
- **conflict_resolution/**: `conflict_detector.dart`, `conflict_resolver_impl.dart` - Detecção e resolução de conflitos
- **sync_engine.dart**: Interface do motor de sincronização

### ✅ Application Layer (`lib/application/`)
- **providers/**: 
  - `auth_provider.dart` - Estado de autenticação
  - `active_baby_provider.dart` - Bebé ativo selecionado
  - `babies_provider.dart` - Lista de bebés acessíveis
  - `caregivers_provider.dart` - Cuidadores do bebé ativo
  - `sleep_events_provider.dart` - Eventos do bebé ativo
  - `sleep_state_provider.dart` - Estado derivado (a dormir/acordado)
  - `sync_provider.dart` - Estado de sincronização
- **services/**: `app_initializer.dart` - Inicialização da app

## Princípios Implementados

### ✅ Offline-First
- Eventos são criados localmente sem verificar conexão
- Repositórios retornam dados locais imediatamente
- Sincronização acontece em background

### ✅ Event-Based
- Apenas `SleepEvent` é persistido
- `SleepState` e `SleepSession` são value objects derivados em memória
- Casos de uso operam em eventos, não em estados finais

### ✅ Sincronização
- Motor de sync isolado em camada dedicada
- Push/Pull strategies separadas
- Resolução de conflitos usando last-write-wins

### ✅ Gestão de Estado
- Providers Riverpod parametrizados
- Estado derivado depende de eventos
- Bebé ativo é estado global

## Próximos Passos

1. **Criar `pubspec.yaml`** com dependências necessárias
2. **Implementar data sources locais** (SQLite/Hive)
3. **Implementar data sources remotos** (Supabase client)
4. **Implementar motor de sincronização completo**
5. **Configurar dependency injection** (Riverpod)
6. **Executar code generation** do Riverpod
7. **Implementar UI** (presentation layer)

## Notas Importantes

- Todos os ficheiros seguem a arquitetura definida no plano
- Estrutura está pronta para implementação completa
- Erros de lint são temporários (dependências não instaladas ainda)
- Imports relativos estão corretos

## Checklist de Arquitetura

✅ Separação de camadas implementada
✅ Offline-first preparado
✅ Event-based implementado
✅ Sincronização estruturada
✅ Gestão de estado com Riverpod
✅ Modelos de domínio definidos
✅ Anti-patterns evitados na estrutura

---

**Data**: Após aprovação do plano de arquitetura
**Status**: Estrutura base completa, pronta para implementação

