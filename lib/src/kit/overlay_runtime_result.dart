class OverlayRuntimeResult<T> {
  OverlayRuntimeResult({
    Future<void>? visible,
    required Future<T?> closed,
    this.identityTag,
    this.refresh,
  }) : _closed = closed,
       visible = visible ?? Future<void>.value();

  OverlayRuntimeResult.lazyClosed({
    Future<void>? visible,
    required Future<T?> Function() closed,
    this.identityTag,
    this.refresh,
  }) : _readClosed = closed,
       visible = visible ?? Future<void>.value();

  final Future<void> visible;
  Future<T?>? _closed;
  Future<T?> Function()? _readClosed;
  Future<T?> get closed => readClosed();

  Future<T?> readClosed() {
    final read = _readClosed;
    if (read != null) {
      _closed = read();
      _readClosed = null;
    }
    return _closed!;
  }

  final String? identityTag;
  final void Function()? refresh;
}
