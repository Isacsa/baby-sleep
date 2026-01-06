import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/baby.dart';
import '../../domain/use_cases/baby/get_accessible_babies.dart';

part 'babies_provider.g.dart';

/// Babies provider
/// 
/// Provides list of accessible babies for current user
/// Updates when sync completes or baby is created
@riverpod
Future<List<Baby>> babies(BabiesRef ref) async {
  // TODO: Inject GetAccessibleBabies use case
  // final useCase = ref.watch(getAccessibleBabiesProvider);
  // return await useCase.execute();
  
  // Placeholder
  return [];
}

