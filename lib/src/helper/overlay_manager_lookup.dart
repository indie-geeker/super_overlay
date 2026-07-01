part of 'overlay_manager.dart';

extension _OverlayManagerLookup on OverlayManager {
  _NotifyRecord? _findNotify({String? tag}) {
    if (_notifyQueue.isEmpty) {
      return null;
    }
    final records = _notifyQueue.toList(growable: false);
    if (tag != null) {
      for (var index = records.length - 1; index >= 0; index--) {
        if (records[index].tag == tag) {
          return records[index];
        }
      }
      return null;
    }
    return records.last;
  }

  _OverlayRecord? _findRecord({
    required OverlayType? type,
    required String? tag,
    required bool force,
  }) {
    if (_dialogQueue.isEmpty) {
      return null;
    }

    final records = _dialogQueue.toList(growable: false);
    if (tag != null) {
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.tag == tag && (type == null || record.type == type)) {
          return record;
        }
      }
      return null;
    }

    if (force) {
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.permanent && (type == null || record.type == type)) {
          return record;
        }
      }
    }

    for (var index = records.length - 1; index >= 0; index--) {
      final record = records[index];
      if (!force && record.permanent) {
        continue;
      }
      if (type == null || record.type == type) {
        return record;
      }
    }
    return null;
  }

  bool _isRouteBoundRecord(_OverlayRecord record, Route<dynamic> route) {
    return record.bindPage &&
        identical(record.route, route) &&
        record.route is! PopupRoute;
  }

  bool _isRecordOnCurrentRoute(_OverlayRecord record) {
    final currentRoute = RouteRecord.instance.currentRoute;
    return currentRoute == null ||
        identical(record.route, currentRoute) ||
        currentRoute is PopupRoute ||
        !record.bindPage;
  }

  _OverlayRecord? _lastBackRecord() {
    final records = _dialogQueue.toList(growable: false);
    for (var index = records.length - 1; index >= 0; index--) {
      final record = records[index];
      if (record.permanent || !record.overlay.mainOverlay.visible) {
        continue;
      }
      return record;
    }
    return null;
  }
}
