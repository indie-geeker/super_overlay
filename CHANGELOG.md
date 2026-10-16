## 0.4.0

Release date: 2026-10-16.

* Bind mask and delayed Popup target-failure callbacks to the original instance
  and presentation, including Loading replacement/close handoffs and colliding
  business tags. Keep Toast callbacks bound to their own lane presentation;
  target automatic expiry and route/widget cleanup by exact record, including
  internal repeated identity tags. Preserve explicit global tag-based cleanup.
* Cancel widget-owned Dialog and anchored Popup commands before replacement
  cleanup or activation when their owner unmounts; preserve existing overlays,
  reject `visible` without building stale content and settle `closed` normally
  with the original close result.
* Forward a custom dispatcher's final key value when it intercepts without
  invoking the overlay bridge, including native child/ancestor shortcuts that
  create or replace consuming overlays during the dispatch.
* Keep consumed Escape events inside native shortcut boundaries even when
  dispatchers rewrite results or reenter before/after delegation; isolate each
  key's observation and preserve application/programmatic return values.
* Bind Loading back callbacks to the selected lifecycle and join an existing
  close without cancelling deferred replacements; preserve explicit cleanup.
* Cancel queued route-owned Dialog/Popup replacements normally when their route
  or observer disappears, while retaining synchronous invalid-owner errors.
* Bound continuous Toast refresh metadata when handles are discarded, while
  preserving historical and pre-activation close observations.
* Release Dialog, Popup and notification content captures even when their
  closed handles remain retained.
* Isolate Loading handle identity from business tags for active, minimum-time
  and deferred commands; preserve global tag-based cleanup.
* **Breaking:** Dialog and Popup builders now receive `(context, overlay)`;
  close content through that typed handle without a captured `late final`.
  Rename `OverlayCloseTarget.topMost` to `highestPriority`. Scoped facades now
  expose only Dialog/Popup; use global `SuperOverlay` for feedback and cleanup.
  No compatibility aliases are provided.
* Release superseded Toast builders and captured values during continuous
  `refreshActive`, while historical handles still await the shared lane close.
* Start Loading's minimum visible interval after its first rendered frame;
  preserve independent replacement timing and immediate host-teardown cleanup.
* Forward application dismissal Actions with the actual invocation context,
  custom dispatcher and key result, without repeating local fallback dispatch.
* Add VM-GC retention and first-frame timing regressions, and document native
  menu/text-input Escape limitations while retaining Flutter 3.29 compatibility.
* Fall back to overlay or application Escape behavior when focused content
  leaves the key unhandled, including disabled actions in Flutter 3.29 menus.
  Preserve content action results, context and modifier-key behavior.
* Keep pop gates and global Dialog/Popup ownership on Navigator's actual current
  route when declarative Pages are inserted, replaced or removed below it.
* Let focused text input dismiss its selection toolbar before Escape applies
  the overlay back policy, preserving application shortcut pass-through.
* Settle first-frame visibility after route suspension/resume without rebuilding
  retained content; keep close-before-resume visibility rejection intact.
* Resolve declarative page order beneath a stable top PopupRoute, preserving
  each page's imperative route group across reordering.
* Bridge text-input `DismissIntent` to consuming overlays or application Actions,
  with a safe no-op when every overlay passes through and no app handler exists.
* Capture all surface close targets before waiting for Loading or animations;
  keep later owners outside global cleanup and tagged Toast close snapshots.
* Keep route-owned Dialog/Popup presentation in sync when existing Navigator
  pages are reordered, including state restoration and Flutter PopupRoutes.
* Forward Escape from focused `passThrough` overlays to the next consuming
  overlay; leave the key with the app when no overlay consumes it.
* Make same-frame Toast refresh insertion idempotent and cancel deferred
  insertion when the Toast has already been removed.
* Reflow concurrent Toasts by measured content bounds after removal, refresh
  and keyboard layout, preserving state and close timers. Keep default screen
  margins out of inter-toast spacing and avoid collisions across alignments.
* Keep fitting Toast stacks inside safe-area and keyboard bounds after
  collision reflow, compacting empty gaps without rebuilding their content.
* Reject initially invalid mounted Popup anchors before completing `visible`,
  while preserving partially clipped anchors and targetless point placement.
* Fix stacked `passThrough` dialogs/popups by sharing consuming-back target
  selection between the route PopEntry gate and event dispatch.
* Make bulk Dialog/Popup/notification close await matching in-flight closes,
  including animations, without overriding the first result.
* Add `loading.run()` with automatic cleanup, independent overlapping tasks,
  typed task results and preservation of business errors.
* Build runtime parameters directly from options and remove private fluent
  builders. Move compiled quick-start examples before advanced routing docs.

* Polish example colors, spacing and shared controls; simplify the header and
  bound desktop content width while reusing the theme in teaching entries.
* Isolate stateless anchor geometry and once-only dismissal coordination while
  preserving generation ownership, typed results and route suspension.
* Add dynamic overlay layout and repeated resource-cleanup regressions, global
  notification refresh and retained-resource teaching examples, and a repeatable
  profile workload without changing public diagnostic APIs.
* Share local and CI verification through an isolated Dart runner with retained
  failure logs, minimum/modern-router suites and a single seeded coverage run.
* Keep root and nested Navigator ownership separate when go_router 18 forwards
  shell events to root observers; test 14.8.1 and 18.0.2 independently.
* Close widget-bound dialogs and popups when their target unmounts during route
  suspension, including before the first visible frame.
* Rebuild global NotifyStyle factories on handle.refresh and avoid invoking
  overridden or unused factories.
* Expose explicit modal semantics labels as route names while preserving names
  provided by content when no label is supplied.
* Adapt the example notification controls to large system text and add a
  minimal integration example with typed confirmation and loading cleanup.
* Clarify published release status, verified routing combinations, and explicit
  propagation of local inherited values.

## 0.3.1

* Preserve already-rendered dialog/popup state during route suspension while
  disabling hidden focus, semantics, hit testing, and tickers.
* Fix Loading and notification handle refresh, and honor explicit null
  notification durations as persistent notifications.
* Constrain popups to safe-area/keyboard bounds with automatic edge flipping;
  update Toast layout reactively when the keyboard opens, resizes, or closes.
* Capture scoped inherited themes for dialog and popup content, including
  replacement and adjustment builders.
* Keep Flutter 3.29-compatible size transitions without new-SDK analysis
  failures and allow recorded device evidence to pass repository validation.
* Keep popup placement stable throughout reveal animations and base Toast slide
  distance on content size when the keyboard is visible.

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
  Partially clipped mounted anchors remain active until they fully leave the
  Overlay viewport.
* Expand the runnable example with typed dialog results, all public back
  behaviors, nested Navigator suspension/resume, and `refreshActive` versus
  handle-owned `refresh()`.
* Add compile-backed README snippets, support tiers, a capability coverage
  matrix, repository contracts, a release checklist, and complete English and
  Simplified Chinese README editions.
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
