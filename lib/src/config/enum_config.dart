enum OverlayType { custom, attach, notify, loading, toast }

enum DismissStatus {
  auto,
  toast,
  allToast,
  loading,
  custom,
  attach,
  dialog,
  notify,
  allCustom,
  allAttach,
  allDialog,
  allNotify,
}

enum ToastDisplayType { normal, last, onlyRefresh, multi }

enum AnimationType {
  fade,
  scale,
  size,
  centerFadeOtherSlide,
  centerScaleOtherSlide,
}

enum MaskTriggerType { down, move, up }

enum NonAnimationType {
  open,
  close,
  routeClose,
  maskClose,
  backClose,
  highlightMask,
}

enum PopupAlignmentMode { inside, center, outside }

enum AwaitCompletion { dismiss, appear, none }

enum BackType { normal, block, ignore }

enum NotifyType { success, failure, warning, error, alert }
