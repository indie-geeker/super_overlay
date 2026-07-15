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
      await _closeAllNotify<T>(
        tag: tag,
        result: result,
        closeType: closeType,
        generation: generation,
      );
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
    bool businessTagOnly = false,
    bool includeInFlight = false,
  }) async {
    final records = _dialogQueue
        .where((record) => record.generation == generation)
        .where((record) => type == null || record.type == type)
        .where(
          (record) =>
              tag == null ||
              (businessTagOnly
                  ? record.matchesBusinessTag(tag)
                  : record.matchesTag(tag)),
        )
        .where((record) => force || !record.permanent)
        .toList(growable: false);
    final inFlightRecords =
        includeInFlight
            ? _inFlightDialogRecords
                .where((record) => record.generation == generation)
                .where((record) => type == null || record.type == type)
                .where(
                  (record) =>
                      tag == null ||
                      (businessTagOnly
                          ? record.matchesBusinessTag(tag)
                          : record.matchesTag(tag)),
                )
                .toList(growable: false)
            : const <_OverlayRecord>[];

    for (final record in records.reversed) {
      if ((record.permanent && !force) ||
          (!_dialogQueue.contains(record) && record.dismissal == null)) {
        continue;
      }
      await _closeDialogRecord<T>(record, result: result, closeType: closeType);
    }
    for (final record in inFlightRecords) {
      final dismissal = record.dismissal;
      if (dismissal != null) {
        await dismissal.future;
      }
    }
  }

  Future<void> _closeSingle<T>({
    required T? result,
    required bool force,
    required OverlayType? type,
    required OverlayCloseType closeType,
    required int generation,
    String? tag,
    bool identityTagOnly = false,
  }) async {
    var record = _findRecord(
      type: type,
      tag: tag,
      force: force,
      generation: generation,
      identityTagOnly: identityTagOnly,
    );
    if (record == null && identityTagOnly && tag != null) {
      record = _findInFlightRecordByIdentity(
        type: type,
        identityTag: tag,
        generation: generation,
      );
    }
    if (record == null ||
        (record.dismissal == null && record.permanent && !force)) {
      return;
    }

    await _closeDialogRecord<T>(record, result: result, closeType: closeType);
  }

  Future<void> _closeDialogRecord<T>(
    _OverlayRecord record, {
    required T? result,
    required OverlayCloseType closeType,
  }) {
    final existingDismissal = record.dismissal;
    if (existingDismissal != null) {
      return existingDismissal.future;
    }

    record.overlay.mainOverlay.validateDismissResult<T>(
      tag: record.businessTag ?? record.tag,
      result: result,
    );
    final dismissal = _RecordDismissalOperation();
    record.dismissal = dismissal;
    record.presentationState = _OverlayPresentationState.closing;
    _dialogQueue.remove(record);
    _inFlightDialogRecords.add(record);
    _syncBackDispositionForGeneration(record.generation);
    record.displayTimer?.cancel();
    unawaited(
      _runDialogDismissal<T>(
        record,
        dismissal,
        result: result,
        closeType: closeType,
      ),
    );
    return dismissal.future;
  }

  Future<void> _runDialogDismissal<T>(
    _OverlayRecord record,
    _RecordDismissalOperation dismissal, {
    required T? result,
    required OverlayCloseType closeType,
  }) async {
    try {
      await record.overlay.dismiss<T>(result: result, closeType: closeType);
      _finalizeDialogDismissal(record, dismissal);
      dismissal.complete();
    } catch (error, stackTrace) {
      try {
        _finalizeDialogDismissal(record, dismissal);
      } catch (_) {
        // Preserve the first dismissal failure for every joined caller.
      }
      dismissal.completeError(error, stackTrace);
    }
  }

  void _finalizeDialogDismissal(
    _OverlayRecord record,
    _RecordDismissalOperation dismissal,
  ) {
    if (!dismissal.beginCleanup()) {
      return;
    }
    _inFlightDialogRecords.remove(record);
    record.presentationState = _OverlayPresentationState.closed;
    record.overlay.overlayEntry.remove();
    _syncBackDispositionForGeneration(record.generation);
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
    bool identityTagOnly = false,
  }) async {
    var record = _findNotify(
      tag: tag,
      generation: generation,
      identityTagOnly: identityTagOnly,
    );
    if (record == null && identityTagOnly && tag != null) {
      record = _findInFlightNotifyByIdentity(
        identityTag: tag,
        generation: generation,
      );
    }
    if (record == null) {
      return;
    }

    await _closeNotifyRecord<T>(record, result: result, closeType: closeType);
  }

  Future<void> _closeAllNotify<T>({
    required String? tag,
    required T? result,
    required OverlayCloseType closeType,
    required int generation,
    bool businessTagOnly = false,
    bool includeInFlight = false,
  }) async {
    final records = _notifyQueue
        .where((record) => record.generation == generation)
        .where(
          (record) =>
              tag == null ||
              (businessTagOnly
                  ? record.matchesBusinessTag(tag)
                  : record.matchesTag(tag)),
        )
        .toList(growable: false);
    final inFlightRecords =
        includeInFlight
            ? _inFlightNotifyRecords
                .where((record) => record.generation == generation)
                .where(
                  (record) =>
                      tag == null ||
                      (businessTagOnly
                          ? record.matchesBusinessTag(tag)
                          : record.matchesTag(tag)),
                )
                .toList(growable: false)
            : const <_NotifyRecord>[];

    for (final record in records.reversed) {
      if (!_notifyQueue.contains(record) && record.dismissal == null) {
        continue;
      }
      await _closeNotifyRecord<T>(record, result: result, closeType: closeType);
    }
    for (final record in inFlightRecords) {
      final dismissal = record.dismissal;
      if (dismissal != null) {
        await dismissal.future;
      }
    }
  }

  Future<void> _closeNotifyRecord<T>(
    _NotifyRecord record, {
    required T? result,
    required OverlayCloseType closeType,
  }) {
    final existingDismissal = record.dismissal;
    if (existingDismissal != null) {
      return existingDismissal.future;
    }

    final dismissal = _RecordDismissalOperation();
    record.dismissal = dismissal;
    _notifyQueue.remove(record);
    _inFlightNotifyRecords.add(record);
    _syncBackDispositionForGeneration(record.generation);
    record.displayTimer?.cancel();
    unawaited(
      _runNotifyDismissal<T>(
        record,
        dismissal,
        result: result,
        closeType: closeType,
      ),
    );
    return dismissal.future;
  }

  Future<void> _runNotifyDismissal<T>(
    _NotifyRecord record,
    _RecordDismissalOperation dismissal, {
    required T? result,
    required OverlayCloseType closeType,
  }) async {
    try {
      await record.overlay.dismiss<T>(result: result, closeType: closeType);
      _finalizeNotifyDismissal(record, dismissal);
      dismissal.complete();
    } catch (error, stackTrace) {
      try {
        _finalizeNotifyDismissal(record, dismissal);
      } catch (_) {
        // Preserve the first dismissal failure for every joined caller.
      }
      dismissal.completeError(error, stackTrace);
    }
  }

  void _finalizeNotifyDismissal(
    _NotifyRecord record,
    _RecordDismissalOperation dismissal,
  ) {
    if (!dismissal.beginCleanup()) {
      return;
    }
    _inFlightNotifyRecords.remove(record);
    record.overlay.overlayEntry.remove();
    _syncBackDispositionForGeneration(record.generation);
  }
}
