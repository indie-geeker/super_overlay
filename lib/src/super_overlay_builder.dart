import 'dart:async';
import 'package:flutter/material.dart';
import 'super_overlay_core.dart';
import 'highlight_mask.dart';

/// Alignment for Popup
enum PopupAlignment {
  bottomLeft,
  bottomRight,
  bottomCenter,
  topLeft,
  topRight,
  topCenter,
}

class SuperOverlayBuilder {
  final Widget content;
  BuildContext? _context;
  
  Color? _maskColor;
  bool _dismissible = true;
  Duration? _animationDuration;
  Alignment _alignment = Alignment.center;
  
  String? _tag;
  bool? _debounce;
  
  BuildContext? _highlightContext;
  EdgeInsets _highlightPadding = EdgeInsets.zero;
  BorderRadius _highlightBorderRadius = BorderRadius.zero;

  SuperOverlayBuilder({required this.content, BuildContext? context}) {
    _context = context;
  }

  SuperOverlayBuilder withMask({
    Color? color,
    bool dismissible = true,
  }) {
    _maskColor = color;
    _dismissible = dismissible;
    return this;
  }

  SuperOverlayBuilder withAnimation(Duration duration) {
    _animationDuration = duration;
    return this;
  }

  SuperOverlayBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }
  
  SuperOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }
  
  SuperOverlayBuilder withDebounce(bool enable) {
    _debounce = enable;
    return this;
  }
  
  SuperOverlayBuilder withHighlight(
    BuildContext targetContext, {
    EdgeInsets padding = EdgeInsets.zero,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    _highlightContext = targetContext;
    _highlightPadding = padding;
    _highlightBorderRadius = borderRadius;
    return this;
  }

  Future<T?> fire<T>() {
    final BuildContext? context = _context ?? SuperOverlay.navigatorKey.currentContext;
    if (context == null) {
      throw StateError(
        'SuperOverlay Error: BuildContext is null. '
        'Did you forget to set SuperOverlay.navigatorKey in your MaterialApp?',
      );
    }
    
    if (!SuperOverlay.checkDebounce(_debounce)) {
      return Future.value(null);
    }
    
    Rect? highlightRect;
    if (_highlightContext != null) {
      final box = _highlightContext!.findRenderObject() as RenderBox?;
      if (box != null) {
        highlightRect = box.localToGlobal(Offset.zero) & box.size;
      }
    }

    if (highlightRect != null) {
      final overlayState = Navigator.of(context).overlay;
      if (overlayState == null) return Future.value(null);
      
      OverlayEntry? entry;
      final completer = Completer<T?>();
      
      entry = OverlayEntry(
        builder: (ctx) {
          Widget page = SafeArea(
            child: Align(
              alignment: _alignment,
              child: content,
            ),
          );
          
          return TweenAnimationBuilder<double>(
            duration: _animationDuration ?? SuperOverlay.config.defaultAnimationDuration,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Stack(
                  children: [
                    HighlightMask(
                      targetRect: highlightRect!,
                      maskColor: _maskColor ?? SuperOverlay.config.defaultMaskColor,
                      padding: _highlightPadding,
                      borderRadius: _highlightBorderRadius,
                      onDismiss: _dismissible ? () {
                        if (entry?.mounted == true) entry?.remove();
                        if (!completer.isCompleted) completer.complete(null);
                      } : null,
                    ),
                    page,
                  ],
                ),
              );
            },
          );
        },
      );
      
      overlayState.insert(entry);
      
      // Basic tag support for highlight overlays (won't support popping natively)
      // For a more robust solution, _activeRoutes could store a custom object
      // with a dismiss() callback instead of just Route.
      return completer.future;
    }

    final route = PageRouteBuilder<T>(
      opaque: false,
      barrierColor: _maskColor ?? SuperOverlay.config.defaultMaskColor,
      barrierDismissible: _dismissible,
      transitionDuration: _animationDuration ?? SuperOverlay.config.defaultAnimationDuration,
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: _alignment,
            child: content,
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
    
    if (_tag != null) {
      SuperOverlay.registerRoute(_tag!, route);
    }

    return Navigator.of(context).push<T>(route);
  }
}

class ToastBuilder {
  final String msg;
  BuildContext? _context;
  Duration? _duration;
  Alignment _alignment = Alignment.bottomCenter;
  bool? _debounce;

  ToastBuilder({required this.msg, BuildContext? context}) {
    _context = context;
  }

  ToastBuilder withDuration(Duration duration) {
    _duration = duration;
    return this;
  }
  
  ToastBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }
  
  ToastBuilder withDebounce(bool enable) {
    _debounce = enable;
    return this;
  }

  void fire() {
    final BuildContext? context = _context ?? SuperOverlay.navigatorKey.currentContext;
    if (context == null) return;
    
    if (!SuperOverlay.checkDebounce(_debounce)) {
      return;
    }
    
    final overlayState = Navigator.of(context).overlay;
    if (overlayState == null) return;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: _alignment,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60.0, top: 60.0),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 20),
                        child: child,
                      ),
                    );
                  },
                  child: SuperOverlay.config.defaultToastBuilder(context, msg),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(entry);

    Timer(_duration ?? SuperOverlay.config.defaultToastDuration, () {
      if (entry != null && entry!.mounted) {
        entry!.remove();
      }
    });
  }
}

class PopupBuilder {
  final Widget content;
  final BuildContext targetContext;
  BuildContext? _context;
  
  Color? _maskColor = Colors.transparent;
  bool _dismissible = true;
  PopupAlignment _alignment = PopupAlignment.bottomLeft;
  Duration? _animationDuration;
  
  String? _tag;
  bool? _debounce;

  PopupBuilder({required this.content, required this.targetContext, BuildContext? context}) {
    _context = context;
  }

  PopupBuilder withAlignment(PopupAlignment alignment) {
    _alignment = alignment;
    return this;
  }
  
  PopupBuilder withMask({
    Color? color,
    bool dismissible = true,
  }) {
    _maskColor = color;
    _dismissible = dismissible;
    return this;
  }
  
  PopupBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }
  
  PopupBuilder withDebounce(bool enable) {
    _debounce = enable;
    return this;
  }

  Future<T?> fire<T>() {
    final BuildContext? context = _context ?? SuperOverlay.navigatorKey.currentContext;
    if (context == null) {
      throw StateError('SuperOverlay Error: BuildContext is null.');
    }
    
    if (!SuperOverlay.checkDebounce(_debounce)) {
      return Future.value(null);
    }

    final RenderBox? targetBox = targetContext.findRenderObject() as RenderBox?;
    if (targetBox == null) return Future.value(null);

    final offset = targetBox.localToGlobal(Offset.zero);
    final size = targetBox.size;

    final route = PageRouteBuilder<T>(
      opaque: false,
      barrierColor: _maskColor ?? Colors.transparent,
      barrierDismissible: _dismissible,
      transitionDuration: _animationDuration ?? SuperOverlay.config.defaultAnimationDuration,
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
        return CustomSingleChildLayout(
          delegate: _PopupLayoutDelegate(
            targetOffset: offset,
            targetSize: size,
            alignment: _alignment,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: content,
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
    
    if (_tag != null) {
      SuperOverlay.registerRoute(_tag!, route);
    }

    return Navigator.of(context).push<T>(route);
  }
}

class _PopupLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset targetOffset;
  final Size targetSize;
  final PopupAlignment alignment;

  _PopupLayoutDelegate({
    required this.targetOffset,
    required this.targetSize,
    required this.alignment,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = 0;
    double y = 0;

    switch (alignment) {
      case PopupAlignment.bottomLeft:
        x = targetOffset.dx;
        y = targetOffset.dy + targetSize.height;
        break;
      case PopupAlignment.bottomRight:
        x = targetOffset.dx + targetSize.width - childSize.width;
        y = targetOffset.dy + targetSize.height;
        break;
      case PopupAlignment.bottomCenter:
        x = targetOffset.dx + (targetSize.width - childSize.width) / 2;
        y = targetOffset.dy + targetSize.height;
        break;
      case PopupAlignment.topLeft:
        x = targetOffset.dx;
        y = targetOffset.dy - childSize.height;
        break;
      case PopupAlignment.topRight:
        x = targetOffset.dx + targetSize.width - childSize.width;
        y = targetOffset.dy - childSize.height;
        break;
      case PopupAlignment.topCenter:
        x = targetOffset.dx + (targetSize.width - childSize.width) / 2;
        y = targetOffset.dy - childSize.height;
        break;
    }
    
    if (x < 0) x = 0;
    if (x + childSize.width > size.width) x = size.width - childSize.width;
    if (y < 0) y = 0;
    if (y + childSize.height > size.height) y = size.height - childSize.height;

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _PopupLayoutDelegate oldDelegate) {
    return targetOffset != oldDelegate.targetOffset ||
           targetSize != oldDelegate.targetSize ||
           alignment != oldDelegate.alignment;
  }
}
