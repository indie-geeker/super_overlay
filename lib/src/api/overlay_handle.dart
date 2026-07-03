import 'dart:async';

import 'package:flutter/widgets.dart';

/// A stable handle returned from command-style overlay APIs.
class OverlayHandle<T> {
  /// Creates a handle backed by explicit lifecycle futures and callbacks.
  OverlayHandle({
    required Future<void> visible,
    required Future<T?> closed,
    required Future<void> Function([T? result]) close,
    required VoidCallback refresh,
    required bool Function() isVisible,
  }) : _visible = visible,
       _closed = closed,
       _close = close,
       _refresh = refresh,
       _isVisible = isVisible;

  /// Creates a handle that is already closed and not attached to an overlay.
  factory OverlayHandle.detached() {
    return OverlayHandle<T>(
      visible: Future<void>.value(),
      closed: Future<T?>.value(),
      close: ([T? result]) => Future<void>.value(),
      refresh: () {},
      isVisible: () => false,
    );
  }

  final Future<void> _visible;
  final Future<T?> _closed;
  final Future<void> Function([T? result]) _close;
  final VoidCallback _refresh;
  final bool Function() _isVisible;
  Future<void>? _closeFuture;

  /// Completes when the overlay has become visible.
  Future<void> get visible => _visible;

  /// Completes once, when the overlay has closed.
  Future<T?> get closed => _closed;

  /// Whether the overlay is currently visible according to its runtime owner.
  bool get isVisible => _isVisible();

  /// Requests the overlay to close with an optional result.
  Future<void> close([T? result]) {
    return _closeFuture ??= _close(result);
  }

  /// Requests the overlay content to rebuild.
  void refresh() {
    _refresh();
  }
}
