// No-op stub (used on platforms without dart:io, e.g. web).

Future<void> agentDebugLog({
  required String sessionId,
  required String runId,
  required String hypothesisId,
  required String location,
  required String message,
  required Map<String, Object?> data,
}) async {
  // Intentionally empty.
}

