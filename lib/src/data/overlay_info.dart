import 'dart:async';

import '../config/enum_config.dart';
import '../kit/super_overlay_entry.dart';

class OverlayInfo<T> {
  OverlayInfo({
    required this.type,
    required this.entry,
    required this.completer,
    this.tag,
    this.permanent = false,
  });

  final OverlayType type;
  final SuperOverlayEntry entry;
  final Completer<T?> completer;
  String? tag;
  bool permanent;
  Timer? displayTimer;
}
