import 'package:temp_flutter/domain/entities/sleep_event.dart';

/// Pure normalizer for sleep events (v1)
/// 
/// Resolves multi-device conflicts deterministically and idempotently.
/// This is a pure function: no I/O, no side effects, fully testable.
/// 
/// POLICY v1 (conservative):
/// - Only resolves Start-Start conflicts (SleepStart while another is already open)
/// - Does NOT touch orphan SleepEnd (may be waiting for SleepStart to arrive via pagination)
/// - Winner is deterministic: highest (timestamp, created_at, id) wins
/// - Loser gets: is_corrected=true, corrected_by=winner.id, metadata with audit info
/// 
/// IDEMPOTENCY:
/// - Running twice on the same dataset produces the same output
/// - Second run produces empty plan (all corrections already applied)
class SleepEventsNormalizer {
  static const String policyVersion = 'v1';
  static const String correctionReason = 'duplicate_multi_device';

  /// Normalizes a list of sleep events and returns a plan of updates
  /// 
  /// [events] - All sleep events for a baby (including corrected ones for reference)
  /// 
  /// Returns [NormalizationPlan] with updates to apply
  /// The caller is responsible for applying the plan to the database
  static NormalizationPlan normalize(List<SleepEvent> events) {
    final logs = <String>[];
    final updates = <EventUpdate>[];

    void log(String msg) {
      logs.add('[Normalizer] $msg');
    }

    // Filter to only valid (non-corrected) events
    final validEvents = events.where((e) => e.isValid).toList();
    
    log('Total events: ${events.length}, valid: ${validEvents.length}');

    if (validEvents.isEmpty) {
      log('No valid events to normalize');
      return NormalizationPlan(updates: updates, logs: logs);
    }

    // Sort by canonical order: timestamp ASC, created_at ASC, id ASC
    validEvents.sort((a, b) {
      final ts = a.timestamp.compareTo(b.timestamp);
      if (ts != 0) return ts;
      final ca = a.createdAt.compareTo(b.createdAt);
      if (ca != 0) return ca;
      return a.id.compareTo(b.id);
    });

    log('Events sorted by (timestamp, created_at, id) ASC');

    // Track open SleepStart
    SleepEvent? openStart;
    int conflictsDetected = 0;
    int orphanEndsDetected = 0;

    for (final event in validEvents) {
      if (event.type == SleepEventType.sleepStart) {
        if (openStart == null) {
          // Normal case: first start, mark as open
          openStart = event;
        } else {
          // CONFLICT: Start while another Start is open
          conflictsDetected++;
          
          // Determine winner: highest (timestamp, created_at, id)
          final winner = _pickWinner(openStart, event);
          final loser = winner.id == openStart.id ? event : openStart;
          
          log('Conflict #$conflictsDetected: Start-while-open');
          log('  Loser: ${_shortId(loser.id)} ts=${loser.timestamp}');
          log('  Winner: ${_shortId(winner.id)} ts=${winner.timestamp}');

          // Create update for loser
          updates.add(EventUpdate(
            eventId: loser.id,
            setCorrectedBy: winner.id,
            metadataPatch: {
              'correction_reason': correctionReason,
              'winner_event_id': winner.id,
              'policy_version': policyVersion,
              'normalized_at': DateTime.now().toUtc().toIso8601String(),
            },
          ));

          // Winner becomes the new open start
          openStart = winner;
        }
      } else if (event.type == SleepEventType.sleepEnd) {
        if (openStart != null) {
          // Normal case: End closes the open Start
          openStart = null;
        } else {
          // ORPHAN END: SleepEnd without preceding SleepStart
          // v1 policy: DO NOT auto-correct (may be waiting for Start to arrive)
          orphanEndsDetected++;
          log('Orphan End detected (ignored): ${_shortId(event.id)} ts=${event.timestamp}');
        }
      }
    }

    log('Normalization complete:');
    log('  Conflicts detected: $conflictsDetected');
    log('  Orphan Ends detected (ignored): $orphanEndsDetected');
    log('  Updates planned: ${updates.length}');

    return NormalizationPlan(updates: updates, logs: logs);
  }

  /// Helper to get short ID for logging (handles short IDs safely)
  static String _shortId(String id) {
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  /// Picks the winner between two conflicting SleepStart events
  /// 
  /// Winner rule: highest (timestamp, created_at, id) wins
  /// This is deterministic and all devices will agree on the same winner
  static SleepEvent _pickWinner(SleepEvent a, SleepEvent b) {
    // Compare timestamp first (later wins)
    final ts = a.timestamp.compareTo(b.timestamp);
    if (ts != 0) return ts > 0 ? a : b;

    // Tie-break by created_at (later wins)
    final ca = a.createdAt.compareTo(b.createdAt);
    if (ca != 0) return ca > 0 ? a : b;

    // Final tie-break by id (lexicographically higher wins)
    return a.id.compareTo(b.id) > 0 ? a : b;
  }
}

/// Plan of updates to apply after normalization
/// 
/// This is a pure data structure with no side effects.
/// The application layer is responsible for applying these updates.
class NormalizationPlan {
  /// List of updates to apply
  final List<EventUpdate> updates;
  
  /// Debug logs explaining what was detected and planned
  final List<String> logs;

  const NormalizationPlan({
    required this.updates,
    required this.logs,
  });

  /// Check if plan is empty (no updates needed)
  bool get isEmpty => updates.isEmpty;

  /// Check if plan has updates
  bool get hasUpdates => updates.isNotEmpty;

  @override
  String toString() => 'NormalizationPlan(updates: ${updates.length}, logs: ${logs.length})';
}

/// Single update to apply to an event
/// 
/// Represents the UPDATE statement:
/// UPDATE sleep_events 
/// SET is_corrected=true, corrected_by=?, metadata=MERGE(metadata, ?)
/// WHERE id=?
class EventUpdate {
  /// ID of the event to update
  final String eventId;
  
  /// Value to set for corrected_by (winner event ID)
  final String setCorrectedBy;
  
  /// Metadata patch to merge with existing metadata
  final Map<String, dynamic> metadataPatch;

  const EventUpdate({
    required this.eventId,
    required this.setCorrectedBy,
    required this.metadataPatch,
  });

  @override
  String toString() => 'EventUpdate(eventId: ${eventId.substring(0, 8)}, '
      'correctedBy: ${setCorrectedBy.substring(0, 8)})';
}
