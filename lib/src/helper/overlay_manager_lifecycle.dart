part of 'overlay_manager.dart';

const _anchorMovementTolerance = 0.5;

extension _OverlayManagerLifecycle on OverlayManager {
  Future<bool> _handleBackEvent(int generation) async {
    if (!ownsGeneration(generation)) {
      return false;
    }
    for (final target in _backTargets(generation)) {
      final handled = await _handleBackConfig(
        generation: generation,
        backType: target.backType,
        onBack: target.onBack,
        close: target.close,
      );
      if (!ownsGeneration(generation)) return false;
      if (handled != null) return handled;
    }
    return false;
  }

  void _handleWidgetBindingFrame() {
    final removeList = <_OverlayRecord>[];
    for (final record in _dialogQueue.toList(growable: false)) {
      final context = record.bindWidget;
      // Unmount is terminal even while the owner route is suspended. Geometry
      // remains deferred until the route is active again.
      if (context != null && !_isContextMounted(context)) {
        removeList.add(record);
        continue;
      }
      final owner = record.routeOwner;
      if (record.bindPage && owner != null) {
        final scopeTracked = NavigatorScopeRegistry.instance.isOwnerTracked(
          owner,
        );
        if (scopeTracked) {
          record.detachedFrameCount = 0;
          final previousState = record.presentationState;
          if (NavigatorScopeRegistry.instance.isOwnerCurrent(owner)) {
            _resumeRecord(record);
          } else {
            _suspendRecord(record);
          }
          if (record.presentationState != previousState) {
            _syncBackDispositionForGeneration(record.generation);
          }
          if (record.presentationState == _OverlayPresentationState.suspended ||
              record.presentationState ==
                  _OverlayPresentationState.suspendedBeforeVisible) {
            continue;
          }
        } else {
          record.detachedFrameCount++;
          if (record.detachedFrameCount == 1) {
            widgetsBinding.ensureVisualUpdate();
          }
          if (record.detachedFrameCount >= 2) {
            removeList.add(record);
            if (!scopeTracked) {
              NavigatorScopeRegistry.instance.pruneDetachedScope(
                owner.scopeIdentity,
              );
            }
          }
          continue;
        }
      }

      if (context == null) {
        continue;
      }

      if (!_isRecordOnCurrentRoute(record)) {
        record.overlay.hide();
        continue;
      }

      final renderBox = OverlayAnchorGeometry.renderBox(context);
      if (renderBox == null) {
        removeList.add(record);
      } else if (record.type == OverlayType.attach) {
        final anchorRect = _anchorRectInOverlay(record, renderBox);
        if (anchorRect == null) {
          removeList.add(record);
          continue;
        }
        record.overlay.appear();
        final previousRect = record.lastRenderedAnchorRect;
        if (previousRect == null ||
            OverlayAnchorGeometry.delta(previousRect, anchorRect) >
                _anchorMovementTolerance) {
          record.lastRenderedAnchorRect = anchorRect;
          record.overlay.mainOverlay.updateAttachTargetRect(anchorRect);
        }
      } else if (OverlayAnchorGeometry.hasInvalidGeometry(renderBox)) {
        record.overlay.hide();
      } else {
        record.overlay.appear();
      }
    }

    for (final record in removeList.reversed) {
      unawaited(
        _dismissOwnedDialogRecord(
          record,
          force: true,
          closeType: OverlayCloseType.normal,
        ),
      );
    }
  }

  Rect? _anchorRectInOverlay(_OverlayRecord record, RenderBox targetRenderBox) {
    final host = _hosts[record.generation];
    final overlayContext = host?.contextAttach ?? host?.contextCustom;
    if (overlayContext == null) {
      return null;
    }

    return OverlayAnchorGeometry.inOverlay(targetRenderBox, overlayContext);
  }

  Future<bool?> _handleBackConfig({
    required int generation,
    required BackType backType,
    required SuperOverlayOnBack? onBack,
    required Future<void> Function() close,
  }) async {
    if (!ownsGeneration(generation)) {
      return false;
    }

    final callbackHandled = await onBack?.call();
    if (!ownsGeneration(generation)) {
      return false;
    }
    if (callbackHandled == true) {
      return true;
    }

    return switch (backType) {
      BackType.normal => () async {
        await close();
        return ownsGeneration(generation);
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
}
