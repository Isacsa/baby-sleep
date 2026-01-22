/// Guide section metadata (from guide_index.json)
///
/// Contains metadata about a guide section, not the content itself.
/// Content is loaded separately from Markdown files.
class GuideSectionMeta {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final String icon;
  final int order;
  final bool hasAgeVariants;
  final List<String> sourceIds;

  const GuideSectionMeta({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.order,
    required this.hasAgeVariants,
    required this.sourceIds,
  });

  factory GuideSectionMeta.fromJson(Map<String, dynamic> json) {
    return GuideSectionMeta(
      id: json['id'] as String,
      titleKey: json['titleKey'] as String,
      subtitleKey: json['subtitleKey'] as String,
      icon: json['icon'] as String,
      order: json['order'] as int,
      hasAgeVariants: json['hasAgeVariants'] as bool? ?? false,
      sourceIds: (json['sources'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }

  @override
  String toString() => 'GuideSectionMeta($id)';
}

/// Loaded guide section with content
class GuideSection {
  final GuideSectionMeta meta;
  final String content;

  const GuideSection({
    required this.meta,
    required this.content,
  });
}
