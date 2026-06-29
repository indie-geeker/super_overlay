import 'dart:async';

import 'package:flutter/material.dart';

import '../data/animation_param.dart';
import '../data/attach_model.dart';

typedef FutureVoidCallback = Future<void> Function();
typedef SuperOverlayOnBack = FutureOr<bool> Function();

typedef AnimationBuilder =
    Widget Function(
      AnimationController controller,
      Widget child,
      AnimationParam animationParam,
    );

typedef AttachTargetBuilder =
    Offset Function(Offset targetOffset, Size targetSize);
typedef AttachReplaceBuilder =
    Widget Function(
      Offset targetOffset,
      Size targetSize,
      Offset selfOffset,
      Size selfSize,
    );
typedef AttachAdjustBuilder =
    AttachAdjustParam Function(AttachParam attachParam);
typedef AttachScalePointBuilder = Offset Function(Size selfSize);
typedef AttachHighlightBuilder =
    Positioned Function(Offset targetOffset, Size targetSize);
