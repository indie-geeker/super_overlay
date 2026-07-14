import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../custom/custom_loading.dart';
import '../custom/custom_notify.dart';
import '../custom/custom_overlay.dart';
import '../custom/toast_tool.dart';
import '../data/show_param.dart';
import '../data/notify_style.dart';
import '../kit/debounce_utils.dart';
import '../kit/overlay_controller.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/typedef.dart';
import '../kit/view_utils.dart';
import 'navigator_scope_registry.dart';
import 'overlay_route_owner.dart';

part 'overlay_manager_dismiss.dart';
part 'overlay_manager_lifecycle.dart';
part 'overlay_manager_lookup.dart';
part 'overlay_manager_models.dart';

enum OverlayCloseType { normal, mask, route, back }

class OverlayManager {
  OverlayManager._();

  static final OverlayManager instance = OverlayManager._();

  final Queue<_OverlayRecord> _dialogQueue = ListQueue<_OverlayRecord>();
  final Queue<_NotifyRecord> _notifyQueue = ListQueue<_NotifyRecord>();
  final Set<_OverlayRecord> _inFlightDialogRecords = <_OverlayRecord>{};
  final Set<_NotifyRecord> _inFlightNotifyRecords = <_NotifyRecord>{};
  final Set<int> _backAttemptsInProgress = <int>{};
  final Set<Object> _scheduledIdleScopePrunes = HashSet<Object>.identity();

  final Map<int, _OverlayHostState> _hosts = <int, _OverlayHostState>{};
  final List<_OverlayHostState> _candidates = <_OverlayHostState>[];
  _OverlayHostState? _activeHost;
  _OverlayHostTopology _topology = _OverlayHostTopology.empty;
  var _nextGeneration = 1;
  var _nextTagId = 0;

  SuperOverlayEntry get entryLoading => _commandHost.entryLoading;
  CustomLoading get loadingOverlay => _commandHost.loadingOverlay;
  BuildContext? get contextCustom => _activeHost?.contextCustom;
  BuildContext? get contextAttach => _activeHost?.contextAttach;
  BuildContext? get contextNotify => _activeHost?.contextNotify;
  BuildContext? get contextToast => _activeHost?.contextToast;

  int acquireHost({
    required Object ownerIdentity,
    required SuperOverlayToastBuilder? toastBuilder,
    required SuperOverlayLoadingBuilder? loadingBuilder,
    required NotifyStyle? notifyStyle,
  }) {
    final generation = _nextGeneration++;
    final host = _OverlayHostState(
      generation: generation,
      ownerIdentity: ownerIdentity,
      defaults: _OverlayHostDefaults(
        toastBuilder: toastBuilder,
        loadingBuilder: loadingBuilder,
        notifyStyle: notifyStyle,
      ),
      onBackDispositionChanged:
          () => _syncBackDispositionForGeneration(generation),
    );
    _hosts[host.generation] = host;
    NavigatorScopeRegistry.instance.attachHost(
      ownerIdentity: ownerIdentity,
      generation: host.generation,
    );

    if (_activeHost == null && _candidates.isEmpty) {
      _activeHost = host;
      _topology = _OverlayHostTopology.active;
      _syncBackDispositionForGeneration(host.generation);
      return host.generation;
    }

    _candidates.add(host);
    _topology = _OverlayHostTopology.pending;
    _scheduleHostReconciliation();
    return host.generation;
  }

  SuperOverlayEntry entryForHost(int generation) {
    return _hostFor(generation).entryLoading;
  }

  void captureHostContexts(int generation, BuildContext context) {
    _hostFor(generation).captureContexts(context);
  }

  void updateHostDefaults({
    required int generation,
    required SuperOverlayToastBuilder? toastBuilder,
    required SuperOverlayLoadingBuilder? loadingBuilder,
    required NotifyStyle? notifyStyle,
  }) {
    final host = _hostFor(generation);
    host.defaults = _OverlayHostDefaults(
      toastBuilder: toastBuilder,
      loadingBuilder: loadingBuilder,
      notifyStyle: notifyStyle,
    );
  }

  SuperOverlayToastBuilder? toastBuilderFor(int generation) {
    requireActiveGenerationMatch(generation);
    return _hostFor(generation).defaults.toastBuilder;
  }

  SuperOverlayLoadingBuilder? loadingBuilderFor(int generation) {
    requireActiveGenerationMatch(generation);
    return _hostFor(generation).defaults.loadingBuilder;
  }

  NotifyStyle? notifyStyleFor(int generation) {
    requireActiveGenerationMatch(generation);
    return _hostFor(generation).defaults.notifyStyle;
  }

  void releaseHost(int generation) {
    final host = _hosts[generation];
    if (host == null || !host.mounted) {
      return;
    }
    host.mounted = false;
    _topology = _OverlayHostTopology.pending;
    _scheduleHostReconciliation();
  }

  int requireActiveGeneration() {
    final host = _commandHost;
    _scheduleIdleDetachedScopePrunes(host);
    return host.generation;
  }

  OverlayRouteOwner captureRouteOwner(
    BuildContext context, {
    required String operation,
  }) {
    final host = _commandHost;
    _scheduleIdleDetachedScopePrunes(host);
    return NavigatorScopeRegistry.instance.captureOwnerForContext(
      ownerIdentity: host.ownerIdentity,
      generation: host.generation,
      context: context,
      operation: operation,
    );
  }

  OverlayRouteOwner captureRootRouteOwner({
    required int generation,
    required String operation,
  }) {
    requireActiveGenerationMatch(generation);
    final host = _hostFor(generation);
    _scheduleIdleDetachedScopePrunes(host);
    return NavigatorScopeRegistry.instance.captureRootOwner(
      ownerIdentity: host.ownerIdentity,
      generation: generation,
      operation: operation,
    );
  }

  int? globalCommandGeneration({bool allowEmpty = false}) {
    if (allowEmpty && _topology == _OverlayHostTopology.empty) {
      return null;
    }
    return requireActiveGeneration();
  }

  void requireActiveGenerationMatch(int generation) {
    final host = _commandHost;
    if (host.generation != generation) {
      throw StateError(
        'Overlay generation $generation is no longer the active host.',
      );
    }
  }

  bool ownsGeneration(int generation) {
    return _activeHost?.generation == generation &&
        _hosts[generation]?.resourcesDisposed == false;
  }

  void refreshForGeneration(int generation, VoidCallback refresh) {
    if (ownsGeneration(generation)) {
      refresh();
    }
  }

  _OverlayHostState get _commandHost {
    switch (_topology) {
      case _OverlayHostTopology.active:
        final host = _activeHost;
        if (host != null && host.mounted && !host.resourcesDisposed) {
          return host;
        }
        throw StateError(
          'SuperOverlay host handoff is pending until the current frame completes.',
        );
      case _OverlayHostTopology.pending:
        throw StateError(
          'SuperOverlay host handoff is pending until the current frame completes.',
        );
      case _OverlayHostTopology.conflict:
        throw StateError(
          'Unsupported SuperOverlay host topology: multiple MaterialApp roots '
          'or FlutterViews are mounted in one Dart isolate. Desktop multi-window '
          'requires one isolated overlay runtime per window.',
        );
      case _OverlayHostTopology.empty:
        throw StateError(
          'SuperOverlay is not initialized. Use SuperOverlay.init() in MaterialApp.builder.',
        );
    }
  }

  _OverlayHostState _hostFor(int generation) {
    final host = _hosts[generation];
    if (host == null) {
      throw StateError(
        'Overlay host generation $generation is no longer owned.',
      );
    }
    return host;
  }

  void _scheduleHostReconciliation() {
    // Flutter can unmount the old root after mounting its replacement in the
    // same frame. Delay ownership decisions until both lifecycles are known.
    widgetsBinding.addPostFrameCallback((_) => _reconcileHosts());
  }

  void _reconcileHosts() {
    final detachedCandidates = _candidates
        .where((host) => !host.mounted)
        .toList(growable: false);
    for (final host in detachedCandidates) {
      _candidates.remove(host);
      _retireHost(host);
    }

    final active = _activeHost;
    if (active != null && active.mounted) {
      if (_candidates.isEmpty) {
        _topology = _OverlayHostTopology.active;
      } else {
        _topology = _OverlayHostTopology.conflict;
      }
      _scheduleIdleDetachedScopePrunes(active);
      return;
    }

    if (active != null) {
      _settleActiveGeneration(active);
      _retireHost(active);
      _activeHost = null;
    }

    if (_candidates.length == 1) {
      // The previous generation is fully settled above. Only now may the
      // surviving candidate accept commands or expose its defaults.
      final promoted = _candidates.removeAt(0);
      _activeHost = promoted;
      _nextTagId = 0;
      _topology = _OverlayHostTopology.active;
      _syncBackDispositionForGeneration(promoted.generation);
      _scheduleIdleDetachedScopePrunes(promoted);
      return;
    }

    if (_candidates.isEmpty) {
      _topology = _OverlayHostTopology.empty;
    } else {
      _topology = _OverlayHostTopology.conflict;
    }
  }

  void _settleActiveGeneration(_OverlayHostState host) {
    final generation = host.generation;
    final dialogRecords = <_OverlayRecord>[
      ..._dialogQueue.where((record) => record.generation == generation),
      ..._inFlightDialogRecords.where(
        (record) => record.generation == generation,
      ),
    ];
    final notifyRecords = <_NotifyRecord>[
      ..._notifyQueue.where((record) => record.generation == generation),
      ..._inFlightNotifyRecords.where(
        (record) => record.generation == generation,
      ),
    ];

    for (final record in dialogRecords) {
      record.displayTimer?.cancel();
      record.overlay.mainOverlay.disposeImmediately();
      record.overlay.overlayEntry.remove();
    }
    for (final record in notifyRecords) {
      record.displayTimer?.cancel();
      record.overlay.mainOverlay.disposeImmediately();
      record.overlay.overlayEntry.remove();
    }
    _dialogQueue.removeWhere((record) => record.generation == generation);
    _notifyQueue.removeWhere((record) => record.generation == generation);
    _inFlightDialogRecords.removeWhere(
      (record) => record.generation == generation,
    );
    _inFlightNotifyRecords.removeWhere(
      (record) => record.generation == generation,
    );
    host.loadingOverlay.disposeHost();
    ToastTool.instance.reset(generation: host.generation);
    DebounceUtils.instance.reset();
    _backAttemptsInProgress.remove(generation);
    _nextTagId = 0;
    _syncBackDispositionForGeneration(generation);
  }

  void _retireHost(_OverlayHostState host) {
    NavigatorScopeRegistry.instance.detachHost(
      ownerIdentity: host.ownerIdentity,
      generation: host.generation,
    );
    host.disposeResources();
    _hosts.remove(host.generation);
  }

  Future<T?> show<T>({required ShowCustomParam param}) {
    final generation = requireActiveGeneration();
    validateCommandRoute(
      generation: generation,
      bindToRoute: param.bindPage,
      backType: param.backType,
      onBack: param.onBack,
      operation: 'SuperOverlay dialog',
      routeOwner: param.routeOwner,
    );
    CustomOverlay? overlay;
    final entry = SuperOverlayEntry(builder: (_) => overlay!.getWidget());
    overlay = CustomOverlay(overlayEntry: entry);
    return overlay.show<T>(param: param);
  }

  Future<T?> showAttach<T>({required ShowAttachParam param}) {
    final generation = requireActiveGeneration();
    validateCommandRoute(
      generation: generation,
      bindToRoute: param.bindPage,
      backType: param.backType,
      onBack: param.onBack,
      operation: 'SuperOverlay popup',
      routeOwner: param.routeOwner,
    );
    CustomOverlay? overlay;
    final entry = SuperOverlayEntry(builder: (_) => overlay!.getWidget());
    overlay = CustomOverlay(overlayEntry: entry);
    return overlay.showAttach<T>(param: param);
  }

  Future<T?> showLoading<T>({required ShowLoadingParam param}) {
    final generation = requireActiveGeneration();
    validateCommandRoute(
      generation: generation,
      bindToRoute: false,
      backType: param.backType,
      onBack: param.onBack,
      operation: 'SuperOverlay loading',
    );
    final result = loadingOverlay.showLoading<T>(param: param);
    _syncBackDispositionForGeneration(generation);
    return result;
  }

  Future<T?> showNotify<T>({required ShowNotifyParam param}) {
    final generation = requireActiveGeneration();
    validateCommandRoute(
      generation: generation,
      bindToRoute: false,
      backType: param.backType,
      onBack: param.onBack,
      operation: 'SuperOverlay notification',
    );
    CustomNotify? notify;
    final entry = SuperOverlayEntry(builder: (_) => notify!.getWidget());
    notify = CustomNotify(overlayEntry: entry);
    return notify.showNotify<T>(param: param);
  }

  Future<T?> showToast<T>({required ShowToastParam param}) {
    final generation = requireActiveGeneration();
    return ToastTool.instance.show<T>(param, generation: generation);
  }

  CustomPushResult pushCustom(CustomOverlay overlay, ShowCustomParam param) {
    return _pushDialog(
      overlay: overlay,
      type: OverlayType.custom,
      tag: param.tag,
      businessTag: param.businessTag,
      keepSingle: param.keepSingle,
      permanent: param.permanent,
      displayTime: param.displayTime,
      bindPage: param.bindPage,
      bindWidget: param.bindWidget,
      backType: param.backType,
      onBack: param.onBack,
      routeOwner: param.routeOwner,
      controller: param.controller,
    );
  }

  CustomPushResult pushAttach(CustomOverlay overlay, ShowAttachParam param) {
    return _pushDialog(
      overlay: overlay,
      type: OverlayType.attach,
      tag: param.tag,
      businessTag: param.businessTag,
      keepSingle: param.keepSingle,
      permanent: param.permanent,
      displayTime: param.displayTime,
      bindPage: param.bindPage,
      bindWidget: param.bindWidget,
      backType: param.backType,
      onBack: param.onBack,
      routeOwner: param.routeOwner,
      controller: param.controller,
    );
  }

  NotifyPushResult pushNotify(CustomNotify notify, ShowNotifyParam param) {
    final host = _commandHost;
    final generation = host.generation;
    final overlayContext = host.contextNotify ?? host.contextCustom;
    if (overlayContext == null) {
      throw StateError(
        'SuperOverlay is not initialized. Use SuperOverlay.init() in MaterialApp.builder.',
      );
    }

    final tag =
        param.keepSingle
            ? param.tag ?? '_super_overlay_notify_keep_single'
            : param.tag ?? '_super_overlay_notify_${_nextTagId++}';

    if (param.keepSingle) {
      final existing = _findNotify(tag: tag, generation: generation);
      if (existing != null) {
        _scheduleNotifyTimer(existing, param.displayTime);
        return NotifyPushResult(
          generation: generation,
          tag: existing.tag,
          overlay: existing.overlay,
          reused: true,
        );
      }
    }

    final record = _NotifyRecord(
      generation: generation,
      overlay: notify,
      tag: tag,
      businessTag: param.businessTag,
      backType: param.backType,
      onBack: param.onBack,
    );
    _notifyQueue.addLast(record);
    _syncBackDispositionForGeneration(generation);
    _scheduleNotifyTimer(record, param.displayTime);
    final loadingEntry = host.entryLoading;
    ViewUtils.addSafeUse(() {
      if (!ownsGeneration(generation) || !_notifyQueue.contains(record)) {
        if (_notifyQueue.remove(record)) {
          record.displayTimer?.cancel();
          record.overlay.mainOverlay.disposeImmediately();
          record.overlay.overlayEntry.remove();
          _syncBackDispositionForGeneration(generation);
        }
        return;
      }
      overlayOf(
        overlayContext,
      ).insert(notify.overlayEntry, below: loadingEntry);
    });
    return NotifyPushResult(
      generation: generation,
      tag: tag,
      overlay: notify,
      reused: false,
    );
  }

  CustomPushResult _pushDialog({
    required CustomOverlay overlay,
    required OverlayType type,
    required String? tag,
    required String? businessTag,
    required bool keepSingle,
    required bool permanent,
    required Duration? displayTime,
    required bool bindPage,
    required BuildContext? bindWidget,
    required BackType backType,
    required SuperOverlayOnBack? onBack,
    required OverlayRouteOwner? routeOwner,
    required SuperOverlayController? controller,
  }) {
    final host = _commandHost;
    final generation = host.generation;
    final overlayContext =
        type == OverlayType.attach
            ? host.contextAttach ?? host.contextCustom
            : host.contextCustom;
    if (overlayContext == null) {
      throw StateError(
        'SuperOverlay is not initialized. Use SuperOverlay.init() in MaterialApp.builder.',
      );
    }

    final effectiveTag =
        keepSingle
            ? tag ?? '_super_overlay_keep_single'
            : tag ?? '_super_overlay_${_nextTagId++}';

    if (keepSingle) {
      final existing = _findRecord(
        type: type,
        tag: effectiveTag,
        force: true,
        generation: generation,
      );
      if (existing != null) {
        existing.permanent = permanent;
        _scheduleDisplayTimer(existing, displayTime);
        return CustomPushResult(
          generation: generation,
          tag: existing.tag,
          overlay: existing.overlay,
          reused: true,
        );
      }
    }

    final record = _OverlayRecord(
      generation: generation,
      overlay: overlay,
      type: type,
      tag: effectiveTag,
      businessTag: businessTag,
      permanent: permanent,
      routeOwner: routeOwner,
      bindPage: bindPage,
      bindWidget: bindWidget,
      backType: backType,
      onBack: onBack,
    );
    if (bindPage &&
        routeOwner != null &&
        !NavigatorScopeRegistry.instance.isOwnerCurrent(routeOwner)) {
      record.presentationState =
          _OverlayPresentationState.suspendedBeforeVisible;
      record.overlay.hide();
    }
    _dialogQueue.addLast(record);
    final visible = controller?.visible;
    if (visible != null) {
      unawaited(
        visible.then<void>((_) {
          if (_dialogQueue.contains(record) &&
              record.presentationState == _OverlayPresentationState.showing) {
            record.presentationState = _OverlayPresentationState.visible;
          }
        }, onError: (Object _, StackTrace __) {}),
      );
    }
    _syncBackDispositionForGeneration(generation);
    _scheduleDisplayTimer(record, displayTime);

    final loadingEntry = host.entryLoading;
    ViewUtils.addSafeUse(() {
      if (!ownsGeneration(generation) || !_dialogQueue.contains(record)) {
        if (_dialogQueue.remove(record)) {
          record.displayTimer?.cancel();
          record.overlay.mainOverlay.disposeImmediately();
          record.overlay.overlayEntry.remove();
          _syncBackDispositionForGeneration(generation);
        }
        return;
      }
      overlayOf(
        overlayContext,
      ).insert(overlay.overlayEntry, below: loadingEntry);
    });
    return CustomPushResult(
      generation: generation,
      tag: effectiveTag,
      overlay: overlay,
      reused: false,
    );
  }

  bool checkExist({
    String? tag,
    int? generation,
    Set<OverlayType> types = const {
      OverlayType.custom,
      OverlayType.attach,
      OverlayType.loading,
      OverlayType.notify,
      OverlayType.toast,
    },
  }) {
    final effectiveGeneration = generation;
    if (effectiveGeneration == null) {
      if (_topology == _OverlayHostTopology.empty) {
        return false;
      }
      requireActiveGeneration();
    } else if (!ownsGeneration(effectiveGeneration)) {
      return false;
    }
    final host =
        effectiveGeneration == null
            ? _commandHost
            : _hosts[effectiveGeneration]!;
    if (tag != null) {
      final hasDialog = _dialogQueue.any(
        (record) =>
            (effectiveGeneration == null ||
                record.generation == effectiveGeneration) &&
            types.contains(record.type) &&
            record.matchesTag(tag),
      );
      final hasLoading =
          types.contains(OverlayType.loading) &&
          host.loadingOverlay.matchesTag(tag);
      final hasNotify =
          types.contains(OverlayType.notify) &&
          _notifyQueue.any(
            (record) =>
                (effectiveGeneration == null ||
                    record.generation == effectiveGeneration) &&
                record.matchesTag(tag),
          );
      final hasToast =
          types.contains(OverlayType.toast) &&
          ToastTool.instance.hasTag(tag, generation: host.generation);
      return hasDialog || hasLoading || hasNotify || hasToast;
    }
    if (_dialogQueue.any(
      (record) =>
          (effectiveGeneration == null ||
              record.generation == effectiveGeneration) &&
          types.contains(record.type),
    )) {
      return true;
    }
    if (types.contains(OverlayType.loading) && host.loadingOverlay.isVisible) {
      return true;
    }
    if (types.contains(OverlayType.toast) &&
        ToastTool.instance.isExist(host.generation)) {
      return true;
    }
    if (types.contains(OverlayType.notify) && _notifyQueue.isNotEmpty) {
      return true;
    }
    return false;
  }

  bool isDialogVisible({
    required String tag,
    required int generation,
    required OverlayType type,
  }) {
    if (!ownsGeneration(generation)) {
      return false;
    }
    final record = _findRecord(
      type: type,
      tag: tag,
      force: true,
      generation: generation,
    );
    return record != null &&
        record.overlay.mainOverlay.visible &&
        (record.presentationState == _OverlayPresentationState.showing ||
            record.presentationState == _OverlayPresentationState.visible);
  }

  Future<T?>? existingClosedFuture<T>({
    required String tag,
    required OverlayType type,
    required int generation,
  }) {
    if (!ownsGeneration(generation)) {
      return null;
    }
    if (type == OverlayType.notify) {
      return _findNotify(
        tag: tag,
        generation: generation,
      )?.overlay.mainOverlay.currentClosedFuture<T>(tag: tag);
    }

    final record = _findRecord(
      type: type,
      tag: tag,
      force: true,
      generation: generation,
    );
    return record?.overlay.mainOverlay.currentClosedFuture<T>(tag: tag);
  }

  Future<void>? existingVisibleFuture({
    required String tag,
    required OverlayType type,
    required int generation,
  }) {
    if (!ownsGeneration(generation)) {
      return null;
    }
    if (type == OverlayType.notify) {
      return _findNotify(
        tag: tag,
        generation: generation,
      )?.overlay.mainOverlay.currentVisibleFuture;
    }

    final record = _findRecord(
      type: type,
      tag: tag,
      force: true,
      generation: generation,
    );
    return record?.overlay.mainOverlay.currentVisibleFuture;
  }

  VoidCallback? existingRefresh({
    required String tag,
    required OverlayType type,
    required int generation,
  }) {
    if (!ownsGeneration(generation)) {
      return null;
    }
    if (type == OverlayType.notify) {
      return _findNotify(
        tag: tag,
        generation: generation,
      )?.overlay.mainOverlay.currentRefresh;
    }

    final record = _findRecord(
      type: type,
      tag: tag,
      force: true,
      generation: generation,
    );
    return record?.overlay.mainOverlay.currentRefresh;
  }

  bool get hasMonitoredOverlays {
    return _dialogQueue.any(
      (record) =>
          record.bindWidget != null ||
          (record.bindPage && record.routeOwner != null),
    );
  }

  void handleRoutePushed({
    required Object ownerIdentity,
    required Object scopeIdentity,
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null || !_isActiveRouteHost(host)) {
      return;
    }
    _scheduleIdleDetachedScopePrunes(host);
    if (route is PopupRoute || previousRoute == null) {
      return;
    }

    for (final record in _dialogQueue) {
      if (record.generation == host.generation &&
          _isRouteBoundRecord(record, scopeIdentity, previousRoute)) {
        _suspendRecord(record);
      }
    }
    _syncBackDispositionForGeneration(host.generation);
  }

  void handleRoutePopped({
    required Object ownerIdentity,
    required Object scopeIdentity,
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null || !_isActiveRouteHost(host)) {
      return;
    }
    _scheduleIdleDetachedScopePrunes(host);
    _closeRouteBoundRecords(host.generation, scopeIdentity, route);
    if (route is PopupRoute || previousRoute == null) {
      return;
    }

    for (final record in _dialogQueue) {
      if (record.generation == host.generation &&
          _isRouteBoundRecord(record, scopeIdentity, previousRoute)) {
        _resumeRecord(record);
      }
    }
    _syncBackDispositionForGeneration(host.generation);
  }

  void handleRouteRemoved({
    required Object ownerIdentity,
    required Object scopeIdentity,
    required Route<dynamic> route,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null || !_isActiveRouteHost(host)) {
      return;
    }
    _scheduleIdleDetachedScopePrunes(host);
    _closeRouteBoundRecords(host.generation, scopeIdentity, route);
  }

  void handleRouteReplaced({
    required Object ownerIdentity,
    required Object scopeIdentity,
    required Route<dynamic>? oldRoute,
    required Route<dynamic>? newRoute,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null || !_isActiveRouteHost(host)) {
      return;
    }
    _scheduleIdleDetachedScopePrunes(host);
    if (oldRoute != null) {
      _closeRouteBoundRecords(host.generation, scopeIdentity, oldRoute);
    }
  }

  void handleObserverDisposed({
    required Object ownerIdentity,
    required Object scopeIdentity,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null || !_isActiveRouteHost(host)) {
      return;
    }
    final records = _dialogQueue
        .where(
          (record) =>
              record.generation == host.generation &&
              record.bindPage &&
              identical(record.routeOwner?.scopeIdentity, scopeIdentity),
        )
        .toList(growable: false);
    for (final record in records.reversed) {
      _closeRouteBoundRecord(record);
    }
    _syncBackDispositionForGeneration(host.generation);
  }

  void handleRouteTopologyChanged({required Object ownerIdentity}) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null || !_isActiveRouteHost(host)) {
      return;
    }
    _scheduleIdleDetachedScopePrunes(host);
  }

  void _scheduleIdleDetachedScopePrunes(_OverlayHostState host) {
    if (!host.mounted || host.resourcesDisposed) {
      return;
    }
    final registry = NavigatorScopeRegistry.instance;
    final scopeIdentities = registry.detachedIdleScopeIdentities(
      ownerIdentity: host.ownerIdentity,
      generation: host.generation,
    );
    for (final scopeIdentity in scopeIdentities) {
      if (_hasActiveRouteBoundRecord(host.generation, scopeIdentity) ||
          !_scheduledIdleScopePrunes.add(scopeIdentity)) {
        continue;
      }
      widgetsBinding.ensureVisualUpdate();
      widgetsBinding.addPostFrameCallback((_) {
        _scheduledIdleScopePrunes.remove(scopeIdentity);
        final currentHost = _hosts[host.generation];
        if (!identical(currentHost, host) ||
            !host.mounted ||
            host.resourcesDisposed ||
            _hasActiveRouteBoundRecord(host.generation, scopeIdentity)) {
          return;
        }
        registry.pruneIdleDetachedScope(
          ownerIdentity: host.ownerIdentity,
          generation: host.generation,
          scopeIdentity: scopeIdentity,
        );
      });
    }
  }

  bool _hasActiveRouteBoundRecord(int generation, Object scopeIdentity) {
    return _dialogQueue.any(
      (record) =>
          record.generation == generation &&
          record.bindPage &&
          identical(record.routeOwner?.scopeIdentity, scopeIdentity),
    );
  }

  _OverlayHostState? _routeHostForOwner(Object ownerIdentity) {
    _OverlayHostState? match;
    for (final host in _hosts.values) {
      if (!host.mounted ||
          host.resourcesDisposed ||
          !identical(host.ownerIdentity, ownerIdentity)) {
        continue;
      }
      if (match != null) {
        // One observer attached to multiple hosts cannot be resolved safely.
        return null;
      }
      match = host;
    }
    return match;
  }

  bool _isActiveRouteHost(_OverlayHostState host) {
    return identical(host, _activeHost) && !host.resourcesDisposed;
  }

  void _closeRouteBoundRecords(
    int generation,
    Object scopeIdentity,
    Route<dynamic> route,
  ) {
    if (route is PopupRoute) {
      return;
    }

    final removeList = _dialogQueue
        .where(
          (record) =>
              record.generation == generation &&
              _isRouteBoundRecord(record, scopeIdentity, route),
        )
        .toList(growable: false);
    for (final record in removeList.reversed) {
      _closeRouteBoundRecord(record);
    }
  }

  void _closeRouteBoundRecord(_OverlayRecord record) {
    if (record.presentationState == _OverlayPresentationState.closing ||
        record.presentationState == _OverlayPresentationState.closed) {
      return;
    }
    record.presentationState = _OverlayPresentationState.closing;
    unawaited(
      _closeSingle<void>(
        tag: record.tag,
        result: null,
        force: true,
        type: record.type,
        closeType: OverlayCloseType.route,
        generation: record.generation,
      ).whenComplete(() {
        record.presentationState = _OverlayPresentationState.closed;
      }),
    );
  }

  void _suspendRecord(_OverlayRecord record) {
    switch (record.presentationState) {
      case _OverlayPresentationState.showing:
        record.presentationState =
            _OverlayPresentationState.suspendedBeforeVisible;
        break;
      case _OverlayPresentationState.visible:
        record.presentationState = _OverlayPresentationState.suspended;
        break;
      case _OverlayPresentationState.suspendedBeforeVisible:
      case _OverlayPresentationState.suspended:
      case _OverlayPresentationState.closing:
      case _OverlayPresentationState.closed:
        return;
    }
    record.overlay.hide();
  }

  void _resumeRecord(_OverlayRecord record) {
    switch (record.presentationState) {
      case _OverlayPresentationState.suspendedBeforeVisible:
        record.presentationState = _OverlayPresentationState.showing;
        break;
      case _OverlayPresentationState.suspended:
        record.presentationState = _OverlayPresentationState.visible;
        break;
      case _OverlayPresentationState.showing:
      case _OverlayPresentationState.visible:
      case _OverlayPresentationState.closing:
      case _OverlayPresentationState.closed:
        return;
    }
    record.overlay.appear();
  }

  Future<bool> handleBackEvent() {
    final generation = _activeHost?.generation;
    if (generation == null) {
      return Future<bool>.value(false);
    }
    return handleBackEventForGeneration(generation);
  }

  Future<bool> handleBackEventForGeneration(int generation) {
    if (!ownsGeneration(generation)) {
      return Future<bool>.value(false);
    }
    if (!_backAttemptsInProgress.add(generation)) {
      return Future<bool>.value(true);
    }
    _syncBackDispositionForGeneration(generation);
    return _handleBackEvent(generation).whenComplete(() {
      _backAttemptsInProgress.remove(generation);
      _syncBackDispositionForGeneration(generation);
    });
  }

  void handleWidgetBindingFrame() {
    _handleWidgetBindingFrame();
  }

  Future<void> dismiss<T>({
    DismissStatus status = DismissStatus.auto,
    String? tag,
    T? result,
    bool force = false,
    OverlayCloseType closeType = OverlayCloseType.normal,
    int? generation,
  }) {
    final effectiveGeneration = generation;
    if (effectiveGeneration == null) {
      if (_topology == _OverlayHostTopology.empty) {
        return Future<void>.value();
      }
      requireActiveGeneration();
    } else if (!ownsGeneration(effectiveGeneration)) {
      return Future<void>.value();
    }
    final resolvedGeneration = effectiveGeneration ?? _activeHost!.generation;
    final dismissal = _dismiss<T>(
      status: status,
      tag: tag,
      result: result,
      force: force,
      closeType: closeType,
      generation: resolvedGeneration,
    );
    _syncBackDispositionForGeneration(resolvedGeneration);
    return dismissal.whenComplete(
      () => _syncBackDispositionForGeneration(resolvedGeneration),
    );
  }

  void validateCommandRoute({
    required int generation,
    required bool bindToRoute,
    required BackType backType,
    required SuperOverlayOnBack? onBack,
    required String operation,
    OverlayRouteOwner? routeOwner,
  }) {
    if (routeOwner != null) {
      requireActiveGenerationMatch(generation);
      final host = _hostFor(generation);
      final invocationContext = routeOwner.invocationContext;
      if (routeOwner.generation != generation ||
          !identical(routeOwner.ownerIdentity, host.ownerIdentity) ||
          !NavigatorScopeRegistry.instance.isOwnerTracked(routeOwner) ||
          (invocationContext is Element && !invocationContext.mounted)) {
        throw StateError(
          '$operation route owner is no longer attached to the active '
          'SuperOverlayIntegration.',
        );
      }
      return;
    }
    if (!bindToRoute && backType == BackType.ignore && onBack == null) {
      return;
    }
    requireActiveGenerationMatch(generation);
    final host = _hostFor(generation);
    NavigatorScopeRegistry.instance.requireRootModalRoute(
      ownerIdentity: host.ownerIdentity,
      generation: generation,
      operation: operation,
    );
  }

  void _syncBackDispositionForGeneration(int generation) {
    final host = _hosts[generation];
    if (host == null || host.resourcesDisposed) {
      return;
    }
    NavigatorScopeRegistry.instance.updateBackDisposition(
      ownerIdentity: host.ownerIdentity,
      generation: generation,
      blocked: ownsGeneration(generation) && _generationBlocksBack(generation),
    );
  }

  bool _generationBlocksBack(int generation) {
    if (_backAttemptsInProgress.contains(generation)) {
      return true;
    }
    final loading = _hosts[generation]?.loadingOverlay;
    if (loading != null &&
        (loading.isVisible || loading.isDismissPending) &&
        _canConsumeBack(loading.backType, loading.onBack)) {
      return true;
    }
    if (_notifyQueue.any(
          (record) =>
              record.generation == generation &&
              _canConsumeBack(record.backType, record.onBack),
        ) ||
        _inFlightNotifyRecords.any(
          (record) =>
              record.generation == generation &&
              _canConsumeBack(record.backType, record.onBack),
        )) {
      return true;
    }
    return _dialogQueue.any(
          (record) =>
              record.generation == generation &&
              !record.permanent &&
              record.overlay.mainOverlay.visible &&
              _canConsumeBack(record.backType, record.onBack),
        ) ||
        _inFlightDialogRecords.any(
          (record) =>
              record.generation == generation &&
              _canConsumeBack(record.backType, record.onBack),
        );
  }

  bool _canConsumeBack(BackType backType, SuperOverlayOnBack? onBack) {
    return backType != BackType.ignore || onBack != null;
  }
}
