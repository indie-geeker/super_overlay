part of 'overlay_manager.dart';

extension _OverlayManagerLookup on OverlayManager {
  _NotifyRecord? _findInFlightNotifyByIdentity({
    required String identityTag,
    required int generation,
  }) {
    for (final record in _inFlightNotifyRecords) {
      if (record.generation == generation &&
          record.matchesIdentityTag(identityTag)) {
        return record;
      }
    }
    return null;
  }

  _OverlayRecord? _findInFlightRecordByIdentity({
    required OverlayType? type,
    required String identityTag,
    required int generation,
  }) {
    for (final record in _inFlightDialogRecords) {
      if (record.generation == generation &&
          (type == null || record.type == type) &&
          record.matchesIdentityTag(identityTag)) {
        return record;
      }
    }
    return null;
  }

  _NotifyRecord? _findNotifyByBusinessTag({
    required String businessTag,
    required int generation,
  }) {
    for (final record in _notifyQueue.toList(growable: false).reversed) {
      if (record.generation == generation &&
          record.matchesBusinessTag(businessTag)) {
        return record;
      }
    }
    return null;
  }

  _OverlayRecord? _findRecordByBusinessTag({
    required OverlayType type,
    required String businessTag,
    required int generation,
  }) {
    for (final record in _dialogQueue.toList(growable: false).reversed) {
      if (record.generation == generation &&
          record.type == type &&
          record.matchesBusinessTag(businessTag)) {
        return record;
      }
    }
    return null;
  }

  _NotifyRecord? _findNotify({
    String? tag,
    int? generation,
    bool identityTagOnly = false,
  }) {
    if (_notifyQueue.isEmpty) {
      return null;
    }
    final records = _notifyQueue.toList(growable: false);
    if (tag != null) {
      for (var index = records.length - 1; index >= 0; index--) {
        if (records[index].matchesIdentityTag(tag) &&
            (generation == null || records[index].generation == generation)) {
          return records[index];
        }
      }
      if (identityTagOnly) {
        return null;
      }
      for (var index = records.length - 1; index >= 0; index--) {
        if (records[index].matchesBusinessTag(tag) &&
            (generation == null || records[index].generation == generation)) {
          return records[index];
        }
      }
      return null;
    }
    for (final record in records.reversed) {
      if (generation == null || record.generation == generation) {
        return record;
      }
    }
    return null;
  }

  _OverlayRecord? _findRecord({
    required OverlayType? type,
    required String? tag,
    required bool force,
    int? generation,
    bool identityTagOnly = false,
  }) {
    if (_dialogQueue.isEmpty) {
      return null;
    }

    final records = _dialogQueue.toList(growable: false);
    if (tag != null) {
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.matchesIdentityTag(tag) &&
            (generation == null || record.generation == generation) &&
            (type == null || record.type == type)) {
          return record;
        }
      }
      if (identityTagOnly) {
        return null;
      }
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.matchesBusinessTag(tag) &&
            (generation == null || record.generation == generation) &&
            (type == null || record.type == type)) {
          return record;
        }
      }
      return null;
    }

    if (force) {
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.permanent &&
            (generation == null || record.generation == generation) &&
            (type == null || record.type == type)) {
          return record;
        }
      }
    }

    for (var index = records.length - 1; index >= 0; index--) {
      final record = records[index];
      if (generation != null && record.generation != generation) {
        continue;
      }
      if (!force && record.permanent) {
        continue;
      }
      if (type == null || record.type == type) {
        return record;
      }
    }
    return null;
  }

  bool _isRouteBoundRecord(
    _OverlayRecord record,
    Object scopeIdentity,
    Route<dynamic> route,
  ) {
    final owner = record.routeOwner;
    return record.bindPage &&
        owner != null &&
        identical(owner.scopeIdentity, scopeIdentity) &&
        identical(owner.route, route) &&
        owner.route is! PopupRoute;
  }

  bool _isRecordOnCurrentRoute(_OverlayRecord record) {
    final owner = record.routeOwner;
    return !record.bindPage ||
        owner == null ||
        NavigatorScopeRegistry.instance.isOwnerCurrent(owner);
  }

  Iterable<_OverlayBackTarget> _backTargets(int generation) sync* {
    final loading = _hosts[generation]?.loadingOverlay;
    if (loading != null &&
        (loading.isVisible || loading.isDismissPending) &&
        _canConsumeBack(loading.backType, loading.onBack)) {
      final closing = loading.isClosing;
      yield _OverlayBackTarget(
        backType: closing ? BackType.normal : loading.backType,
        onBack: closing ? null : loading.onBack,
        close: loading.captureBackDismissal(),
      );
    }

    // An existing close owns the event until its animation and cleanup settle.
    for (final record in _inFlightNotifyRecords.toList(growable: false)) {
      if (record.generation == generation &&
          _canConsumeBack(record.backType, record.onBack)) {
        yield _OverlayBackTarget(
          backType: BackType.normal,
          close: () => record.dismissal!.future,
        );
      }
    }
    for (final record in _notifyQueue.toList(growable: false).reversed) {
      if (record.generation == generation &&
          _notifyQueue.contains(record) &&
          _canConsumeBack(record.backType, record.onBack)) {
        yield _OverlayBackTarget(
          backType: record.backType,
          onBack: record.onBack,
          close:
              () => _closeNotifyRecord<void>(
                record,
                result: null,
                closeType: OverlayCloseType.back,
              ),
        );
      }
    }
    for (final record in _inFlightDialogRecords.toList(growable: false)) {
      if (record.generation == generation &&
          _canConsumeBack(record.backType, record.onBack)) {
        yield _OverlayBackTarget(
          backType: BackType.normal,
          close: () => record.dismissal!.future,
        );
      }
    }
    for (final record in _dialogQueue.toList(growable: false).reversed) {
      if (record.generation == generation &&
          _dialogQueue.contains(record) &&
          !record.permanent &&
          record.overlay.mainOverlay.visible &&
          record.presentationState != _OverlayPresentationState.suspended &&
          record.presentationState !=
              _OverlayPresentationState.suspendedBeforeVisible &&
          _canConsumeBack(record.backType, record.onBack)) {
        yield _OverlayBackTarget(
          backType: record.backType,
          onBack: record.onBack,
          close:
              () => _closeDialogRecord<void>(
                record,
                result: null,
                closeType: OverlayCloseType.back,
              ),
        );
      }
    }
  }
}
