class OverlayRuntimeResult<T> {
  OverlayRuntimeResult({
    Future<void>? visible,
    required this.closed,
    this.identityTag,
    this.refresh,
  }) : visible = visible ?? Future<void>.value();

  final Future<void> visible;
  final Future<T?> closed;
  final String? identityTag;
  final void Function()? refresh;
}
