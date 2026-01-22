/// Reference to a source (AAP, CDC, NHS, etc.)
///
/// Loaded from sources.json asset.
class SourceRef {
  final String id;
  final String name;
  final String publisher;
  final String? url;

  const SourceRef({
    required this.id,
    required this.name,
    required this.publisher,
    this.url,
  });

  factory SourceRef.fromJson(Map<String, dynamic> json) {
    return SourceRef(
      id: json['id'] as String,
      name: json['name'] as String,
      publisher: json['publisher'] as String,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'publisher': publisher,
    if (url != null) 'url': url,
  };

  @override
  String toString() => 'SourceRef($id: $name)';
}
