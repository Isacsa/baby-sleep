# Arquitetura Flutter - MVP de Tracking Manual de Sono

## Estrutura do Projeto

Este projeto segue uma **Clean Architecture adaptada para Flutter**, com separação clara em camadas:

```
lib/
├── core/           # Utilitários, constantes, tipos base, tratamento de erros
├── domain/         # Lógica de negócio pura (entidades, value objects, casos de uso)
├── data/           # Implementação de persistência (modelos, data sources, repositórios)
├── sync/           # Motor de sincronização isolado
├── application/    # State management (Riverpod providers)
└── presentation/   # UI (futuro - não implementado ainda)
```

## Princípios Arquiteturais

### Offline-First
- Eventos são criados localmente sem verificar conexão
- Estado derivado é calculado a partir de dados locais
- Sincronização acontece em background, não bloqueia UI
- Repositórios retornam dados locais imediatamente

### Event-Based
- Apenas `SleepEvent` é persistido, não `SleepSession`
- Estado derivado (`SleepState`) é value object em memória
- Casos de uso operam em eventos, não em estados finais
- Repositórios retornam listas de eventos, nunca estados

### Sincronização
- Motor de sync é isolado em camada dedicada
- Push strategy envia eventos com `syncedAt = NULL`
- Pull strategy recebe eventos com `syncedAt > lastSyncedAt`
- Idempotência garantida via `id` único gerado localmente
- Conflitos resolvidos localmente usando last-write-wins

## Camadas

### Core
Utilitários, constantes, tipos base, tratamento de erros. Sem dependências de domínio ou dados.

### Domain
Lógica de negócio pura. Entidades, value objects, casos de uso, interfaces de repositórios. Zero dependências externas.

### Data
Implementação de persistência. Modelos de dados (JSON), data sources (local/remoto), implementação de repositórios, mappers.

### Sync
Motor de sincronização isolado. Orquestra envio/receção, gerencia fila, resolve conflitos. Depende de `data` mas não de `domain` diretamente.

### Application
State management e coordenação. Providers Riverpod, estado global, inicialização. Depende de `domain` e `sync`.

### Presentation
UI (futuro). Widgets, páginas, navegação. Depende apenas de `application`.

## Próximos Passos

1. Implementar data sources locais (SQLite/Hive)
2. Implementar data sources remotos (Supabase)
3. Implementar motor de sincronização completo
4. Configurar dependency injection (Riverpod)
5. Implementar UI (presentation layer)

