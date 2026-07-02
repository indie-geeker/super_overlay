<!--
 * @Author: wen indiegeeker@gmail.com
 * @Date: 2026-06-30 23:15:10
 * @LastEditors: wen indiegeeker@gmail.com
 * @LastEditTime: 2026-07-02 00:36:46
 * @Description: 
-->
## 0.1.1

* Corrected pub.dev metadata links to the `indie-geeker/super_overlay` GitHub
  repository.
* Removed internal `doc/` materials from the published package and tracked
  repository contents.

## 0.1.0

* Breaking rewrite from route-based dialogs to a self-managed `OverlayEntry`
  runtime.
* Added `SuperOverlayInit.init()` and `SuperOverlayInit.observer` as the only
  initialization path.
* Added custom, loading, toast, popup, highlighted popup, and notify overlays.
* Added popup/attach parity features: explicit target points, targetless
  positioning, edge clamping, alignment modes, replacement and adjustment
  hooks, scale-origin hooks, and mask ignore areas.
* Added init-level default builders for loading, toast, and notify surfaces.
* Added explicit `AwaitCompletion` semantics for `fire()` futures.
* Exported the intended consumer API from `package:super_overlay/super_overlay.dart`,
  including configuration types, public enums, `SuperOverlayController`,
  `AnimationParam`, popup geometry types, and default feedback builder types.
* Added route binding, widget binding, and `BackType` handling.
* Fixed permanent overlay dismiss semantics so all-dialog cleanup skips permanent
  entries instead of hanging.
* Excluded IDE metadata from the pub publish archive.
* Removed the legacy navigator-key API and old `content:`/`msg:` call shapes.
* Removed unused internal builder re-export files and legacy info data holders
  that were not part of the public API.
