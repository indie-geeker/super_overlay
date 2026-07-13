import 'dart:async';

import 'package:flutter/widgets.dart';

typedef OverlayBackRequest = Future<bool> Function(int generation);

/// A generation-bound pop gate registered directly with a [ModalRoute].
class OverlayPopEntry implements PopEntry<Object?> {
  OverlayPopEntry({
    required this.generation,
    required OverlayBackRequest onBackRequested,
  }) : _onBackRequested = onBackRequested;

  final int generation;
  final OverlayBackRequest _onBackRequested;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier<bool>(true);

  bool _backAttemptInProgress = false;
  bool _disposed = false;

  void updateCanPop(bool canPop) {
    if (_disposed || canPopNotifier.value == canPop) {
      return;
    }
    canPopNotifier.value = canPop;
  }

  @override
  void onPopInvoked(bool didPop) {
    onPopInvokedWithResult(didPop, null);
  }

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    // ModalRoute broadcasts failed pops to every registered PopEntry. A
    // PopScope or Form may be the entry that blocked the route, so only the
    // SuperOverlay entry that currently owns the veto may handle this event.
    if (_disposed || didPop || canPopNotifier.value) {
      return;
    }
    if (_backAttemptInProgress) {
      return;
    }
    _backAttemptInProgress = true;
    unawaited(_requestBack());
  }

  Future<void> _requestBack() async {
    try {
      await _onBackRequested(generation);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'super_overlay',
          context: ErrorDescription('while handling a route back request'),
        ),
      );
    } finally {
      _backAttemptInProgress = false;
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    canPopNotifier.dispose();
  }
}
