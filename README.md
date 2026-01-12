# Baby Sleep Monitor

Aplicação mobile para monitorização de sono de bebés. Offline-first, event-based, multi-cuidador.

## Estrutura do Monorepo

```
baby-sleep/
├── apps/
│   └── mobile/          # App Flutter (iOS/Android)
├── backend/
│   └── supabase/        # Schema SQL, migrations, RLS policies
├── docs/                # Documentação de arquitetura e domínio
└── scripts/             # Scripts auxiliares
```

## Quick Start

### Backend (Supabase)

```bash
# Opção 1: Usar script wrapper
./scripts/apply-migrations.sh

# Opção 2: Manual
cd backend/supabase
supabase link --project-ref your-project-ref
supabase db push
```

Ver [backend/supabase/README.md](backend/supabase/README.md) para detalhes.

### App Mobile (Flutter)

```bash
cd apps/mobile

# Criar ficheiro .env com credenciais Supabase
cp .env.example .env  # Editar com as tuas credenciais

# Instalar dependências
flutter pub get

# Gerar código Riverpod
flutter pub run build_runner build --delete-conflicting-outputs

# Executar app
flutter run
```

Ver [apps/mobile/lib/sync/README.md](apps/mobile/lib/sync/README.md) para configuração de sync.

## Documentação

| Ficheiro | Descrição |
|----------|-----------|
| [docs/00_product_vision.txt](docs/00_product_vision.txt) | Visão do produto |
| [docs/01_domain_model.txt](docs/01_domain_model.txt) | Modelo de domínio |
| [docs/02_core_principles.txt](docs/02_core_principles.txt) | Princípios core |
| [docs/03_architecture_overview.txt](docs/03_architecture_overview.txt) | Arquitetura geral |
| [docs/06_backend_contract_sleep_mvp.md](docs/06_backend_contract_sleep_mvp.md) | Contrato backend |
| [docs/07_flutter_architecture_base.md](docs/07_flutter_architecture_base.md) | Arquitetura Flutter |
| [docs/08_auth_and_user_context.md](docs/08_auth_and_user_context.md) | Auth e contexto |

## Princípios

- **Offline-first**: App funciona sem internet, sync eventual
- **Event-based**: Estados derivados de eventos, não armazenados
- **Multi-cuidador**: Múltiplos cuidadores por bebé com roles (owner/editor/viewer)
- **Clean Architecture**: Domain puro, data layer isolada, sync layer dedicada

## Tech Stack

- **Mobile**: Flutter + Riverpod + SQLite (sqflite)
- **Backend**: Supabase (PostgreSQL + Auth + RLS)
- **Sync**: Manual/semi-automático (push/pull)

## Desenvolvimento

### Verificar Flutter

```bash
cd apps/mobile
dart analyze lib/
flutter test
```

### Verificar Migrations

```bash
ls backend/supabase/migrations/
```

## Licença

Projeto privado.
