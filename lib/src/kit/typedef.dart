import 'dart:async';

import 'package:flutter/material.dart';

import '../data/animation_param.dart';

typedef FutureVoidCallback = Future<void> Function();
typedef SuperOverlayOnBack = FutureOr<bool> Function();

typedef AnimationBuilder =
    Widget Function(
      AnimationController controller,
      Widget child,
      AnimationParam animationParam,
    );

typedef PopupTargetRectBuilder = Rect Function(Rect targetRect);
