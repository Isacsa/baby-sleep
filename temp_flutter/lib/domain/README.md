# Domain Layer - MVP de Tracking Manual de Sono

## Status: ✅ Implementação Completa

A camada domain está completamente implementada de forma isolada, pura e independente.

## Estrutura Implementada

### ✅ Common (`lib/domain/common/`)
- **result.dart**: Pattern Result<T> para domain layer (DomainResult, DomainSuccess, DomainError)
- **failure.dart**: Tipos de falhas do domínio (ValidationFailure, PermissionFailure, NetworkFailure, StorageFailure)

### ✅ Entities (`lib/domain/entities/`)
- **baby.dart**: Entidade Baby (imutável)
- **caregiver.dart**: Entidade Caregiver com enum CaregiverRole (imutável)
- **sleep_event.dart**: Entidade SleepEvent com enum SleepEventType (imutável)
- **user.dart**: Entidade User (imutável)

### ✅ Value Objects (`lib/domain/value_objects/`)
- **sleep_state.dart**: SleepState derivado de eventos (não persistido)
- **sleep_session.dart**: SleepSession derivado de eventos (não persistido)

### ✅ Repositories (`lib/domain/repositories/`)
- **baby_repository.dart**: Interface abstrata para acesso a babies
- **caregiver_repository.dart**: Interface abstrata para acesso a caregivers
- **sleep_event_repository.dart**: Interface abstrata para acesso a sleep events

### ✅ Use Cases (`lib/domain/use_cases/`)

#### Sleep
- **create_sleep_start.dart**: Cria evento SleepStart
- **create_sleep_end.dart**: Cria evento SleepEnd
- **create_correction_event.dart**: Cria evento de correção
- **mark_event_as_corrected.dart**: Marca evento como corrigido
- **derive_sleep_state.dart**: Deriva estado atual do sono

#### Baby
- **get_accessible_babies.dart**: Obtém bebés acessíveis ao utilizador
- **select_active_baby.dart**: Valida acesso a um bebé

#### Caregiver
- **get_caregivers_for_baby.dart**: Obtém cuidadores de um bebé

### ✅ Services (`lib/domain/services/`)
- **conflict_resolver.dart**: Interface e implementação de resolução de conflitos (last-write-wins)

## Características da Implementação

### ✅ Independência Total
- **Zero dependências externas**: Não depende de Flutter, Riverpod, Supabase, SQLite, Hive ou qualquer package
- **Tipos próprios**: DomainResult e DomainFailure são definidos dentro de domain
- **Dart puro**: Apenas biblioteca padrão do Dart

### ✅ Imutabilidade
- Todas as entidades são imutáveis (final fields, const constructors)
- Métodos `copyWith` para criar cópias modificadas
- Value objects são imutáveis

### ✅ Regras de Domínio Implementadas

**SleepEvent**:
- É a única entidade persistida para sono
- Nunca é apagado
- Correções são sempre novos eventos
- `isCorrected = true` invalida o evento para derivação de estado

**DeriveSleepState**:
- Filtra eventos com `isCorrected = false`
- Ordena por `timestamp DESC, createdAt DESC`
- Se último evento válido for `SleepStart` → `isSleeping = true`
- Se for `SleepEnd` → `isSleeping = false`

**SleepSession**:
- NÃO é persistida
- É derivada agrupando `SleepStart` → `SleepEnd`
- Pode existir sessão incompleta (sem `SleepEnd`)

**ConflictResolver**:
- Implementa lógica last-write-wins
- Nunca apaga eventos
- Apenas define qual evento é dominante para derivação

### ✅ Validações Implementadas

**CreateSleepStart/CreateSleepEnd**:
- Valida timestamp é UTC
- Valida timestamp não é > 1 hora no futuro
- Valida createdAt é UTC
- Valida permissões (caregiver existe e pode escrever)

**CreateCorrectionEvent**:
- Valida evento original existe
- Valida evento original pertence ao mesmo baby
- Valida permissões

**MarkEventAsCorrected**:
- Valida evento existe
- Valida evento de correção existe
- Valida ambos pertencem ao mesmo baby

## Testabilidade

A camada domain é 100% testável como lógica pura:
- Sem dependências de frameworks
- Sem side effects (exceto chamadas a repositórios que são abstrações)
- Entidades e value objects são testáveis unitariamente
- Casos de uso são testáveis com mocks de repositórios

## Próximos Passos

1. Implementar testes unitários para entidades e value objects
2. Implementar testes unitários para casos de uso (com mocks)
3. Implementar testes para ConflictResolver
4. Implementar camada data (repositórios concretos)
5. Implementar camada application (providers)

---

**Data**: Após aprovação da arquitetura
**Status**: ✅ Implementação completa e independente

