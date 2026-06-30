import 'catalog_item.dart';

enum CatalogRequestMode { success, empty, failure }

abstract class CatalogRepository {
  Future<List<CatalogItem>> loadItems(CatalogRequestMode mode);
}

class CatalogLoadFailure implements Exception {
  const CatalogLoadFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class LoadCatalogItems {
  const LoadCatalogItems(this._repository);

  final CatalogRepository _repository;

  Future<List<CatalogItem>> call(CatalogRequestMode mode) {
    return _repository.loadItems(mode);
  }
}
