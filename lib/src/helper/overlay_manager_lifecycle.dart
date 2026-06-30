part of 'overlay_manager.dart';

extension _OverlayManagerLifecycle on OverlayManager {
  Future<bool> _handleBackEvent() async {
    if (loadingOverlay.isVisible) {
      final handled = await _handleBackConfig(
        backType: loadingOverlay.backType,
        onBack: loadingOverlay.onBack,
        close: () => dismiss<void>(
          status: DismissStatus.loading,
          closeType: OverlayCloseType.back,
        ),
      );
      if (handled != null) {
        return handled;
      }
    }

    final notifyRecords = _notifyQueue.toList(growable: false);
    for (var index = notifyRecords.length - 1; index >= 0; index--) {
      final record = notifyRecords[index];
      final handled = await _handleBackConfig(
        backType: record.backType,
        onBack: record.onBack,
        close: () => dismiss<void>(
          status: DismissStatus.notify,
          tag: record.tag,
          closeType: OverlayCloseType.back,
        ),
      );
      if (handled != null) {
        return handled;
      }
    }

    final record = _lastBackRecord();
    if (record == null) {
      return false;
    }

    final handled = await _handleBackConfig(
      backType: record.backType,
      onBack: record.onBack,
      close: () => dismiss<void>(
        status: record.type == OverlayType.attach
            ? DismissStatus.attach
            : DismissStatus.custom,
        tag: record.tag,
        closeType: OverlayCloseType.back,
      ),
    );
    return handled ?? false;
  }

  void _handleWidgetBindingFrame() {
    final removeList = <_OverlayRecord>[];
    for (final record in _dialogQueue.toList(growable: false)) {
      final context = record.bindWidget;
      if (context == null) {
        continue;
      }

      if (!_isContextMounted(context)) {
        removeList.add(record);
        continue;
      }

      if (!_isRecordOnCurrentRoute(record)) {
        record.overlay.hide();
        continue;
      }

      final renderBox = _safeRenderBox(context);
      if (renderBox == null) {
        removeList.add(record);
      } else if (_hasInvalidGeometry(renderBox)) {
        record.overlay.hide();
      } else {
        record.overlay.appear();
      }
    }

    for (final record in removeList.reversed) {
      unawaited(
        _closeSingle<void>(
          tag: record.tag,
          result: null,
          force: true,
          type: record.type,
          closeType: OverlayCloseType.normal,
        ),
      );
    }
  }

  Future<bool?> _handleBackConfig({
    required BackType backType,
    required SuperOverlayOnBack? onBack,
    required Future<void> Function() close,
  }) async {
    if (await onBack?.call() == true) {
      return true;
    }

    return switch (backType) {
      BackType.normal => () async {
        await close();
        return true;
      }(),
      BackType.block => true,
      BackType.ignore => null,
    };
  }

  bool _isContextMounted(BuildContext context) {
    if (context is Element) {
      return context.mounted;
    }
    return true;
  }

  RenderBox? _safeRenderBox(BuildContext context) {
    try {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.attached &&
          renderObject.hasSize) {
        return renderObject;
      }
    } catch (_) {}
    return null;
  }

  bool _hasInvalidGeometry(RenderBox renderBox) {
    try {
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      return size.isEmpty ||
          offset.dx < 0 ||
          offset.dy < 0 ||
          offset.dx.isNaN ||
          offset.dy.isNaN ||
          offset.dx.isInfinite ||
          offset.dy.isInfinite;
    } catch (_) {
      return true;
    }
  }
}
