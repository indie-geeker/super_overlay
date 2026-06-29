import 'attach_dialog_config.dart';
import 'custom_dialog_config.dart';
import 'loading_config.dart';
import 'notify_config.dart';
import 'toast_config.dart';

class OverlayConfig {
  OverlayConfig({
    CustomDialogConfig? custom,
    AttachDialogConfig? attach,
    LoadingConfig? loading,
    ToastConfig? toast,
    NotifyConfig? notify,
  }) : custom = custom ?? const CustomDialogConfig(),
       attach = attach ?? const AttachDialogConfig(),
       loading = loading ?? const LoadingConfig(),
       toast = toast ?? const ToastConfig(),
       notify = notify ?? const NotifyConfig();

  CustomDialogConfig custom;
  AttachDialogConfig attach;
  LoadingConfig loading;
  ToastConfig toast;
  NotifyConfig notify;
}
