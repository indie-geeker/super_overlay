import 'package:flutter/widgets.dart';

import 'view_utils.dart';

class SuperOverlayEntry extends OverlayEntry {
  SuperOverlayEntry({
    required super.builder,
    super.opaque,
    super.maintainState,
  });

  bool _removedByOwner = false;
  bool _disposedByOwner = false;

  @override
  void markNeedsBuild() {
    ViewUtils.addSafeUse(() {
      if (_removedByOwner || _disposedByOwner || !mounted) {
        return;
      }
      super.markNeedsBuild();
    });
  }

  @override
  void remove() {
    if (_removedByOwner) {
      return;
    }

    _removedByOwner = true;
    if (mounted) {
      super.remove();
      widgetsBinding.addPostFrameCallback((_) => _disposeOnce());
      return;
    }
    _disposeOnce();
  }

  void _disposeOnce() {
    if (_disposedByOwner) {
      return;
    }
    _disposedByOwner = true;
    super.dispose();
  }
}
