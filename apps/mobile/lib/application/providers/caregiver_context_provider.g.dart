// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caregiver_context_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$caregiverContextHash() => r'1fcbaa9f25a2afdc4183bd72cb40fe3a3df546b0';

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
///
/// Copied from [CaregiverContext].
@ProviderFor(CaregiverContext)
final caregiverContextProvider =
    AutoDisposeNotifierProvider<
      CaregiverContext,
      CaregiverContextState
    >.internal(
      CaregiverContext.new,
      name: r'caregiverContextProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$caregiverContextHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CaregiverContext = AutoDisposeNotifier<CaregiverContextState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
