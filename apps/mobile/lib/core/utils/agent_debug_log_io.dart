import 'dart:convert';
import 'dart:io';

/// Sends a tiny JSON payload to the local NDJSON ingest server (best-effort).
///
/// IMPORTANT: This is debug-only plumbing. Errors are swallowed on purpose.
Future<void> agentDebugLog({
  required String sessionId,
  required String runId,
  required String hypothesisId,
  required String location,
  required String message,
  required Map<String, Object?> data,
}) async {
  // #region agent log
  try {
    final uri = Uri.parse(
      'http://127.0.0.1:7242/ingest/402e49f3-28ad-4dea-bc1e-1a9f87eb4f6c',
    );

    final payload = <String, Object?>{
      'sessionId': sessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final client = HttpClient();
    final req = await client.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(payload));
    await req.close();
    client.close(force: true);
  } catch (_) {
    // ignore
  }
  // #endregion
}

