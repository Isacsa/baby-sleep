import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:temp_flutter/domain/content/source_ref.dart';

/// Loader for curated sources from sources.json asset
///
/// Sources are used to reference AAP, CDC, NHS, AASM guidelines.
/// Loaded once and cached in memory.
class CuratedSourcesLoader {
  static const _assetPath = 'assets/curated/sources/v1/sources.json';

  static Map<String, SourceRef>? _cache;

  const CuratedSourcesLoader._();

  /// Loads and caches all sources as a map by ID
  static Future<Map<String, SourceRef>> load() async {
    if (_cache != null) return _cache!;

    final jsonString = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final sourcesList = json['sources'] as List<dynamic>;

    _cache = {
      for (final s in sourcesList)
        (s as Map<String, dynamic>)['id'] as String:
            SourceRef.fromJson(s),
    };

    return _cache!;
  }

  /// Gets a specific source by ID (returns null if not found)
  static Future<SourceRef?> getById(String id) async {
    final sources = await load();
    return sources[id];
  }

  /// Gets multiple sources by their IDs
  static Future<List<SourceRef>> getByIds(List<String> ids) async {
    final sources = await load();
    return ids
        .map((id) => sources[id])
        .whereType<SourceRef>()
        .toList();
  }

  /// Clears the cache (for testing)
  static void clearCache() {
    _cache = null;
  }
}
