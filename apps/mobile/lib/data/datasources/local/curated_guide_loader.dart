import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show rootBundle;
import 'package:temp_flutter/domain/content/guide_section.dart';

/// Loader for curated guide content from assets
///
/// Guide content is stored as:
/// - guide_index.json (metadata: order, titleKey, sources)
/// - {locale}/{sectionId}.md (markdown content)
///
/// Supports locale fallback: pt_PT → pt → en_US → en
class CuratedGuideLoader {
  static const _basePath = 'assets/curated/guide/v1';
  static const _indexPath = '$_basePath/guide_index.json';

  static List<GuideSectionMeta>? _indexCache;
  static final Map<String, String> _contentCache = {};

  const CuratedGuideLoader._();

  /// Loads the guide index (section metadata)
  static Future<List<GuideSectionMeta>> loadIndex() async {
    if (_indexCache != null) return _indexCache!;

    final jsonString = await rootBundle.loadString(_indexPath);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final sectionsList = json['sections'] as List<dynamic>;

    _indexCache = sectionsList
        .map((s) => GuideSectionMeta.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return _indexCache!;
  }

  /// Loads markdown content for a section with locale fallback
  ///
  /// Fallback order: pt_PT → pt → en_US → en
  static Future<String> loadContent(String sectionId, Locale locale) async {
    final cacheKey = '${locale.toLanguageTag()}_$sectionId';
    if (_contentCache.containsKey(cacheKey)) {
      return _contentCache[cacheKey]!;
    }

    // Try locales in fallback order
    final localesToTry = _buildLocaleFallback(locale);

    for (final loc in localesToTry) {
      final path = '$_basePath/$loc/$sectionId.md';
      try {
        final content = await rootBundle.loadString(path);
        _contentCache[cacheKey] = content;
        return content;
      } catch (_) {
        // Asset not found, try next locale
        continue;
      }
    }

    // Fallback: return placeholder
    return '# Content not available\n\nThis section is not yet available in your language.';
  }

  /// Loads a complete guide section (meta + content)
  static Future<GuideSection> loadSection(
    String sectionId,
    Locale locale,
  ) async {
    final index = await loadIndex();
    final meta = index.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => throw ArgumentError('Section not found: $sectionId'),
    );
    final content = await loadContent(sectionId, locale);
    return GuideSection(meta: meta, content: content);
  }

  /// Builds locale fallback list
  static List<String> _buildLocaleFallback(Locale locale) {
    final result = <String>[];

    // Full locale (e.g., pt_PT)
    if (locale.countryCode != null) {
      result.add('${locale.languageCode}_${locale.countryCode}');
    }

    // Language only (e.g., pt)
    // Note: Our assets use pt_PT and en_US format
    if (locale.languageCode == 'pt') {
      result.add('pt_PT');
    } else if (locale.languageCode == 'en') {
      result.add('en_US');
    }

    // Default fallback
    if (!result.contains('en_US')) {
      result.add('en_US');
    }

    return result;
  }

  /// Clears all caches (for testing)
  static void clearCache() {
    _indexCache = null;
    _contentCache.clear();
  }
}
