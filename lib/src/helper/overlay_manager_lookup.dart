part of 'overlay_manager.dart';

extension _OverlayManagerLookup on OverlayManager {
  _NotifyRecord? _findNotify({String? tag, int? generation}) {
    if (_notifyQueue.isEmpty) {
      return null;
    }
    final records = _notifyQueue.toList(growable: false);
    if (tag != null) {
      for (var index = records.length - 1; index >= 0; index--) {
        if (records[index].tag == tag &&
            (generation == null || records[index].generation == generation)) {
          return records[index];
        }
      }
      for (var index = records.length - 1; index >= 0; index--) {
        if (records[index].businessTag == tag &&
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
  }) {
    if (_dialogQueue.isEmpty) {
      return null;
    }

    final records = _dialogQueue.toList(growable: false);
    if (tag != null) {
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.tag == tag &&
            (generation == null || record.generation == generation) &&
            (type == null || record.type == type)) {
          return record;
        }
      }
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.businessTag == tag &&
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

  _OverlayRecord? _lastBackRecord({required int generation}) {
    final records = _dialogQueue.toList(growable: false);
    for (var index = records.length - 1; index >= 0; index--) {
      final record = records[index];
      if (record.generation != generation ||
          record.permanent ||
          !record.overlay.mainOverlay.visible ||
          record.presentationState == _OverlayPresentationState.suspended ||
          record.presentationState ==
              _OverlayPresentationState.suspendedBeforeVisible) {
        continue;
      }
      return record;
    }
    return null;
  }
}
