class LinkPreview {
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
  });

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;

  bool get hasContent => title != null || description != null;
}
