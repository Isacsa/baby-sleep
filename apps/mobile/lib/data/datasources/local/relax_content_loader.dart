import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:temp_flutter/domain/relax/relax.dart';

/// Loads localized relax content (guides, checklist, night mode bullets).
class RelaxContentLoader {
  static const _basePath = 'assets/curated/relax/v1';
  
  final Map<String, RelaxContent> _cache = {};

  /// Load content for the given locale with fallback.
  Future<RelaxContent> loadContent(Locale locale) async {
    final localeKey = _resolveLocaleKey(locale);
    
    if (_cache.containsKey(localeKey)) {
      return _cache[localeKey]!;
    }

    try {
      final jsonStr = await rootBundle.loadString('$_basePath/$localeKey/guides.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final content = RelaxContent.fromJson(json);
      _cache[localeKey] = content;
      return content;
    } catch (e) {
      // Fallback to pt_PT
      if (localeKey != 'pt_PT') {
        return loadContent(const Locale('pt', 'PT'));
      }
      rethrow;
    }
  }

  String _resolveLocaleKey(Locale locale) {
    // Portuguese variants
    if (locale.languageCode == 'pt') {
      return 'pt_PT';
    }
    // English
    if (locale.languageCode == 'en') {
      return 'en_US';
    }
    // Default to Portuguese
    return 'pt_PT';
  }

  /// Clear the cache (for testing or memory pressure).
  void clearCache() {
    _cache.clear();
  }
}
