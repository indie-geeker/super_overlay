import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../data/animation_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/typedef.dart';
import '../kit/view_utils.dart';
import 'animation/fade_animation.dart';
import 'animation/mask_animation.dart';
import 'animation/scale_animation.dart';
import 'animation/slide_animation.dart';
import 'animation/size_animation.dart';
import 'helper/mask_event.dart';

class OverlayDialogWidget extends StatefulWidget {
  const OverlayDialogWidget({
    super.key,
    required this.child,
    required this.controller,
    required this.alignment,
    required this.usePenetrate,
    required this.useAnimation,
    required this.animationTime,
    required this.animationType,
    required this.nonAnimationTypes,
    required this.animationBuilder,
    required this.maskColor,
    required this.maskWidget,
    required this.maskTriggerType,
    required this.ignoreArea,
    required this.onMask,
  });

  final Widget child;
  final OverlayDialogWidgetController controller;
  final Alignment alignment;
  final bool usePenetrate;
  final bool useAnimation;
  final Duration animationTime;
  final AnimationType animationType;
  final List<NonAnimationType> nonAnimationTypes;
  final AnimationBuilder? animationBuilder;
  final Color maskColor;
  final Widget? maskWidget;
  final MaskTriggerType maskTriggerType;
  final Rect? ignoreArea;
  final VoidCallback onMask;

  @override
  State<OverlayDialogWidget> createState() => _OverlayDialogWidgetState();
}

class _OverlayDialogWidgetState extends State<OverlayDialogWidget>
    with TickerProviderStateMixin {
  late AnimationController _maskController;
  late AnimationController _bodyController;
  AnimationParam? _animationParam;

  @override
  void initState() {
    super.initState();
    _maskController = AnimationController(vsync: this);
    _bodyController = AnimationController(vsync: this);
    widget.controller._bind(this);
    _forward();
  }

  @override
  void didUpdateWidget(covariant OverlayDialogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller._bind(this);
    if (oldWidget.child != widget.child) {
      _forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: widget.ignoreArea?.left ?? 0,
        top: widget.ignoreArea?.top ?? 0,
        right: widget.ignoreArea?.right ?? 0,
        bottom: widget.ignoreArea?.bottom ?? 0,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MaskEvent(
            maskTriggerType: widget.maskTriggerType,
            onMask: widget.onMask,
            child: MaskAnimation(
              controller: _maskController,
              maskWidget: widget.maskWidget,
              maskColor: widget.maskColor,
              usePenetrate: widget.usePenetrate,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: widget.alignment,
              child: Material(
                type: MaterialType.transparency,
                child: _buildBodyAnimation(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _forward() {
    final duration = _openDuration;
    _maskController.duration = duration;
    _bodyController.duration = duration;
    _maskController.forward(from: 0);
    _bodyController.forward(from: 0);
    ViewUtils.addSafeUse(() => _animationParam?.onForward?.call());
  }

  Duration get _openDuration {
    if (!widget.useAnimation ||
        widget.nonAnimationTypes.contains(NonAnimationType.open)) {
      return Duration.zero;
    }
    return widget.animationTime;
  }

  Widget _buildBodyAnimation() {
    final child = widget.child;
    final animationBuilder = widget.animationBuilder;
    if (animationBuilder != null) {
      return animationBuilder(
        _bodyController,
        child,
        _animationParam = AnimationParam(
          alignment: widget.alignment,
          animationTime: widget.animationTime,
        ),
      );
    }

    return switch (widget.animationType) {
      AnimationType.fade => FadeAnimation(
        controller: _bodyController,
        child: child,
      ),
      AnimationType.scale => ScaleAnimation(
        controller: _bodyController,
        child: child,
      ),
      AnimationType.size => SizeAnimation(
        controller: _bodyController,
        alignment: widget.alignment,
        child: child,
      ),
      AnimationType.centerFadeOtherSlide =>
        widget.alignment == Alignment.center
            ? FadeAnimation(controller: _bodyController, child: child)
            : SlideAnimation(
                controller: _bodyController,
                alignment: widget.alignment,
                child: child,
              ),
      AnimationType.centerScaleOtherSlide =>
        widget.alignment == Alignment.center
            ? ScaleAnimation(controller: _bodyController, child: child)
            : SlideAnimation(
                controller: _bodyController,
                alignment: widget.alignment,
                child: child,
              ),
    };
  }

  Future<void> dismiss({
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) async {
    final duration = _closeDuration(closeType);
    _maskController.duration = duration;
    _bodyController.duration = duration;
    _maskController.reverse();
    _bodyController.reverse();
    _animationParam?.onDismiss?.call();
  }

  Duration _closeDuration(OverlayCloseType closeType) {
    if (!widget.useAnimation ||
        widget.nonAnimationTypes.contains(NonAnimationType.close) ||
        _hasCloseTypeSkip(closeType)) {
      return Duration.zero;
    }
    return widget.animationTime;
  }

  bool _hasCloseTypeSkip(OverlayCloseType closeType) {
    return switch (closeType) {
      OverlayCloseType.normal => false,
      OverlayCloseType.mask => widget.nonAnimationTypes.contains(
        NonAnimationType.maskClose,
      ),
      OverlayCloseType.route => widget.nonAnimationTypes.contains(
        NonAnimationType.routeClose,
      ),
      OverlayCloseType.back => widget.nonAnimationTypes.contains(
        NonAnimationType.backClose,
      ),
    };
  }

  @override
  void dispose() {
    _maskController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}

class OverlayDialogWidgetController {
  _OverlayDialogWidgetState? _state;

  void _bind(_OverlayDialogWidgetState state) {
    _state = state;
  }

  Future<void> dismiss({OverlayCloseType closeType = OverlayCloseType.normal}) {
    return _state?.dismiss(closeType: closeType) ?? Future<void>.value();
  }
}
