import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/baby.dart';

part 'active_baby_provider.g.dart';

/// Active baby provider
/// 
/// Manages currently selected baby
/// Other providers depend on this to filter data
@riverpod
class ActiveBaby extends _$ActiveBaby {
  @override
  Baby? build() {
    // TODO: Load from local preferences
    return null;
  }

  /// Sets active baby
  void setBaby(Baby? baby) {
    state = baby;
    // TODO: Save to local preferences
  }

  /// Clears active baby
  void clearBaby() {
    state = null;
  }
}

