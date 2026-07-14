part of 'overlay_manager.dart';

extension _OverlayManagerDismiss on OverlayManager {
  Future<void> _dismiss<T>({
    DismissStatus status = DismissStatus.auto,
    String? tag,
    T? result,
    bool force = false,
    OverlayCloseType closeType = OverlayCloseType.normal,
    required int generation,
  }) async {
    final host = _hosts[generation];
    if (host == null || host.resourcesDisposed) {
      return;
    }
    final generationLoading = host.loadingOverlay;
    if (status == DismissStatus.auto) {
      if ((generationLoading.isVisible || generationLoading.isDismissPending) &&
          (tag == null || generationLoading.matchesDismissTag(tag))) {
        await generationLoading.dismiss(closeType: closeType, tag: tag);
        return;
      }

      final hasMatchingNotify = _notifyQueue.any(
        (record) =>
            record.generation == generation &&
            (tag == null || record.matchesTag(tag)),
      );
      if (hasMatchingNotify) {
        await _closeNotify<T>(
          tag: tag,
          result: result,
          closeType: closeType,
          generation: generation,
        );
        return;
      }

      final hasMatchingDialog = _dialogQueue.any(
        (record) =>
            record.generation == generation &&
            (tag == null || record.matchesTag(tag)) &&
            (force || !record.permanent),
      );
      if (hasMatchingDialog) {
        await _closeSingle<T>(
          tag: tag,
          result: result,
          force: force,
          type: null,
          closeType: closeType,
          generation: generation,
        );
        return;
      }

      if (tag == null ||
          ToastTool.instance.hasTag(tag, generation: generation)) {
        await ToastTool.instance.dismiss(generation: generation, tag: tag);
      }
      return;
    }

    if (status == DismissStatus.custom ||
        status == DismissStatus.attach ||
        status == DismissStatus.dialog) {
      await _closeSingle<T>(
        tag: tag,
        result: result,
        force: force,
        type: switch (status) {
          DismissStatus.custom => OverlayType.custom,
          DismissStatus.attach => OverlayType.attach,
          _ => null,
        },
        closeType: closeType,
        generation: generation,
      );
      return;
    }

    if (status == DismissStatus.allCustom ||
        status == DismissStatus.allAttach ||
        status == DismissStatus.allDialog) {
      await _closeAll<T>(
        tag: tag,
        result: result,
        force: force,
        type: switch (status) {
          DismissStatus.allCustom => OverlayType.custom,
          DismissStatus.allAttach => OverlayType.attach,
          _ => null,
        },
        closeType: closeType,
        generation: generation,
      );
      return;
    }

    if (status == DismissStatus.notify) {
      await _closeNotify<T>(
        tag: tag,
        result: result,
        closeType: closeType,
        generation: generation,
      );
      return;
    }

    if (status == DismissStatus.allNotify) {
      final records = _notifyQueue
          .where((record) => record.generation == generation)
          .where((record) => tag == null || record.matchesTag(tag))
          .toList(growable: false);
      for (final record in records.reversed) {
        await _closeNotify<T>(
          tag: record.tag,
          result: result,
          closeType: closeType,
          generation: generation,
        );
      }
      return;
    }

    if (status == DismissStatus.loading) {
      if (tag == null || generationLoading.matchesDismissTag(tag)) {
        await generationLoading.dismiss(closeType: closeType, tag: tag);
      }
      return;
    }

    if (status == DismissStatus.toast) {
      await ToastTool.instance.dismiss(generation: generation, tag: tag);
      return;
    }

    if (status == DismissStatus.allToast) {
      await ToastTool.instance.dismiss(
        generation: generation,
        closeAll: tag == null,
        tag: tag,
      );
    }
  }

  Future<void> _closeAll<T>({
    required String? tag,
    required T? result,
    required bool force,
    required OverlayType? type,
    required OverlayCloseType closeType,
    required int generation,
  }) async {
    final records = _dialogQueue
        .where((record) => record.generation == generation)
        .where((record) => type == null || record.type == type)
        .where((record) => tag == null || record.matchesTag(tag))
        .where((record) => force || !record.permanent)
        .toList(growable: false);

    for (final record in records.reversed) {
      await _closeSingle<T>(
        tag: record.tag,
        result: result,
        force: force,
        type: record.type,
        closeType: closeType,
        generation: generation,
      );
    }
  }

  Future<void> _closeSingle<T>({
    required T? result,
    required bool force,
    required OverlayType? type,
    required OverlayCloseType closeType,
    required int generation,
    String? tag,
  }) async {
    final record = _findRecord(
      type: type,
      tag: tag,
      force: force,
      generation: generation,
    );
    if (record == null || (record.permanent && !force)) {
      return;
    }

    record.overlay.mainOverlay.validateDismissResult<T>(
      tag: record.businessTag ?? record.tag,
      result: result,
    );
    record.presentationState = _OverlayPresentationState.closing;
    _dialogQueue.remove(record);
    _inFlightDialogRecords.add(record);
    _syncBackDispositionForGeneration(generation);
    record.displayTimer?.cancel();
    try {
      await record.overlay.dismiss<T>(result: result, closeType: closeType);
    } finally {
      _inFlightDialogRecords.remove(record);
      record.presentationState = _OverlayPresentationState.closed;
      record.overlay.overlayEntry.remove();
      _syncBackDispositionForGeneration(generation);
    }
  }

  void _scheduleDisplayTimer(_OverlayRecord record, Duration? displayTime) {
    record.displayTimer?.cancel();
    if (displayTime == null) {
      record.displayTimer = null;
      return;
    }
    record.displayTimer = Timer(displayTime, () {
      dismiss<void>(
        status:
            record.type == OverlayType.attach
                ? DismissStatus.attach
                : DismissStatus.custom,
        tag: record.tag,
        generation: record.generation,
      );
    });
  }

  void _scheduleNotifyTimer(_NotifyRecord record, Duration? displayTime) {
    record.displayTimer?.cancel();
    if (displayTime == null) {
      record.displayTimer = null;
      return;
    }
    record.displayTimer = Timer(displayTime, () {
      dismiss<void>(
        status: DismissStatus.notify,
        tag: record.tag,
        generation: record.generation,
      );
    });
  }

  Future<void> _closeNotify<T>({
    String? tag,
    T? result,
    OverlayCloseType closeType = OverlayCloseType.normal,
    required int generation,
  }) async {
    final record = _findNotify(tag: tag, generation: generation);
    if (record == null) {
      return;
    }

    _notifyQueue.remove(record);
    _inFlightNotifyRecords.add(record);
    _syncBackDispositionForGeneration(generation);
    record.displayTimer?.cancel();
    try {
      await record.overlay.dismiss<T>(result: result, closeType: closeType);
    } finally {
      _inFlightNotifyRecords.remove(record);
      record.overlay.overlayEntry.remove();
      _syncBackDispositionForGeneration(generation);
    }
  }
}
