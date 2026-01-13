import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/application/providers/auth_provider.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource_impl.dart';
import 'package:temp_flutter/domain/entities/caregiver.dart';
import 'package:temp_flutter/application/providers/caregivers_provider.dart';

part 'caregiver_context_provider.g.dart';

/// CaregiverContextState - Estados possíveis do contexto de caregiver
/// 
/// Usado para garantir que o utilizador tem caregiver local antes de criar eventos.
sealed class CaregiverContextState {
  const CaregiverContextState();
}

/// Estado inicial - ainda não verificado
class CaregiverContextInitial extends CaregiverContextState {
  const CaregiverContextInitial();
}

/// A verificar/carregar caregiver
class CaregiverContextLoading extends CaregiverContextState {
  const CaregiverContextLoading();
}

/// Caregiver disponível - pode criar eventos
class CaregiverContextReady extends CaregiverContextState {
  final Caregiver caregiver;
  const CaregiverContextReady(this.caregiver);
}

/// Erro: offline sem caregiver local
class CaregiverContextOfflineNoCaregiver extends CaregiverContextState {
  final String message;
  const CaregiverContextOfflineNoCaregiver(this.message);
}

/// Erro: permissão negada ou outro erro
class CaregiverContextError extends CaregiverContextState {
  final String message;
  const CaregiverContextError(this.message);
}

/// CaregiverContextNotifier - Garante que o caregiver do utilizador existe localmente
/// 
/// IDEMPOTÊNCIA: Se já verificou e está Ready, não faz nada.
/// 
/// Fluxo:
/// 1. Verifica se caregiver existe localmente (SQLite)
/// 2. Se existe → CaregiverContextReady
/// 3. Se não existe:
///    a. Se online → faz pull apenas de caregivers
///    b. Se offline → CaregiverContextOfflineNoCaregiver
@riverpod
class CaregiverContext extends _$CaregiverContext {
  // Cache para evitar múltiplas verificações na mesma sessão
  static final Map<String, bool> _verifiedBabies = {};

  CaregiverLocalDataSourceImpl get _localDataSource => CaregiverLocalDataSourceImpl();
  CaregiverRemoteDataSourceImpl get _remoteDataSource => CaregiverRemoteDataSourceImpl();

  @override
  CaregiverContextState build() {
    // Observar mudanças no active baby para invalidar cache
    final activeBaby = ref.watch(activeBabyProvider);
    if (activeBaby == null) {
      return const CaregiverContextInitial();
    }
    
    // Se já foi verificado para este baby nesta sessão, verificar localmente
    if (_verifiedBabies[activeBaby.id] == true) {
      // Verificar se ainda existe localmente (pode ter sido removido)
      _checkLocalCaregiver(activeBaby.id);
    }
    
    return const CaregiverContextInitial();
  }

  /// Garante que o caregiver do utilizador atual existe localmente
  /// 
  /// IDEMPOTENTE: Se já está Ready, retorna imediatamente.
  /// Se já está Loading, não inicia nova verificação.
  Future<void> ensureContext() async {
    final currentState = state;
    
    // Idempotência: já está pronto, não fazer nada
    if (currentState is CaregiverContextReady) {
      // ignore: avoid_print
      print('[CaregiverContext] Already ready, skipping');
      return;
    }
    
    // Idempotência: já está a carregar, não duplicar
    if (currentState is CaregiverContextLoading) {
      // ignore: avoid_print
      print('[CaregiverContext] Already loading, skipping');
      return;
    }

    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);

    if (user == null) {
      state = const CaregiverContextError('Utilizador não autenticado');
      return;
    }

    if (activeBaby == null) {
      state = const CaregiverContextError('Nenhum bebé selecionado');
      return;
    }

    state = const CaregiverContextLoading();
    // ignore: avoid_print
    print('[CaregiverContext] Ensuring context for baby=${activeBaby.id}, user=${user.id}');

    // Step 1: Verificar localmente primeiro
    final localResult = await _localDataSource.getCaregiverByUserIdForBaby(
      userId: user.id,
      babyId: activeBaby.id,
    );

    switch (localResult) {
      case Success(:final data):
        if (data != null) {
          // Caregiver existe localmente - sucesso!
          state = CaregiverContextReady(data.toDomain());
          _verifiedBabies[activeBaby.id] = true;
          // ignore: avoid_print
          print('[CaregiverContext] Found local caregiver: ${data.id}');
          return;
        }
      case Error(:final failure):
        // Erro ao ler local - tentar continuar com pull
        // ignore: avoid_print
        print('[CaregiverContext] Error checking local: ${failure.message}');
    }

    // Step 2: Não existe localmente - tentar pull do remoto
    // ignore: avoid_print
    print('[CaregiverContext] No local caregiver, attempting remote pull');

    final remoteResult = await _remoteDataSource.getCaregiversForBaby(activeBaby.id);

    switch (remoteResult) {
      case Success(:final data):
        if (data.isEmpty) {
          // Remoto retornou vazio - utilizador não é caregiver deste baby
          state = const CaregiverContextError(
            'Não tens permissão para este bebé. '
            'Pede ao owner para te convidar.',
          );
          return;
        }

        // Encontrar o caregiver do utilizador atual
        final userCaregiver = data.where((c) => c.userId == user.id).toList();
        
        if (userCaregiver.isEmpty) {
          state = const CaregiverContextError(
            'Não tens permissão para este bebé. '
            'Pede ao owner para te convidar.',
          );
          return;
        }

        // Upsert caregivers no SQLite
        for (final caregiver in data) {
          await _localDataSource.saveCaregiver(caregiver);
        }
        
        // ignore: avoid_print
        print('[CaregiverContext] Pulled ${data.length} caregivers, saved to local');

        // Sucesso!
        state = CaregiverContextReady(userCaregiver.first.toDomain());
        _verifiedBabies[activeBaby.id] = true;
        
        // Invalidar provider de caregivers para refresh
        ref.invalidate(caregiversNotifierProvider);

      case Error(:final failure):
        // Erro de rede ou outro - provavelmente offline
        final message = failure.message.toLowerCase();
        if (message.contains('network') || 
            message.contains('connection') ||
            message.contains('socket') ||
            message.contains('timeout')) {
          state = const CaregiverContextOfflineNoCaregiver(
            'Precisas de estar online 1x para ativar este bebé. '
            'Liga à internet e tenta novamente.',
          );
        } else {
          state = CaregiverContextError(
            'Erro ao verificar permissões: ${failure.message}',
          );
        }
        // ignore: avoid_print
        print('[CaregiverContext] Remote pull failed: ${failure.message}');
    }
  }

  /// Verificar localmente (usado para refresh rápido)
  Future<void> _checkLocalCaregiver(String babyId) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final result = await _localDataSource.getCaregiverByUserIdForBaby(
      userId: user.id,
      babyId: babyId,
    );

    switch (result) {
      case Success(:final data):
        if (data != null) {
          state = CaregiverContextReady(data.toDomain());
        }
      case Error():
        // Ignorar erros no check local
        break;
    }
  }

  /// Força re-verificação (útil após sync)
  Future<void> refresh() async {
    final activeBaby = ref.read(activeBabyProvider);
    if (activeBaby != null) {
      _verifiedBabies.remove(activeBaby.id);
    }
    state = const CaregiverContextInitial();
    await ensureContext();
  }

  /// Limpar cache (ex: ao mudar de baby)
  void clearCache() {
    _verifiedBabies.clear();
    state = const CaregiverContextInitial();
  }
}
