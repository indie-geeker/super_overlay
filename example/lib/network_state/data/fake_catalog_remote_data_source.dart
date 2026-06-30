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
          title: '山地徒步背包',
          subtitle: '局部图片加载成功，页面保持可操作。',
          imageLabel: '远程图片 A',
        ),
        CatalogItemDto(
          id: 'rain-shell',
          title: '轻量防雨外套',
          subtitle: '模拟图片加载失败，只影响当前卡片。',
          imageLabel: '远程图片 B',
          imageShouldFail: true,
        ),
        CatalogItemDto(
          id: 'camp-lamp',
          title: '营地照明灯',
          subtitle: '列表内容已经返回，图片状态独立处理。',
          imageLabel: '远程图片 C',
        ),
      ],
      CatalogRequestMode.empty => const [],
      CatalogRequestMode.failure => throw const CatalogLoadFailure(
        '远程服务暂时不可用，请稍后重试。',
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
