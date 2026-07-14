## 0.3.0

* Add owned `SuperOverlayIntegration` objects, disposable scoped Navigator
  observers, and `SuperOverlay.of(context)` for exact nested-route ownership.
* Support generic nested Navigators, `go_router` `ShellRoute`, and the default
  `StatefulShellRoute.indexedStack` branch lifecycle without adding a runtime
  dependency on `go_router`.
* Make same-frame whole-root replacement generation-safe and fail fast for
  simultaneous live app hosts or competing views.
* Coordinate `dismiss`, `block`, and `passThrough` through route `PopEntry`
  state for predictive back, nested routes, and application `PopScope`/`Form`
  interoperability.
* Add modal focus trapping, focus restoration, background semantic blocking,
  semantic route/barrier labels, Escape handling, and live-region feedback.
* Track moving popup anchors in root Overlay coordinates with per-entry
  invalidation, a 0.5 logical-pixel tolerance, and fail-closed target cleanup.
* Expand the runnable example with typed dialog results, all public back
  behaviors, nested Navigator suspension/resume, and `refreshActive` versus
  handle-owned `refresh()`.
* Add compile-backed README snippets, support tiers, a capability coverage
  matrix, repository contracts, and a release checklist.
* Make `OverlayHandle.visible` reflect the first rendered frame across dialog,
  loading, popup, toast, and notification surfaces. Requests that terminate
  before rendering now fail `visible` with `StateError` while still settling
  `closed`.
* Serialize same-tag `replaceExisting` commands and preserve the current overlay
  when a queued replacement is canceled.
* Reject `keepExisting` calls that reuse a dialog or popup tag with an
  incompatible generic result type.
* Treat `OverlayPopupOptions.maskIgnoreArea` as an exact rectangular mask
  cutout, and automatically close popups whose target context or geometry is
  invalid.
* Reset init-level builders and settle active handles when the overlay host is
  disposed or replaced.
* Reorganize the example around real development scenarios, including Toast
  policies, one-at-a-time notifications, anchored dropdown and upward menus,
  route/widget lifecycle cases, and a scoped Overlay Control Lab.
* Keep custom notifications below display cutouts and add simulated safe-area
  regression coverage for all notification types.
* Wire Toast command handles to their content refresh controller so
  `OverlayHandle.refresh()` rebuilds an active Toast without affecting other
  Toast owners.

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
