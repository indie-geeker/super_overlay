class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageLabel,
    this.imageShouldFail = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageLabel;
  final bool imageShouldFail;
}
