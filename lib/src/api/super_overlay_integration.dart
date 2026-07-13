part of '../super_overlay_core.dart';

/// Owns the stable objects used to install SuperOverlay in one app root.
///
/// Create this object outside `build`, then reuse [builder] and [observer] for
/// the lifetime of that root. Call [navigatorObserver] for each additional
/// nested Navigator that should participate in SuperOverlay route tracking.
/// Attach each observer to exactly one Navigator. When a nested Navigator is
/// removed dynamically, dispose its scoped observer as part of that lifecycle.
class SuperOverlayIntegration {
  /// Creates an independently owned SuperOverlay root integration.
  SuperOverlayIntegration({
    TransitionBuilder? builder,
    SuperOverlayStyleBuilder? styleBuilder,
    SuperOverlayToastBuilder? toastBuilder,
    SuperOverlayLoadingBuilder? loadingBuilder,
    NotifyStyle? notifyStyle,
  }) : _ownerIdentity = Object() {
    _rootObserver = SuperOverlayNavigatorObserver._root(_ownerIdentity);
    final hostBuilder = SuperOverlayInit.init(
      ownerIdentity: _ownerIdentity,
      builder: builder,
      styleBuilder: styleBuilder,
      toastBuilder: toastBuilder,
      loadingBuilder: loadingBuilder,
      notifyStyle: notifyStyle,
    );
    _builder = (context, child) {
      _ensureNotDisposed();
      return hostBuilder(context, child);
    };
  }

  final Object _ownerIdentity;
  late final SuperOverlayNavigatorObserver _rootObserver;
  final Set<SuperOverlayNavigatorObserver> _scopedObservers = {};
  late final TransitionBuilder _builder;
  bool _disposed = false;

  /// The stable builder installed in `MaterialApp.builder`.
  TransitionBuilder get builder {
    _ensureNotDisposed();
    return _builder;
  }

  /// The stable observer installed on this integration's root Navigator.
  ///
  /// Store this observer outside `build` and attach it to exactly one
  /// Navigator. Its lifetime is managed by this integration.
  SuperOverlayNavigatorObserver get observer {
    _ensureNotDisposed();
    return _rootObserver;
  }

  /// Creates an observer owned by this integration for one nested Navigator.
  ///
  /// Store the returned observer outside `build`, attach it to exactly one
  /// Navigator, and call its `dispose` method when that Navigator is removed.
  SuperOverlayNavigatorObserver navigatorObserver() {
    _ensureNotDisposed();

    late final SuperOverlayNavigatorObserver observer;
    observer = SuperOverlayNavigatorObserver._scoped(
      _ownerIdentity,
      onDispose: () => _scopedObservers.remove(observer),
    );
    _scopedObservers.add(observer);
    return observer;
  }

  TransitionBuilder _legacyBuilder({
    TransitionBuilder? builder,
    SuperOverlayStyleBuilder? styleBuilder,
    SuperOverlayToastBuilder? toastBuilder,
    SuperOverlayLoadingBuilder? loadingBuilder,
    NotifyStyle? notifyStyle,
  }) {
    return SuperOverlayInit.init(
      ownerIdentity: _ownerIdentity,
      builder: builder,
      styleBuilder: styleBuilder,
      toastBuilder: toastBuilder,
      loadingBuilder: loadingBuilder,
      notifyStyle: notifyStyle,
    );
  }

  /// Disposes the root and scoped Navigator observers owned by this object.
  ///
  /// This method is idempotent. The installed host remains owned by the widget
  /// lifecycle and is released when its builder subtree unmounts.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;

    _rootObserver._disposeOwned(_ownerIdentity);
    for (final observer in _scopedObservers.toList(growable: false)) {
      observer._disposeOwned(_ownerIdentity);
    }
    _scopedObservers.clear();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('This SuperOverlayIntegration has been disposed.');
    }
  }
}

/// A Navigator observer owned by a [SuperOverlayIntegration].
///
/// Scoped observers can be disposed directly after their Navigator is
/// removed. Root observers are released only by disposing their integration.
class SuperOverlayNavigatorObserver extends SuperOverlayObserver {
  SuperOverlayNavigatorObserver._root(this._ownerIdentity)
    : _allowPublicDispose = false,
      super(ownerIdentity: _ownerIdentity);

  SuperOverlayNavigatorObserver._scoped(this._ownerIdentity, {super.onDispose})
    : _allowPublicDispose = true,
      super(ownerIdentity: _ownerIdentity);

  final Object _ownerIdentity;
  final bool _allowPublicDispose;

  /// Releases this observer after its nested Navigator is removed.
  ///
  /// Root observers are owned by their [SuperOverlayIntegration] and reject
  /// direct disposal. Dispose the integration to release a root observer.
  @override
  void dispose() {
    if (!_allowPublicDispose) {
      throw StateError(
        'A root observer cannot be disposed directly. '
        'Dispose its SuperOverlayIntegration instead.',
      );
    }
    super.dispose();
  }

  void _disposeOwned(Object ownerIdentity) {
    if (!identical(_ownerIdentity, ownerIdentity)) {
      throw StateError('This observer belongs to another integration.');
    }
    super.dispose();
  }
}
