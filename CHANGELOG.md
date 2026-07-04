## 0.2.0

* Breaking: replace the fluent public API with command services:
  `SuperOverlay.dialog`, `SuperOverlay.loading`, `SuperOverlay.popup`,
  `SuperOverlay.notify`, `SuperOverlay.toast`, `SuperOverlay.close`, and
  `SuperOverlay.exists`.
* Add typed command contracts: `OverlayHandle`, `OverlayDialogOptions`,
  `OverlayPopupOptions`, `OverlayLoadingOptions`, `OverlayToastOptions`,
  `OverlayNotifyOptions`, `OverlayStrategy`, `OverlayBackBehavior`,
  `OverlayCloseTarget`, and `OverlaySurface`.
* Hide obsolete public fluent builders, mutable global config types, internal
  controller types, and the old root-init widget from the package entrypoint.
* Harden lifecycle behavior for route replacement, route removal, widget-bound
  overlays, invalid popup target geometry, and idempotent handle close.
* Update the example app to production-style command API flows, including
  loading plus page-owned empty/error states.

## 0.1.2

* Relax Dart SDK constraint to >=3.7.0 <4.0.0.
* Relax Flutter minimum version to >=3.29.0.
* Align example and lint constraints with the lowered SDK floor.

## 0.1.1

* Corrected pub.dev metadata links to the `indie-geeker/super_overlay` GitHub
  repository.
* Removed internal `doc/` materials from the published package and tracked
  repository contents.

## 0.1.0

* Breaking rewrite from route-based dialogs to a self-managed `OverlayEntry`
  runtime.
* Added the root overlay host and navigator observer initialization path.
* Added custom dialogs, loading indicators, toasts, popups, highlighted popups,
  and notifications.
* Added popup geometry features: explicit target points, targetless positioning,
  edge clamping, alignment modes, replacement and adjustment hooks, scale-origin
  hooks, and mask ignore areas.
* Added init-level default builders for loading, toast, and notification
  surfaces.
* Added route binding, widget binding, and back-button handling.
* Fixed permanent overlay cleanup semantics.
* Excluded IDE metadata from the pub publish archive.
* Removed the legacy navigator-key API and old `content:`/`msg:` call shapes.
