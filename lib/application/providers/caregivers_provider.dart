import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/caregiver.dart';
import '../../domain/use_cases/caregiver/get_caregivers_for_baby.dart';
import 'active_baby_provider.dart';

part 'caregivers_provider.g.dart';

/// Caregivers provider
/// 
/// Provides list of caregivers for active baby
/// Updates when active baby changes or after sync
@riverpod
Future<List<Caregiver>> caregivers(CaregiversRef ref) async {
  final activeBaby = ref.watch(activeBabyProvider);
  
  if (activeBaby == null) {
    return [];
  }

  // TODO: Inject GetCaregiversForBaby use case
  // final useCase = ref.watch(getCaregiversForBabyProvider);
  // return await useCase.execute(activeBaby.id);
  
  // Placeholder
  return [];
}

