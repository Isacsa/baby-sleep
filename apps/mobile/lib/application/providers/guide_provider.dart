import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/data/datasources/local/curated_guide_loader.dart';
import 'package:temp_flutter/data/datasources/local/curated_sources_loader.dart';
import 'package:temp_flutter/domain/content/guide_section.dart';
import 'package:temp_flutter/domain/content/source_ref.dart';

/// Provider for guide section index (metadata only)
///
/// Returns list of [GuideSectionMeta] sorted by order.
/// Cached after first load.
final guideIndexProvider = FutureProvider<List<GuideSectionMeta>>((ref) async {
  return CuratedGuideLoader.loadIndex();
});

/// Provider for a specific guide section with content
///
/// Parameters: (sectionId, locale)
/// Returns [GuideSection] with metadata and markdown content.
final guideSectionProvider =
    FutureProvider.family<GuideSection, (String, Locale)>((ref, params) async {
  final (sectionId, locale) = params;
  return CuratedGuideLoader.loadSection(sectionId, locale);
});

/// Provider for sources by IDs
///
/// Returns list of [SourceRef] for the given IDs.
final sourcesByIdsProvider =
    FutureProvider.family<List<SourceRef>, List<String>>((ref, ids) async {
  return CuratedSourcesLoader.getByIds(ids);
});

/// Provider for all sources
final allSourcesProvider = FutureProvider<Map<String, SourceRef>>((ref) async {
  return CuratedSourcesLoader.load();
});
