import 'dart:async';

import 'package:flutter/material.dart';

import '../data/animation_param.dart';

class PopupLayoutInfo {
  const PopupLayoutInfo({
    required this.targetOffset,
    required this.targetSize,
    required this.popupOffset,
    required this.popupSize,
  });

  final Offset targetOffset;
  final Size targetSize;
  final Offset popupOffset;
  final Size popupSize;

  @override
  bool operator ==(Object other) {
    return other is PopupLayoutInfo &&
        other.targetOffset == targetOffset &&
        other.targetSize == targetSize &&
        other.popupOffset == popupOffset &&
        other.popupSize == popupSize;
  }

  @override
  int get hashCode {
    return Object.hash(targetOffset, targetSize, popupOffset, popupSize);
  }
}

class PopupAdjustment {
  const PopupAdjustment({this.alignment, this.builder});

  final Alignment? alignment;
  final WidgetBuilder? builder;
}

typedef FutureVoidCallback = Future<void> Function();
typedef SuperOverlayOnBack = FutureOr<bool> Function();
typedef SuperOverlayToastBuilder = Widget Function(String message);
typedef SuperOverlayLoadingBuilder = Widget Function(String message);

typedef AnimationBuilder =
    Widget Function(
      AnimationController controller,
      Widget child,
      AnimationParam animationParam,
    );

typedef PopupTargetRectBuilder = Rect Function(Rect targetRect);

typedef PopupTargetPointBuilder =
    Offset Function(Offset targetOffset, Size targetSize);

typedef PopupReplacementBuilder = Widget Function(PopupLayoutInfo info);
typedef PopupAdjustmentBuilder = PopupAdjustment Function(PopupLayoutInfo info);
typedef PopupScaleOriginBuilder = Offset Function(Size popupSize);
