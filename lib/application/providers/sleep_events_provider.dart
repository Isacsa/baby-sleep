import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/sleep_event.dart';
import '../../domain/repositories/sleep_event_repository.dart';
import 'active_baby_provider.dart';

part 'sleep_events_provider.g.dart';

/// Sleep events provider
/// 
/// Provides timeline of sleep events for active baby
/// Events are ordered by timestamp DESC, createdAt DESC
/// Updates when event is created locally or after sync
@riverpod
Future<List<SleepEvent>> sleepEvents(SleepEventsRef ref) async {
  final activeBaby = ref.watch(activeBabyProvider);
  
  if (activeBaby == null) {
    return [];
  }

  // TODO: Inject SleepEventRepository
  // final repository = ref.watch(sleepEventRepositoryProvider);
  // return await repository.getSleepEventsTimeline(
  //   babyId: activeBaby.id,
  //   includeCorrected: false,
  // );
  
  // Placeholder
  return [];
}

