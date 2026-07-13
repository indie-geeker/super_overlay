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
import '../kit/super_overlay_entry.dart';
import '../kit/typedef.dart';
import '../kit/view_utils.dart';
import 'route_record.dart';

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
    final host = _OverlayHostState(
      generation: _nextGeneration++,
      ownerIdentity: ownerIdentity,
      defaults: _OverlayHostDefaults(
        toastBuilder: toastBuilder,
        loadingBuilder: loadingBuilder,
        notifyStyle: notifyStyle,
      ),
    );
    _hosts[host.generation] = host;

    if (_activeHost == null && _candidates.isEmpty) {
      _activeHost = host;
      _topology = _OverlayHostTopology.active;
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

  int requireActiveGeneration() => _commandHost.generation;

  int? globalCommandGeneration({bool allowEmpty = false}) {
    if (allowEmpty && _topology == _OverlayHostTopology.empty) {
      return null;
    }
    return _commandHost.generation;
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
      RouteRecord.instance.replaceWith(promoted.routeRecord);
      _nextTagId = 0;
      _topology = _OverlayHostTopology.active;
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
    RouteRecord.instance.reset();
    _nextTagId = 0;
  }

  void _retireHost(_OverlayHostState host) {
    host.disposeResources();
    _hosts.remove(host.generation);
  }

  Future<T?> show<T>({required ShowCustomParam param}) {
    requireActiveGeneration();
    CustomOverlay? overlay;
    final entry = SuperOverlayEntry(builder: (_) => overlay!.getWidget());
    overlay = CustomOverlay(overlayEntry: entry);
    return overlay.show<T>(param: param);
  }

  Future<T?> showAttach<T>({required ShowAttachParam param}) {
    requireActiveGeneration();
    CustomOverlay? overlay;
    final entry = SuperOverlayEntry(builder: (_) => overlay!.getWidget());
    overlay = CustomOverlay(overlayEntry: entry);
    return overlay.showAttach<T>(param: param);
  }

  Future<T?> showLoading<T>({required ShowLoadingParam param}) {
    requireActiveGeneration();
    return loadingOverlay.showLoading<T>(param: param);
  }

  Future<T?> showNotify<T>({required ShowNotifyParam param}) {
    requireActiveGeneration();
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
    _scheduleNotifyTimer(record, param.displayTime);
    final loadingEntry = host.entryLoading;
    ViewUtils.addSafeUse(() {
      if (!ownsGeneration(generation) || !_notifyQueue.contains(record)) {
        if (_notifyQueue.remove(record)) {
          record.displayTimer?.cancel();
          record.overlay.mainOverlay.disposeImmediately();
          record.overlay.overlayEntry.remove();
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
      route: host.routeRecord.currentRoute,
      bindPage: bindPage,
      bindWidget: bindWidget,
      backType: backType,
      onBack: onBack,
    );
    _dialogQueue.addLast(record);
    _scheduleDisplayTimer(record, displayTime);

    final loadingEntry = host.entryLoading;
    ViewUtils.addSafeUse(() {
      if (!ownsGeneration(generation) || !_dialogQueue.contains(record)) {
        if (_dialogQueue.remove(record)) {
          record.displayTimer?.cancel();
          record.overlay.mainOverlay.disposeImmediately();
          record.overlay.overlayEntry.remove();
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

  bool get hasWidgetBoundOverlays {
    return _dialogQueue.any((record) => record.bindWidget != null);
  }

  void handleRoutePushed({
    required Object ownerIdentity,
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null) {
      return;
    }
    host.routeRecord.push(route);
    if (!_isActiveRouteHost(host)) {
      return;
    }
    RouteRecord.instance.replaceWith(host.routeRecord);
    if (route is PopupRoute || previousRoute == null) {
      return;
    }

    for (final record in _dialogQueue) {
      if (record.generation == host.generation &&
          _isRouteBoundRecord(record, previousRoute)) {
        record.overlay.hide();
      }
    }
  }

  void handleRoutePopped({
    required Object ownerIdentity,
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null) {
      return;
    }
    host.routeRecord.pop(route, previousRoute);
    if (!_isActiveRouteHost(host)) {
      return;
    }
    RouteRecord.instance.replaceWith(host.routeRecord);
    _closeRouteBoundRecords(host.generation, route);
    if (route is PopupRoute || previousRoute == null) {
      return;
    }

    for (final record in _dialogQueue) {
      if (record.generation == host.generation &&
          _isRouteBoundRecord(record, previousRoute)) {
        record.overlay.appear();
      }
    }
  }

  void handleRouteRemoved({
    required Object ownerIdentity,
    required Route<dynamic> route,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null) {
      return;
    }
    host.routeRecord.remove(route);
    if (!_isActiveRouteHost(host)) {
      return;
    }
    RouteRecord.instance.replaceWith(host.routeRecord);
    _closeRouteBoundRecords(host.generation, route);
  }

  void handleRouteReplaced({
    required Object ownerIdentity,
    required Route<dynamic>? oldRoute,
    required Route<dynamic>? newRoute,
  }) {
    final host = _routeHostForOwner(ownerIdentity);
    if (host == null) {
      return;
    }
    host.routeRecord.replace(oldRoute: oldRoute, newRoute: newRoute);
    if (!_isActiveRouteHost(host)) {
      return;
    }
    RouteRecord.instance.replaceWith(host.routeRecord);
    if (oldRoute != null) {
      _closeRouteBoundRecords(host.generation, oldRoute);
    }
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

  void _closeRouteBoundRecords(int generation, Route<dynamic> route) {
    if (route is PopupRoute) {
      return;
    }

    final removeList = _dialogQueue
        .where(
          (record) =>
              record.generation == generation &&
              _isRouteBoundRecord(record, route),
        )
        .toList(growable: false);
    for (final record in removeList.reversed) {
      unawaited(
        _closeSingle<void>(
          tag: record.tag,
          result: null,
          force: true,
          type: record.type,
          closeType: OverlayCloseType.route,
          generation: record.generation,
        ),
      );
    }
  }

  Future<bool> handleBackEvent() {
    return _handleBackEvent();
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
    return _dismiss<T>(
      status: status,
      tag: tag,
      result: result,
      force: force,
      closeType: closeType,
      generation: effectiveGeneration ?? _activeHost!.generation,
    );
  }
}
