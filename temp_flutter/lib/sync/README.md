# Sync Module

## Overview

This module handles synchronization between local SQLite storage and Supabase backend.
Currently implements **PUSH only** (local → remote).

## Architecture

```
SyncProvider (Riverpod)
    ↓
SyncPushEngine
    ↓
PushStrategyImpl
    ↓
┌─────────────────┐    ┌─────────────────────────┐
│ Local SQLite    │ →  │ Supabase (Remote)       │
│ SleepEventLocal │    │ SleepEventRemote        │
└─────────────────┘    └─────────────────────────┘
```

## Configuration

### 1. Create `.env` file

Create a `.env` file in the project root with your Supabase credentials:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

⚠️ **Never commit `.env` to version control!**

### 2. Initialize Supabase

In `main.dart`, initialize Supabase before `runApp()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientImpl.initialize();
  runApp(MyApp());
}
```

## Usage

### Push events for a baby

```dart
final syncNotifier = ref.read(syncProvider.notifier);
await syncNotifier.pushForBaby(babyId);
```

### Push all pending events

```dart
await syncNotifier.pushAll();
```

### Monitor sync state

```dart
final syncState = ref.watch(syncProvider);

// Check status
if (syncState.status == SyncStatus.syncing) {
  // Show loading indicator
}

if (syncState.status == SyncStatus.error) {
  // Show error: syncState.errorMessage
}

if (syncState.status == SyncStatus.success) {
  // Show last sync: syncState.lastSyncedAt
}
```

## Error Handling

### Error Types

| Type | Behavior | Example |
|------|----------|---------|
| **Transient** | Stop push, retry later | Network timeout |
| **Permission** | Mark event, continue | RLS blocking |
| **Validation** | Mark event, continue | Constraint violation |
| **Duplicate** | Treat as success | Event already exists |

### Permanent Errors

Events with permanent errors (permission/validation) are marked in `metadata.sync_error`:

```json
{
  "sync_error": {
    "type": "permission",
    "message": "RLS policy violation",
    "timestamp": "2024-01-01T00:00:00Z"
  }
}
```

## Idempotency

The push is idempotent:
- Events have UUIDs generated locally before sync
- Supabase has UNIQUE constraint on `id`
- Duplicate inserts are treated as success
- Re-running push is safe

## Future Work

- [ ] PULL strategy (remote → local)
- [ ] Conflict resolution (last-write-wins)
- [ ] Background sync
- [ ] Retry with exponential backoff

