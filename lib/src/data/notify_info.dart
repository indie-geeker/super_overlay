import 'dart:async';

import '../config/enum_config.dart';
import '../kit/typedef.dart';
import 'overlay_info.dart';

class NotifyInfo {
  NotifyInfo({required this.info, required this.backType, this.onBack});

  final OverlayInfo<void> info;
  BackType backType;
  SuperOverlayOnBack? onBack;
  Timer? displayTimer;
}
