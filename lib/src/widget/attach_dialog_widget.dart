import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../data/animation_param.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/typedef.dart';
import 'animation/fade_animation.dart';
import 'animation/highlight_mask_animation.dart';
import 'animation/scale_animation.dart';
import 'animation/slide_animation.dart';
import 'animation/popup_reveal_animation.dart';
import 'helper/attach_widget.dart';
import 'helper/dialog_scope.dart';
import 'helper/mask_event.dart';
import 'highlight_mask.dart';

class AttachDialogWidget extends StatefulWidget {
  const AttachDialogWidget({
    super.key,
    required this.param,
    required this.controller,
    required this.targetRectListenable,
    required this.onMask,
    required this.onTargetUnavailable,
  });

  final ShowAttachParam param;
  final AttachDialogWidgetController controller;
  final ValueListenable<Rect?> targetRectListenable;
  final VoidCallback onMask;
  final Future<void> Function() onTargetUnavailable;

  @override
  State<AttachDialogWidget> createState() => _AttachDialogWidgetState();
}

class _AttachDialogWidgetState extends State<AttachDialogWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bodyController;
  AnimationParam? _animationParam;
  PopupLayoutInfo? _layoutInfo;
  PopupLayoutInfo? _pendingLayoutInfo;
  Alignment? _adjustedAlignment;
  bool _targetFailureScheduled = false;

  ShowAttachParam get param => widget.param;

  @override
  void initState() {
    super.initState();
    _bodyController = AnimationController(vsync: this);
    widget.controller._bind(this);
    widget.targetRectListenable.addListener(_handleTargetRectChanged);
    _forward();
  }

  @override
  void didUpdateWidget(covariant AttachDialogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._unbind(this);
    }
    widget.controller._bind(this);
    if (!identical(
      oldWidget.targetRectListenable,
      widget.targetRectListenable,
    )) {
      oldWidget.targetRectListenable.removeListener(_handleTargetRectChanged);
      widget.targetRectListenable.addListener(_handleTargetRectChanged);
    }
    if (oldWidget.param != widget.param) {
      _layoutInfo = null;
      _pendingLayoutInfo = null;
      _adjustedAlignment = null;
      _forward();
    }
  }

  @override
  void dispose() {
    widget.controller._unbind(this);
    widget.targetRectListenable.removeListener(_handleTargetRectChanged);
    _bodyController.dispose();
    super.dispose();
  }

  void _handleTargetRectChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetRect = _targetRect(context);
    if (targetRect == null) {
      _scheduleTargetFailure();
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    double inset(double padding, double keyboard) =>
        padding > keyboard ? padding : keyboard;
    final viewInsets = EdgeInsets.fromLTRB(
      inset(media.viewPadding.left, media.viewInsets.left),
      inset(media.viewPadding.top, media.viewInsets.top),
      inset(media.viewPadding.right, media.viewInsets.right),
      inset(media.viewPadding.bottom, media.viewInsets.bottom),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMask(targetRect),
        CustomSingleChildLayout(
          delegate: AttachPositionDelegate(
            targetRect: targetRect,
            alignment: _effectiveAlignment,
            alignmentMode: param.alignmentMode,
            onLayout: _handleLayout,
            viewInsets: viewInsets,
            allowFlip: _adjustedAlignment == null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: _buildBodyAnimation(_buildBody()),
          ),
        ),
      ],
    );
  }

  Alignment get _effectiveAlignment => _adjustedAlignment ?? param.alignment;

  Alignment get _animationAlignment {
    final alignment = _effectiveAlignment;
    final info = _layoutInfo;
    if (info == null) {
      return alignment;
    }
    final target = info.targetOffset & info.targetSize;
    final popup = info.popupOffset & info.popupSize;
    if (alignment.y == 1 && popup.bottom <= target.top) {
      return Alignment(alignment.x, -1);
    }
    if (alignment.y == -1 && popup.top >= target.bottom) {
      return Alignment(alignment.x, 1);
    }
    if (alignment == Alignment.centerRight && popup.right <= target.left) {
      return Alignment.centerLeft;
    }
    if (alignment == Alignment.centerLeft && popup.left >= target.right) {
      return Alignment.centerRight;
    }
    return alignment;
  }

  void _scheduleTargetFailure() {
    if (_targetFailureScheduled) {
      return;
    }
    _targetFailureScheduled = true;
    param.controller?.failVisible(
      'The popup could not become visible because its target geometry is unavailable.',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.onTargetUnavailable());
      }
    });
  }

  Widget _buildBody() {
    final layoutInfo = _layoutInfo;
    var builder = param.builder;

    if (layoutInfo != null) {
      final adjustment = param.adjustmentBuilder?.call(layoutInfo);
      final adjustedAlignment = adjustment?.alignment;
      if (adjustedAlignment != null &&
          adjustedAlignment != _adjustedAlignment) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _adjustedAlignment = adjustedAlignment);
          }
        });
      }

      if (adjustment?.builder != null) {
        builder = adjustment!.builder!;
      } else {
        final replacementBuilder = param.replacementBuilder;
        if (replacementBuilder != null) {
          builder = (_) => replacementBuilder(layoutInfo);
        }
      }
    }

    return DialogScope(controller: param.controller, builder: builder);
  }

  Widget _buildBodyAnimation(Widget child) {
    final animationBuilder = param.animationBuilder;
    if (animationBuilder != null) {
      return animationBuilder(
        _bodyController,
        child,
        _animationParam = AnimationParam(
          alignment: _animationAlignment,
          animationTime: param.animationTime,
        ),
      );
    }

    return switch (param.animationType) {
      AnimationType.fade => FadeAnimation(
        controller: _bodyController,
        child: child,
      ),
      AnimationType.scale => ScaleAnimation(
        controller: _bodyController,
        alignment: _scaleAlignment,
        child: child,
      ),
      AnimationType.size => PopupRevealAnimation(
        controller: _bodyController,
        alignment: _animationAlignment,
        child: child,
      ),
      AnimationType.centerFadeOtherSlide =>
        _effectiveAlignment == Alignment.center
            ? FadeAnimation(controller: _bodyController, child: child)
            : SlideAnimation(
              controller: _bodyController,
              alignment: _animationAlignment,
              child: child,
            ),
      AnimationType.centerScaleOtherSlide =>
        _effectiveAlignment == Alignment.center
            ? ScaleAnimation(
              controller: _bodyController,
              alignment: _scaleAlignment,
              child: child,
            )
            : SlideAnimation(
              controller: _bodyController,
              alignment: _animationAlignment,
              child: child,
            ),
    };
  }

  Alignment get _scaleAlignment {
    final layoutInfo = _layoutInfo;
    final scaleOriginBuilder = param.scaleOriginBuilder;
    if (layoutInfo == null || scaleOriginBuilder == null) {
      return Alignment.center;
    }

    final popupSize = layoutInfo.popupSize;
    if (popupSize.width == 0 || popupSize.height == 0) {
      return Alignment.center;
    }

    final scaleOrigin = scaleOriginBuilder(popupSize);
    return Alignment(
      (scaleOrigin.dx - popupSize.width / 2) / (popupSize.width / 2),
      (scaleOrigin.dy - popupSize.height / 2) / (popupSize.height / 2),
    );
  }

  void _handleLayout(PopupLayoutInfo info) {
    if (_layoutInfo == info || _pendingLayoutInfo == info) {
      return;
    }
    _pendingLayoutInfo = info;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _layoutInfo == info) {
        return;
      }
      setState(() {
        _layoutInfo = info;
        _pendingLayoutInfo = null;
      });
    });
  }

  void _forward() {
    _bodyController.duration = _openDuration;
    _bodyController.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationParam?.onForward?.call();
    });
  }

  Duration get _openDuration {
    if (!param.useAnimation ||
        param.nonAnimationTypes.contains(NonAnimationType.open)) {
      return Duration.zero;
    }
    return param.animationTime;
  }

  Future<void> dismiss({
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) async {
    final duration = _closeDuration(closeType);
    _bodyController.duration = duration;
    _animationParam?.onDismiss?.call();
    _bodyController.reverse();
    if (duration > Duration.zero) {
      await Future<void>.delayed(duration);
    }
  }

  Duration _closeDuration(OverlayCloseType closeType) {
    if (!param.useAnimation ||
        param.nonAnimationTypes.contains(NonAnimationType.close) ||
        _hasCloseTypeSkip(closeType)) {
      return Duration.zero;
    }
    return param.animationTime;
  }

  bool _hasCloseTypeSkip(OverlayCloseType closeType) {
    return switch (closeType) {
      OverlayCloseType.normal => false,
      OverlayCloseType.mask => param.nonAnimationTypes.contains(
        NonAnimationType.maskClose,
      ),
      OverlayCloseType.route => param.nonAnimationTypes.contains(
        NonAnimationType.routeClose,
      ),
      OverlayCloseType.back => param.nonAnimationTypes.contains(
        NonAnimationType.backClose,
      ),
    };
  }

  Widget _buildMask(Rect targetRect) {
    final highlight = param.highlight;
    final mask =
        highlight != null
            ? HighlightMaskAnimation(
              controller: _bodyController,
              animate:
                  param.useAnimation &&
                  !param.nonAnimationTypes.contains(
                    NonAnimationType.highlightMask,
                  ),
              child: HighlightMask(
                targetRect: targetRect,
                maskColor: param.maskColor,
                padding: highlight.padding,
                borderRadius: highlight.borderRadius,
                onDismiss: widget.onMask,
              ),
            )
            : (param.maskWidget ?? ColoredBox(color: param.maskColor));

    if (param.usePenetrate) {
      return _applyMaskIgnoreArea(IgnorePointer(child: mask));
    }

    return _applyMaskIgnoreArea(
      MaskEvent(
        maskTriggerType: param.maskTriggerType,
        onMask: widget.onMask,
        dismissible: param.clickMaskDismiss,
        semanticsLabel: param.barrierSemanticsLabel,
        child: mask,
      ),
    );
  }

  Widget _applyMaskIgnoreArea(Widget maskLayer) {
    final area = param.maskIgnoreArea;
    if (area == null) {
      return maskLayer;
    }

    return ClipPath(
      clipper: _MaskIgnoreRectClipper(area),
      clipBehavior: Clip.hardEdge,
      child: maskLayer,
    );
  }

  Rect? _targetRect(BuildContext context) {
    final targetContext = param.targetContext;
    final trackedRect = widget.targetRectListenable.value;
    var hasTargetInfo = trackedRect != null;
    var targetOffset = trackedRect?.topLeft ?? Offset.zero;
    var targetSize = trackedRect?.size ?? Size.zero;

    if (!hasTargetInfo) {
      final renderObject =
          targetContext?.mounted == true
              ? targetContext?.findRenderObject()
              : null;
      if (renderObject is RenderBox &&
          renderObject.attached &&
          renderObject.hasSize) {
        final overlayRenderBox = _overlayRenderBox(context);
        if (overlayRenderBox == null) {
          return null;
        }
        final rect = MatrixUtils.transformRect(
          renderObject.getTransformTo(overlayRenderBox),
          Offset.zero & renderObject.size,
        );
        final offset = rect.topLeft;
        final size = rect.size;
        if (_isValidOffset(offset) && _isValidSize(size)) {
          targetOffset = offset;
          targetSize = size;
          hasTargetInfo = true;
        }
      }
    }

    final targetPointBuilder = param.targetPointBuilder;
    if (targetPointBuilder != null) {
      final targetPoint = targetPointBuilder(targetOffset, targetSize);
      if (!_isValidOffset(targetPoint)) {
        return null;
      }
      targetOffset = targetPoint;
    } else if (!hasTargetInfo) {
      return null;
    }

    final targetRect =
        param.targetRectBuilder?.call(targetOffset & targetSize) ??
        targetOffset & targetSize;
    return _isValidRect(targetRect) ? targetRect : null;
  }

  RenderBox? _overlayRenderBox(BuildContext context) {
    try {
      final renderObject = Overlay.of(context).context.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.attached &&
          renderObject.hasSize) {
        return renderObject;
      }
    } catch (_) {}
    return null;
  }

  bool _isValidOffset(Offset offset) {
    return offset.dx.isFinite && offset.dy.isFinite;
  }

  bool _isValidSize(Size size) {
    return size.width.isFinite && size.height.isFinite;
  }

  bool _isValidRect(Rect rect) {
    return rect.left.isFinite &&
        rect.top.isFinite &&
        rect.right.isFinite &&
        rect.bottom.isFinite &&
        rect.width.isFinite &&
        rect.height.isFinite;
  }
}

class AttachDialogWidgetController {
  _AttachDialogWidgetState? _state;

  void _bind(_AttachDialogWidgetState state) {
    _state = state;
  }

  void _unbind(_AttachDialogWidgetState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  Future<void> dismiss({OverlayCloseType closeType = OverlayCloseType.normal}) {
    return _state?.dismiss(closeType: closeType) ?? Future<void>.value();
  }
}

class _MaskIgnoreRectClipper extends CustomClipper<Path> {
  const _MaskIgnoreRectClipper(this.ignoreRect);

  final Rect ignoreRect;

  @override
  Path getClip(Size size) {
    final bounds = Offset.zero & size;
    final visibleMask = Path()..addRect(bounds);
    final clippedIgnoreRect = ignoreRect.intersect(bounds);
    if (clippedIgnoreRect.isEmpty) {
      return visibleMask;
    }

    final ignoredArea = Path()..addRect(clippedIgnoreRect);
    return Path.combine(PathOperation.difference, visibleMask, ignoredArea);
  }

  @override
  bool shouldReclip(covariant _MaskIgnoreRectClipper oldClipper) {
    return ignoreRect != oldClipper.ignoreRect;
  }
}
