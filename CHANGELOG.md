## 0.1.0-dev.1

* Breaking rewrite from route-based dialogs to a self-managed `OverlayEntry`
  runtime.
* Added `SuperOverlayInit.init()` and `SuperOverlayInit.observer` as the only
  initialization path.
* Added custom, loading, toast, popup, highlighted popup, and notify overlays.
* Added route binding, widget binding, and `BackType` handling.
* Removed the legacy navigator-key API and old `content:`/`msg:` call shapes.
