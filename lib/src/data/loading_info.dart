import '../config/enum_config.dart';
import '../kit/typedef.dart';
import 'overlay_info.dart';

class LoadingInfo {
  LoadingInfo({this.info, this.backType = BackType.normal, this.onBack});

  OverlayInfo<void>? info;
  BackType backType;
  SuperOverlayOnBack? onBack;
  DateTime? shownAt;
}
