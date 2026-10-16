import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Positions live toast entries without rebuilding their content or restarting
/// their timers/animations. Closing entries keep their space until removal.
class ToastStackLayout {
  final List<ToastStackEntry> _entries = [];
  bool _dirty = true;

  ToastStackEntry add(Alignment alignment) {
    final entry = ToastStackEntry._(this, alignment);
    _entries.add(entry);
    _markDirty();
    return entry;
  }

  void _markDirty() {
    _dirty = true;
    for (final entry in _entries) {
      entry._position?.markNeedsPaint();
      entry._position?.markNeedsSemanticsUpdate();
    }
  }

  void _updateOffsets() {
    if (!_dirty) return;
    _dirty = false;
    final originalBounds = <ToastStackEntry, Rect>{};
    final placed = <ToastStackEntry, Rect>{};
    for (final entry in _entries) {
      final bounds = entry._layoutBounds();
      if (bounds == null) continue;
      originalBounds[entry] = bounds;
      final upwards = entry._alignment.y > 0;
      // Only horizontally intersecting bodies compete for vertical space.
      // Walk in the stacking direction so moving past one obstacle cannot
      // move into another obstacle that has already been checked.
      final obstacles =
          placed.values
              .where(
                (rect) => bounds.left < rect.right && bounds.right > rect.left,
              )
              .toList()
            ..sort(
              (a, b) =>
                  upwards
                      ? b.bottom.compareTo(a.bottom)
                      : a.top.compareTo(b.top),
            );
      var positioned = bounds;
      for (final obstacle in obstacles) {
        if (positioned.top < obstacle.bottom + 8 &&
            positioned.bottom > obstacle.top - 8) {
          final top =
              upwards ? obstacle.top - bounds.height - 8 : obstacle.bottom + 8;
          positioned = bounds.shift(Offset(0, top - bounds.top));
        }
      }
      placed[entry] = positioned;
    }
    _fitInViewport(placed);
    for (final entry in placed.keys) {
      entry._offset = placed[entry]!.topLeft - originalBounds[entry]!.topLeft;
    }
  }

  void _fitInViewport(Map<ToastStackEntry, Rect> placed) {
    if (placed.isEmpty) return;
    final viewport = placed.keys.first._position!.usableViewport;
    // Horizontal overlap is transitive: moving any member of a connected
    // group must also move the bodies whose reserved space it depends on.
    final ordered =
        placed.keys.toList()
          ..sort((a, b) => placed[a]!.left.compareTo(placed[b]!.left));
    var group = <ToastStackEntry>[];
    var right = double.negativeInfinity;
    for (final entry in ordered) {
      final rect = placed[entry]!;
      if (group.isNotEmpty && rect.left >= right) {
        _fitGroup(group, placed, viewport);
        group = [];
        right = double.negativeInfinity;
      }
      group.add(entry);
      right = math.max(right, rect.right);
    }
    _fitGroup(group, placed, viewport);
  }

  void _fitGroup(
    List<ToastStackEntry> group,
    Map<ToastStackEntry, Rect> placed,
    Rect viewport,
  ) {
    Rect extent() => group
        .skip(1)
        .fold(
          placed[group.first]!,
          (bounds, entry) => bounds.expandToInclude(placed[entry]!),
        );
    var bounds = extent();
    if (bounds.top >= viewport.top && bounds.bottom <= viewport.bottom) return;

    if (bounds.height > viewport.height) {
      // Remove empty vertical gaps before translating. Side-by-side bodies
      // can still share a row; content and animation widgets are untouched.
      final original = {for (final entry in group) entry: placed[entry]!};
      final ordered =
          group.toList()
            ..sort((a, b) => original[a]!.top.compareTo(original[b]!.top));
      final compacted = <Rect>[];
      for (final entry in ordered) {
        final body = original[entry]!;
        var top = viewport.top;
        for (final preceding in compacted) {
          if (body.left < preceding.right && body.right > preceding.left) {
            top = math.max(top, preceding.bottom + 8);
          }
        }
        final positioned = body.shift(Offset(0, top - body.top));
        placed[entry] = positioned;
        compacted.add(positioned);
      }
      bounds = extent();
      if (bounds.height > viewport.height) {
        // If this stacking order still cannot fit, preserve its overflow
        // behavior rather than overlap, resize or discard toast content.
        placed.addAll(original);
        return;
      }
    }
    final shift = 0.0.clamp(
      viewport.top - bounds.top,
      viewport.bottom - bounds.bottom,
    );
    for (final entry in group) {
      placed[entry] = placed[entry]!.shift(Offset(0, shift));
    }
  }
}

class ToastStackEntry {
  ToastStackEntry._(this._layout, this._alignment);

  final ToastStackLayout _layout;
  Alignment _alignment;
  Offset _offset = Offset.zero;
  _RenderToastStackPosition? _position;
  _RenderToastStackMeasure? _body;

  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    _layout._markDirty();
  }

  Offset get _paintOffset {
    _layout._updateOffsets();
    return _offset;
  }

  Rect? _layoutBounds() {
    final body = _body;
    final position = _position;
    if (body == null ||
        position == null ||
        !body.attached ||
        !body.hasSize ||
        !position.hasSize) {
      return null;
    }
    // Reserve the fully laid-out content, ignoring paint-only entrance/exit
    // transforms. Safe-area and keyboard layout offsets remain included.
    var offset = Offset.zero;
    RenderObject? node = body;
    while (node != null && !identical(node, position)) {
      final data = node.parentData;
      if (data is BoxParentData) offset += data.offset;
      node = node.parent;
    }
    return node == null ? null : body.stackBounds.shift(offset);
  }

  void remove() {
    if (_layout._entries.remove(this)) _layout._markDirty();
  }
}

/// Translate the full entry so displaced content remains hit-testable, even
/// outside the body's original layout box. Semantics uses the same transform.
class ToastStackPosition extends SingleChildRenderObjectWidget {
  ToastStackPosition({required this.entry, required super.child})
    : super(key: ObjectKey(entry));

  final ToastStackEntry entry;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderToastStackPosition(entry, _viewportInsets(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderToastStackPosition)
        .viewportInsets = _viewportInsets(context);
  }

  static EdgeInsets _viewportInsets(BuildContext context) {
    final media = MediaQuery.of(context);
    // Match OverlayDialogWidget's SafeArea and keyboard positioning contract.
    return EdgeInsets.fromLTRB(
      math.max(media.padding.left, media.viewPadding.left),
      math.max(media.padding.top, media.viewPadding.top),
      math.max(media.padding.right, media.viewPadding.right),
      media.padding.bottom + media.viewInsets.bottom,
    );
  }
}

class _RenderToastStackPosition extends RenderProxyBox {
  _RenderToastStackPosition(this.entry, this._viewportInsets) {
    entry._position = this;
  }

  final ToastStackEntry entry;
  EdgeInsets _viewportInsets;

  set viewportInsets(EdgeInsets value) {
    if (_viewportInsets == value) return;
    _viewportInsets = value;
    entry._layout._markDirty();
  }

  Rect get usableViewport {
    final left = _viewportInsets.left.clamp(0.0, size.width);
    final top = _viewportInsets.top.clamp(0.0, size.height);
    return Rect.fromLTRB(
      left,
      top,
      (size.width - _viewportInsets.right).clamp(left, size.width),
      (size.height - _viewportInsets.bottom).clamp(top, size.height),
    );
  }

  @override
  void performLayout() {
    super.performLayout();
    entry._layout._markDirty();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset + entry._paintOffset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: entry._paintOffset,
        position: position,
        hitTest:
            (result, position) =>
                super.hitTestChildren(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    final offset = entry._paintOffset;
    transform.multiply(Matrix4.translationValues(offset.dx, offset.dy, 0));
  }

  @override
  void dispose() {
    entry._position = null;
    super.dispose();
  }
}

class ToastStackMeasure extends SingleChildRenderObjectWidget {
  ToastStackMeasure({
    required this.entry,
    this.outerMargin = EdgeInsets.zero,
    required super.child,
  }) : super(key: ObjectKey(entry));

  final ToastStackEntry entry;
  final EdgeInsets outerMargin;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderToastStackMeasure(entry, outerMargin);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderToastStackMeasure).outerMargin = outerMargin;
  }
}

class _RenderToastStackMeasure extends RenderProxyBox {
  _RenderToastStackMeasure(this.entry, this._outerMargin) {
    entry._body = this;
  }

  final ToastStackEntry entry;
  EdgeInsets _outerMargin;

  set outerMargin(EdgeInsets value) {
    if (_outerMargin == value) return;
    _outerMargin = value;
    entry._layout._markDirty();
  }

  Rect get stackBounds {
    final left = _outerMargin.left.clamp(0.0, size.width);
    final top = _outerMargin.top.clamp(0.0, size.height);
    return Rect.fromLTRB(
      left,
      top,
      (size.width - _outerMargin.right).clamp(left, size.width),
      (size.height - _outerMargin.bottom).clamp(top, size.height),
    );
  }

  @override
  void performLayout() {
    super.performLayout();
    entry._layout._markDirty();
  }

  @override
  void dispose() {
    entry._body = null;
    super.dispose();
  }
}
