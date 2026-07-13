# SuperOverlay Commercial-Readiness And Navigation Design

**Status:** Approved design direction

**Date:** 2026-07-13

## Context

SuperOverlay already has a strong command-oriented API, a self-managed
`OverlayEntry` runtime, more than 90% aggregate line coverage, a scenario-based
example, and package publication checks. The remaining gap is not feature
count. It is whether lifecycle, navigation, accessibility, and release
contracts remain correct in real application structures rather than only in
the current happy-path test order.

The review confirmed four release-blocking runtime risks:

1. A cold-start system back event can pop the page before dismissing the
   overlay. The complete test suite passes because a process-global observer is
   registered by an earlier test; the same test fails when run alone.
2. Manually closing the active queued Toast can leave the queue permanently
   stalled.
3. Replacing the root host has no owner or generation check, so an old host can
   dispose the new host's runtime and default builders.
4. Modal overlays do not yet provide a focus trap, focus restoration, modal
   semantics, or a keyboard Escape contract.

The review also confirmed important P2 gaps: route ownership is global and
therefore cannot model nested Navigators, anchored popups do not follow a
moving target, and loading `close()` can complete before a configured minimum
visible duration actually ends.

This design keeps the proven self-managed `OverlayEntry` architecture and
hardens the boundaries around it. It does not convert dialogs into routes and
does not add a package-owned `Navigator`.

## Goals

- Make the default single-root integration safe for ordinary commercial apps.
- Support `ShellRoute`, the default `StatefulShellRoute.indexedStack`, and
  ordinary nested Navigator route ownership without making every command
  require a context.
- Preserve the current root-level `SuperOverlay.*` API as the simple default.
- Make root host replacement deterministic and stale-owner safe.
- Fail early for unsupported simultaneous root hosts instead of silently
  routing commands to the wrong app or desktop window.
- Make back, Toast queue, loading close, popup anchor, focus, semantics, and
  handle lifecycle behavior independently testable.
- Give the example and README enough runnable evidence to teach the core
  contracts, including typed dialog results and nested navigation.
- Define an auditable automated and manual release gate.

## Non-Goals

- Multiple simultaneously active `MaterialApp` roots in one Dart isolate.
- Routing one static `SuperOverlay.*` call to an arbitrary desktop window.
- A cross-isolate or cross-engine overlay registry.
- Replacing Flutter's Router, Navigator, or back-button dispatcher.
- Turning every popup target into a required `CompositedTransformTarget`.
- Preserving undocumented behavior that only works because process-global
  state leaked between tests.

## Supported Topology

| Topology | Decision | Contract |
| --- | --- | --- |
| One stable `MaterialApp`, root Navigator | Fully supported | Existing `SuperOverlay.init()` and `SuperOverlay.observer` remain the shortest integration. The singleton observer is attached to one Navigator only. |
| Atomic whole `MaterialApp` replacement | Fully supported through integration pairs | Each root uses its own stable `SuperOverlay.integration()` object, which supplies a matching builder and observer. A pending candidate is promoted only when the old root detaches by the frame boundary. |
| AnimatedSwitcher or another multi-frame overlap between root apps | Unsupported | Two full app roots remain live and are indistinguishable from concurrent apps. Use one `MaterialApp` and animate content below it. |
| `ShellRoute` or ordinary nested Navigator | Fully supported | Each nested Navigator gets a fresh observer and commands use `SuperOverlay.of(context)` when route ownership should follow that nested route. |
| `StatefulShellRoute.indexedStack` branches | Supported with explicit scoped calls | Each branch gets its own stable observer. The default container's Navigator-level `TickerMode` marks branch activity, so a root-rendered overlay hides while its branch is offstage and reappears when active. |
| Custom `StatefulShellRoute.navigatorContainerBuilder` | Conditional | Exactly one active branch must expose activity through Navigator-level `TickerMode`. Simultaneously visible or otherwise custom activity models are not inferred. |
| Two live `MaterialApp` hosts in one isolate | Unsupported, fail fast | A one-frame replacement overlap is frozen and evaluated. If both owners remain mounted, the candidate stays conflicted, new global commands fail, and commands never silently cross hosts. |
| Desktop multi-window in one isolate/view registry | Unsupported for this milestone | The host records its `FlutterView`; a competing view is rejected with guidance. Separate isolates may have independent static state but are not claimed as a tested multi-window API. |

The support boundary is intentionally asymmetric. Nested Navigators share one
visual application root and can safely render into one host once route
ownership is explicit. Multiple root apps or windows need independent runtime
registries, default configurations, back dispatch, focus ownership, and window
routing; adding that complexity to the global API would make the common case
less predictable.

## Public Integration Design

### Root API Remains Simple

Existing applications keep the current integration:

```dart
MaterialApp(
  builder: SuperOverlay.init(),
  navigatorObservers: [SuperOverlay.observer],
  home: const AppHome(),
);
```

`SuperOverlay.dialog`, `loading`, `popup`, `notify`, `toast`, `close`, and
`exists` continue to address the single root host. Existing static dialog and
popup calls remain bound to the root Navigator when `bindToRoute` is enabled.

The static observer is a singleton and therefore must not be attached to two
Navigators, even for a short transition. Applications that replace the whole
`MaterialApp` create one stable integration object per root:

```dart
class AppState extends State<App> {
  final overlay = SuperOverlay.integration();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: overlay.builder,
      navigatorObservers: [overlay.observer],
      home: const AppHome(),
    );
  }
}
```

The integration object also creates nested observers associated with its root.
It must be stored outside `build`; constructing a new integration on every
rebuild is a configuration error. Two simultaneously mounted MaterialApps must
not reuse one integration because its observer is intentionally single-owner.

### Nested Navigator API Is Explicit

A nested Navigator must receive a new observer instance. The singleton root
observer must never be reused by two Navigators.

```dart
// Store both fields outside build.
final overlay = SuperOverlay.integration();
final nestedObserver = overlay.navigatorObserver();

Navigator(
  observers: [nestedObserver],
  onGenerateRoute: buildNestedRoute,
);
```

Commands originating from the nested route select that route explicitly:

```dart
final handle = SuperOverlay.of(context).dialog.show<bool>(
  builder: (_) => const ConfirmDialog(),
);
```

`SuperOverlay.of(context)` resolves and stores the route and Navigator scope at
command creation time. It does not keep using a mutable global "current route"
and it does not choose a host based on whichever Navigator emitted the latest
event.

The scoped facade exposes the same surface services. Route-neutral surfaces
such as Toast and notification still render in the root host; the scope only
changes route ownership for commands that opt into route binding. Handle-owned
close remains the preferred cleanup path.

If a scoped, route-bound command cannot find a registered observer for its
route, it throws a diagnostic `StateError` in every build mode rather than
silently binding to the root route. `bindToRoute: false` remains usable without
a nested observer because it has no route lifecycle contract.

### `go_router` Integration

`ShellRoute.observers` and `StatefulShellBranch.observers` receive distinct,
stable observer instances created with the root integration. The root
`GoRouter.observers` receives the matching root observer. A page descendant
context below the target Navigator uses `SuperOverlay.of(context)` for
route-bound dialogs and popups. A shell AppBar or navigation bar context above
the branch Navigator resolves to the root/shell route; branch-owned commands
must be initiated with a descendant context from that branch.

The package keeps zero runtime dependencies. `go_router` is a dev-only
compatibility fixture, pinned to a version that supports the declared Flutter
3.29 minimum, so actual `ShellRoute` behavior is tested without making
applications install `go_router`.

## Runtime Architecture

```text
SuperOverlay.init()
        |
        v
Root Overlay Host ---- host lease/generation ---- OverlayManager
        |                                           |
        |                                           +-- overlay records/handles
        |                                           +-- Toast/loading state
        |                                           +-- focus/back coordinator
        |
        +-- root Navigator observer ----+
                                        |
nested observer factory ----------------+--> NavigatorScopeRegistry
                                                 |
SuperOverlay.of(context) ------------------------+--> immutable route owner
```

### Host Lease And Generation

Each stable integration owns a private identity and a unique root observer.
Its builder creates a host registration that returns an internal lease
containing:

- the owner identity;
- a monotonically increasing generation;
- the `FlutterView` associated with the host;
- owner-scoped default builders and styles.

Only the active lease may update defaults, accept command contexts, or dispose
the active runtime. A competing registration first becomes a
`PendingCandidate` with its own not-yet-active overlay entries and defaults.
During that overlap, new global commands are frozen; the active generation and
its handles are not destroyed by the candidate.

During the pending frame, every new show/global-close/existence command throws
an actionable transient `StateError`; commands are not queued across an unknown
generation. At the end of the frame, promotion is atomic:

- if the previous owner detached and the candidate remains mounted, settle the
  previous generation, promote the candidate, apply its defaults, and unfreeze
  commands;
- if both owners remain mounted, keep the previous active runtime, retain the
  candidate only as a conflicted owner, and expose an unsupported-topology error
  for new global commands;
- if the candidate detached, discard it and continue with the previous owner.

Conflict recovery is deterministic. If every candidate detaches, the retained
active owner resumes accepting commands. If the active owner detaches and
exactly one candidate remains, that candidate is promoted. Two or more
remaining candidates stay conflicted; none wins by registration timing.

Existing handles capture their host generation. They may close their own
records during a conflict but cannot mutate a later generation. Disposing a
stale or conflicted lease only unregisters that lease.

### Navigator Scope Registry

`RouteRecord` is replaced by a registry keyed by observer/Navigator scope. Each
scope owns its own ordered route stack. A route owner is immutable data:

```text
scope identity + route identity + invocation mount probe + Navigator activity
```

Overlay records store that owner. Push, pop, remove, and replace events only
affect records owned by the same scope. This prevents a route change in one
tab or shell from hiding or closing an overlay owned by another Navigator.

For stateful shell branches, the registry observes activity at the branch
Navigator context, which is below go_router's branch `TickerMode` but above any
page-local `TickerMode`. An unmounted invocation context closes its bound
overlay. A disabled branch Navigator hides it, and branch reactivation makes it
visible again. This directly supports go_router's default
`StatefulShellRoute.indexedStack` container. A custom container must provide the
same exactly-one-active-branch signal through Navigator-level `TickerMode`; the
package does not guess activity from paint order, animation, or size.
Monitoring runs only while scoped or widget-bound overlays exist.

NavigatorObserver has no detach callback. A dynamically owned scoped observer
therefore has an explicit `dispose()` contract and must be disposed beside its
Navigator/router configuration; the root integration disposes its root
observer. The registry keeps weak references to route and Navigator objects so
an idle detached scope cannot retain a route tree. It also prunes lazily on
host lifecycle, route events, and command resolution. While a scope owns active
overlays, the existing frame monitor checks `observer.navigator`; if it remains
null at the frame boundary, the registry unregisters reachable `PopEntry`
objects, closes route-bound overlays, and drops the scope. Same-frame
deactivate/activate moves are preserved.

Route coverage and branch inactivity move an overlay through an explicit
`visible -> suspended -> visible` lifecycle. A suspended overlay is removed
from hit testing, semantics, focus traversal, and back priority. A modal that
owned primary focus releases it to the visible page and requests focus again
only when resumed under its existing focus policy. Timers continue running, so
an auto-dismiss deadline may close an overlay while it is suspended.

Suspension can also happen between command creation and the first rendered
frame. In `showing -> suspended-before-visible`, the overlay must not flash and
its `visible` future stays pending until a real visible frame. If it closes
while still suspended, `visible` fails with the existing pre-render
`StateError`.

### Back Dispatch

The late process-global `WidgetsBindingObserver.didPopRoute` hook is removed.
`MaterialApp.builder` places the host outside the Navigator's routes, so a
`PopScope` wrapped directly around the host would not register with the active
`ModalRoute`. Instead, every SuperOverlay Navigator observer registers an
internal `PopEntry` with each observed `ModalRoute`. This is the same public
Flutter pop protocol used by `PopScope`, including Android predictive back.

The manager mirrors the global visible-overlay back disposition to every
current observed `ModalRoute` that may receive a system back event, not only to
the route that owns the overlay. This matters because a default MaterialApp may
send system back to its root Navigator even when the visible overlay belongs to
a nested Navigator.

`dismiss` and `block` set each relevant entry's synchronous `canPopNotifier` to
false; a failed pop callback then closes a `dismiss` overlay through the same
idempotent close path. The entries stay blocking through the full close
animation and are released only after the overlay record is removed, preventing
a rapid second back from popping the page underneath. A pass-through surface
is skipped while resolving the existing loading, notification, dialog/popup
priority, and the application may pop only when no lower-priority overlay
consumes the event. Successful route pops are observed but do not trigger a
second overlay close. Escape invokes the same policy for keyboard users.

Flutter broadcasts a failed pop attempt to every `PopEntry` registered on that
route. Consequently, an application `PopScope` or `Form` callback may also
receive `didPop == false` when SuperOverlay blocks the route. The package
guarantees that the route does not pop; it cannot guarantee that unrelated
callbacks are not notified. Interoperability tests and documentation require
those application callbacks to be idempotent and free of destructive side
effects on a failed attempt.

A custom route that is not a `ModalRoute` cannot register a `PopEntry` and is
not supported for a back-consuming overlay. The package reports this topology
when a scoped command requests `dismiss` or `block` on such a route;
`passThrough` and `bindToRoute: false` remain available.

The same validation applies to the root API. If the host builder is installed
but its matching root observer is missing or has no current `ModalRoute`, a
command that requests route binding or a consuming back behavior fails in every
build mode. Route-neutral, pass-through Toast or notification commands remain
available. A custom Router/back dispatcher that bypasses Navigator and
`ModalRoute` is outside this milestone's back guarantee.

Back ordering and pass-through semantics are locked by isolated tests. No test
may depend on an observer registered by a previous test file.

### Toast And Loading Completion

Every active Toast exits through one internal finalization function. It
cancels the timer, awaits animation dismissal, settles all attached requests,
and invokes the queue continuation once. Timer, tag, global, replacement, and
host-disposal paths all use it.

Loading keeps a shared pending-close future while the minimum visible duration
is active. Every `close()` caller awaits the real dismissal and close animation.
Starting a replacement settles the previous generation before rebinding the
singleton loading entry.

### Modal Accessibility And Keyboard Contract

Modal dialog and loading surfaces:

- capture focus after their first rendered frame;
- use a closed-loop focus scope;
- block background semantics;
- expose a semantic route/container and a localized barrier label;
- restore the previously focused node after close when it is still valid;
- route Escape through `OverlayBackBehavior`.

Popup focus remains non-modal by default. A popup restores target focus on
close and handles Escape while focus is inside the popup, but does not trap Tab
unless a future explicit popup focus policy requests it. Toast and notification
surfaces use live-region semantics and never steal focus.

Accessibility options are additive and typed. Defaults must be useful without
forcing every caller to supply labels, while custom content remains responsible
for its own control labels.

### Moving Popup Anchors

The existing `targetContext` API cannot retroactively create a shared
`LayerLink`, so this milestone keeps it and adds measured-anchor tracking.
While an anchored popup is visible, the existing frame monitor compares the
target rectangle with the last rendered rectangle after converting both into
the active root Overlay's local coordinate space. A meaningful change
invalidates the popup once for that frame. Popup placement, highlight cutout,
and highlight hit testing use the same local rectangle snapshot. An explicit
`maskIgnoreArea` remains fixed in its documented overlay-host coordinates.

The monitor is disabled when there are no anchored, scoped, or widget-bound
records. A future optional anchor widget may add a composited fast path without
breaking this API.

## Failure And Cleanup Contracts

- Commands before host initialization throw the existing actionable error.
- New show/global-close/existence commands synchronously throw a transient
  `StateError` during an unresolved atomic host handoff.
- Commands after detection of competing hosts throw an unsupported-topology
  error naming the one-host-per-isolate contract; handles from the retained
  active generation may still close their own records.
- Root or scoped commands that require route binding or consuming back behavior
  fail immediately in every build mode when their matching observer/current
  `ModalRoute` is absent.
- Stale host disposal is a no-op for the current generation.
- Route removal, host replacement, timer close, mask close, back close, Escape,
  and handle close settle `closed` once.
- `visible` completes only after the first rendered frame; a command closed
  before rendering completes it with `StateError`.
- Invalid or unmounted popup anchors fail closed and leave no registry record.
- Suspended route-bound overlays do not intercept pointer, semantics, focus, or
  back input.
- A loading `close()` future never completes while the loading overlay remains
  visible solely because of `minimumVisibleDuration`.

## Example And Documentation Design

The runnable example must demonstrate the package's decision-making contracts,
not every internal option:

1. A confirmation dialog returns `bool` through `OverlayHandle<bool>.closed`.
2. Back controls use the public names `dismiss`, `block`, and `passThrough`.
3. A nested Navigator page shows that a scoped route-bound overlay hides,
   restores, and closes with the correct inner route.
4. The Overlay Control Lab retains visible/closed timeline, handle close,
   refresh, and scoped cleanup.
5. Toast policies document the distinction between a new `refreshActive`
   command and refreshing content owned by an existing handle.

The README adds:

- root, replacement-safe integration-pair, and nested integration snippets;
- `go_router` `ShellRoute` and `StatefulShellBranch` observer wiring;
- a topology support table;
- accessibility and keyboard behavior;
- the explicit multiple-`MaterialApp` and desktop multi-window limitation;
- a capability-to-example-to-test matrix.

The example can keep Flutter-only nested navigation. Actual `ShellRoute`
compatibility is verified in package tests so the example does not acquire a
runtime router dependency only for demonstration.

## Verification And Release Gates

Automated gates:

- formatting, analysis, documentation dry-run, and publish dry-run;
- the complete package suite with coverage at or above 90%;
- the cold-start back test by itself;
- randomized test ordering to detect process-global leakage;
- atomic host replacement, stale-owner, observer-ownership, and competing-host
  tests;
- generic nested Navigator, `ShellRoute`, default stateful branch, observer
  disposal, and suspended-overlay tests;
- PopEntry interoperability tests with application `PopScope` and `Form`;
- focus traversal, focus restoration, semantics, Escape, and text-scale tests;
- moving-anchor and highlight synchronization tests;
- package consumer-import smoke test;
- example analysis, tests, and web build;
- Flutter stable plus the declared Flutter 3.29 minimum.

Manual release gates:

- cutout iPhone and edge-to-edge Android portrait/landscape checks;
- keyboard-open popup and focus checks;
- Android system back and predictive-back checks on a physical device or
  emulator that exposes the gesture;
- one desktop keyboard pass for Tab, Shift-Tab, and Escape;
- a clean archive inspection, versioned changelog, tag, and successful remote
  CI run.

The source can be considered code-ready when all automated gates pass. It is
release-ready only when the manual matrix and version traceability are also
recorded. A publish dry-run alone is not sufficient evidence.

## Rollout Order

1. Lock current defects with standalone failing tests.
2. Add host lease/generation and topology diagnostics.
3. Replace global back monitoring with route-registered `PopEntry` objects.
4. Fix Toast queue and loading close completion.
5. Add scoped Navigator registry and public scoped client.
6. Verify generic nested Navigator and real `go_router` shell fixtures.
7. Add modal accessibility and keyboard contracts.
8. Track moving popup anchors.
9. Update example, README, support matrix, and governance.
10. Run automated gates, complete the manual device matrix, and prepare a
    traceable release.

This ordering fixes data-loss and navigation defects before expanding the
public integration surface, then uses examples and release evidence to prove
the resulting contracts.
