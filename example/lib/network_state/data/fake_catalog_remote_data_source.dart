import '../domain/catalog_item.dart';
import '../domain/load_catalog_items.dart';

class FakeCatalogRemoteDataSource {
  const FakeCatalogRemoteDataSource();

  Future<List<CatalogItemDto>> fetchItems(CatalogRequestMode mode) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return switch (mode) {
      CatalogRequestMode.success => const [
        CatalogItemDto(
          id: 'trail-pack',
          title: 'Mountain Hiking Backpack',
          subtitle:
              'The card image loads successfully while the page remains interactive.',
          imageLabel: 'Remote Image A',
        ),
        CatalogItemDto(
          id: 'rain-shell',
          title: 'Lightweight Rain Shell',
          subtitle: 'A simulated image failure affects only this card.',
          imageLabel: 'Remote Image B',
          imageShouldFail: true,
        ),
        CatalogItemDto(
          id: 'camp-lamp',
          title: 'Camp Lantern',
          subtitle:
              'List content is ready while each image manages its own state.',
          imageLabel: 'Remote Image C',
        ),
      ],
      CatalogRequestMode.empty => const [],
      CatalogRequestMode.failure =>
        throw const CatalogLoadFailure(
          'The remote service is temporarily unavailable. Try again later.',
        ),
    };
  }
}

class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl(this._remote);

  final FakeCatalogRemoteDataSource _remote;

  @override
  Future<List<CatalogItem>> loadItems(CatalogRequestMode mode) async {
    final items = await _remote.fetchItems(mode);
    return items.map((item) => item.toEntity()).toList(growable: false);
  }
}

class CatalogItemDto {
  const CatalogItemDto({
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

  CatalogItem toEntity() {
    return CatalogItem(
      id: id,
      title: title,
      subtitle: subtitle,
      imageLabel: imageLabel,
      imageShouldFail: imageShouldFail,
    );
  }
}
