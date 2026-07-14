# SuperOverlay

SuperOverlay is a Flutter package for app-level dialogs, loading indicators,
toasts, target-attached popups, highlighted guides, and notifications backed by
a self-managed `OverlayEntry` host. It provides typed handles, route and widget
ownership, nested-Navigator scoping, back policies, keyboard/focus behavior,
and moving-anchor tracking without installing a package-owned navigator key.

## Install

```yaml
dependencies:
  super_overlay: ^0.3.0
```

The package requires Dart `>=3.7.0 <4.0.0` and Flutter `>=3.29.0`. Runtime
dependencies are limited to the Flutter SDK; `go_router` is used only as a
dev-time compatibility fixture.

## Root Integration

Create one stable `SuperOverlayIntegration` outside `build`, then use its
matching builder and root observer for that `MaterialApp`. Dispose the
integration with the app root.

```dart
// snippet:root-integration:start
class RootOverlayApp extends StatefulWidget {
  const RootOverlayApp({super.key});

  @override
  State<RootOverlayApp> createState() => _RootOverlayAppState();
}

class _RootOverlayAppState extends State<RootOverlayApp> {
  late final SuperOverlayIntegration integration;

  @override
  void initState() {
    super.initState();
    integration = SuperOverlay.integration();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const AppHome(),
    );
  }

  @override
  void dispose() {
    integration.dispose();
    super.dispose();
  }
}
// snippet:root-integration:end
```

`SuperOverlay.init()` and `SuperOverlay.observer` remain the compact legacy
pair for one stable root. New production integrations should prefer the owned
object above because observer ownership and disposal are explicit.

### Atomic Root Replacement

When replacing a complete `MaterialApp`, give the old and new roots separate,
stable integrations. Store both integration pairs outside their respective
`build` methods. A same-frame replacement overlap is frozen until the old root
detaches, then the candidate is promoted atomically. Existing handles remain
generation-bound and cannot mutate the new root.

Do not reuse one observer in two Navigators, and do not leave both roots mounted
beyond the replacement frame. Two live app hosts in one isolate are an
unsupported conflict, not a multi-tenant mode.

## Nested Navigator Integration

Create one scoped observer per nested Navigator. Store it outside `build`,
attach it to exactly one Navigator, and dispose it when that Navigator is
removed.

```dart
// snippet:nested-navigator:start
class NestedCheckoutFlow extends StatefulWidget {
  const NestedCheckoutFlow({super.key, required this.integration});

  final SuperOverlayIntegration integration;

  @override
  State<NestedCheckoutFlow> createState() => _NestedCheckoutFlowState();
}

class _NestedCheckoutFlowState extends State<NestedCheckoutFlow> {
  late final SuperOverlayNavigatorObserver observer;

  @override
  void initState() {
    super.initState();
    observer = widget.integration.navigatorObserver();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      observers: [observer],
      onGenerateRoute:
          (_) => MaterialPageRoute<void>(builder: (_) => const CheckoutHome()),
    );
  }

  @override
  void dispose() {
    observer.dispose();
    super.dispose();
  }
}
// snippet:nested-navigator:end
```

Call `SuperOverlay.of(context)` with a context below the Navigator that owns the
route. A shell AppBar context above a branch Navigator resolves to the shell or
root scope, not the branch.

```dart
final handle = SuperOverlay.of(context).dialog.show<bool>(
  builder: (_) => const ConfirmDeleteDialog(),
);
```

Scoped route-bound dialogs and popups suspend while their route is covered,
resume when it becomes current, and close when the owner route or observer is
removed. Route-neutral toast, loading, and notification surfaces remain rooted
at the one app host.

## go_router ShellRoute

The root `GoRouter.observers` receives the root observer. Every `ShellRoute`
receives its own scoped observer.

```dart
// snippet:shell-route:start
class ShellRouterOwner {
  ShellRouterOwner(this.integration);

  final SuperOverlayIntegration integration;
  late final SuperOverlayNavigatorObserver shellObserver =
      integration.navigatorObserver();
  late final GoRouter router = GoRouter(
    observers: [integration.observer],
    routes: [
      ShellRoute(
        observers: [shellObserver],
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const ShellHome()),
        ],
      ),
    ],
  );

  void dispose() {
    router.dispose();
    shellObserver.dispose();
  }
}
// snippet:shell-route:end
```

For `StatefulShellRoute.indexedStack`, create a distinct observer for every
branch and initiate branch-owned commands from a descendant context inside that
branch.

```dart
// snippet:stateful-shell-branches:start
class StatefulShellRouterOwner {
  StatefulShellRouterOwner(this.integration);

  final SuperOverlayIntegration integration;
  late final SuperOverlayNavigatorObserver firstBranchObserver =
      integration.navigatorObserver();
  late final SuperOverlayNavigatorObserver secondBranchObserver =
      integration.navigatorObserver();
  late final GoRouter router = GoRouter(
    observers: [integration.observer],
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                Scaffold(body: navigationShell),
        branches: [
          StatefulShellBranch(
            observers: [firstBranchObserver],
            routes: [
              GoRoute(
                path: '/first',
                builder: (context, state) => const FirstBranchHome(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [secondBranchObserver],
            routes: [
              GoRoute(
                path: '/second',
                builder: (context, state) => const SecondBranchHome(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  void dispose() {
    router.dispose();
    firstBranchObserver.dispose();
    secondBranchObserver.dispose();
  }
}
// snippet:stateful-shell-branches:end
```

The default indexed-stack container supplies Navigator-level `TickerMode`, so
inactive branch overlays release hit testing, semantics, focus, and back
priority. A custom stateful-shell container must provide the same
exactly-one-active Navigator-level signal.

## Command And Handle Basics

Keep the returned handle when the calling flow owns the overlay lifecycle:

```dart
final loading = SuperOverlay.loading.show(message: 'Syncing profile...');
try {
  await syncProfile();
  SuperOverlay.toast(
    'Saved',
    options: const OverlayToastOptions(
      displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
    ),
  );
} finally {
  await loading.close();
}
```

Dialogs and popups carry typed results through `closed`:

```dart
late final OverlayHandle<bool> handle;
handle = SuperOverlay.dialog.show<bool>(
  builder: (_) => ConfirmDeleteDialog(
    onDecision: (confirmed) => handle.close(confirmed),
  ),
  options: const OverlayDialogOptions(
    tag: 'delete-confirmation',
    strategy: OverlayStrategy.replaceExisting,
  ),
);

final confirmed = await handle.closed;
```

Prefer `handle.close()` for owned content. Use typed global cleanup for
application shutdown, tests, or content that cannot receive its handle:

```dart
await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
await SuperOverlay.close(
  target: OverlayCloseTarget.allDialogs,
  tag: 'checkout',
  force: true,
);
```

## Back, Focus, And Semantics

`OverlayBackBehavior.dismiss` closes the highest-priority consuming overlay,
`block` keeps it visible and blocks the route, and `passThrough` leaves the back
event to the application. Android predictive back is coordinated through the
same `ModalRoute` `PopEntry` protocol used by `PopScope`.

On keyboard platforms, Escape is focus-local: it uses the same overlay policy
only while keyboard focus is inside the overlay. `requestFocus` controls only
initial focus capture. With `requestFocus: false`, the page retains focus
initially, so Escape remains with the page until focus enters the overlay.
SuperOverlay does not install a host-level keyboard dispatcher.

Flutter notifies every `PopEntry` after a failed pop. An application `PopScope`
or `Form` callback may therefore also receive `didPop == false` while
SuperOverlay blocks the route. Keep failed-pop callbacks idempotent and avoid
destructive side effects until `didPop` is true.

Modal dialogs and loading surfaces capture focus by default, use a closed-loop
focus scope, block background semantics, expose a semantic route, and restore
prior focus when possible. `semanticsLabel` labels the overlay's semantic
container and becomes its route label for modal dialogs. Supply labels when the
surrounding content does not make the purpose clear:

```dart
const OverlayDialogOptions(
  requestFocus: true,
  semanticsLabel: 'Delete confirmation',
  barrierSemanticsLabel: 'Dismiss delete confirmation',
);
```

Dialogs with `consumeEvents: false` are non-modal for both pointer input and
semantics: the underlying page remains interactive and discoverable, and focus
traversal is not trapped inside the overlay. `requestFocus` controls only
initial focus capture; set it to `false` when the page should retain keyboard
focus. Because non-modal traversal is not trapped, traversal can move focus
back to the page; Escape then remains with the page.

Popup focus is non-modal by default. Toasts and notifications are live regions
and do not steal focus. Application content remains responsible for semantic
labels on its own buttons, fields, and custom controls.

Consuming back behavior (`dismiss` or `block`) requires an observed
`ModalRoute`. Custom non-`ModalRoute` routes and dispatchers that bypass
Navigator do not have this guarantee; use `passThrough` or a route-neutral
surface there.

## Moving Anchored Popups

An anchored popup follows a mounted `targetContext` after scrolling, layout,
and transform changes. The runtime converts the target into the root Overlay's
local coordinates and refreshes only that popup when movement exceeds 0.5
logical pixels. Placement, highlight cutout, and highlight hit testing receive
one immutable rectangle snapshot.

```dart
SuperOverlay.popup.show<void>(
  targetContext: buttonContext,
  builder: (_) => const FilterMenu(),
  options: const OverlayPopupOptions(
    tag: 'filter-menu',
    alignment: Alignment.bottomCenter,
    strategy: OverlayStrategy.replaceExisting,
  ),
);
```

An unmounted or invalid target fails closed and removes its registry record.
`maskIgnoreArea` is different: it remains fixed in overlay-host coordinates and
does not move relative to the target.

## Refresh Contracts

`OverlayToastDisplayPolicy.refreshActive` starts a new toast command in the
policy-owned refresh lane or replaces that lane's content. It is not a handle
content refresh.

`handle.refresh()` rebuilds only content owned by that existing handle. Use it
for progress or mutable presentation state without starting another command.
The runnable example displays both families side by side.

## Handle Lifecycle

`OverlayHandle.visible` completes after the first rendered frame. It fails with
`StateError` if the command is rejected or closes before rendering, including
an invalid popup target or a route removed before first paint. The deliberate
exception is `OverlayHandle.detached()`: it represents a no-op owner, completes
`visible` immediately, and is never visible.

`OverlayHandle.closed` settles exactly once with the optional result. Repeated
`close()` calls share one close future. A suspended route-bound overlay reports
`isVisible == false` until it resumes.

## Supported Topology And Platforms

SuperOverlay supports one active root host per isolate. The table records the
release policy; device evidence status is maintained in the
[device verification matrix](tool/verification/example_device_matrix.md).

| Platform | Tier | Release expectation |
| --- | --- | --- |
| Android | Supported | Automated gates plus recorded edge-to-edge/cutout device evidence before release |
| iOS | Supported | Automated gates plus recorded notch/Dynamic Island evidence before release |
| Web | Supported | Full example test suite and `flutter build web` in CI |
| macOS | Best effort | Single-window behavior; record a build/manual result to claim it for a release |
| Windows | Best effort | Single-window behavior; record a build/manual result to claim it for a release |
| Linux | Best effort | Single-window behavior; record a build/manual result to claim it for a release |

Supported navigation topologies include one stable MaterialApp, same-frame
atomic whole-root replacement, ordinary nested Navigators, `ShellRoute`, and
the default `StatefulShellRoute.indexedStack` container.

Explicit limitations:

- simultaneous live `MaterialApp` hosts in one isolate fail fast;
- root transitions that keep old and new hosts mounted across multiple frames
  are unsupported;
- desktop multi-window routing in one isolate/view registry is unsupported;
- custom stateful-shell containers without Navigator-level `TickerMode` cannot
  provide reliable branch activity;
- consuming back behavior on a non-`ModalRoute` is unsupported;
- physical-device cutout and keyboard evidence must be recorded per release;
- desktop claims are single-window best effort unless that release records a
  build and manual result.

## Example, Verification, And Maintenance

The [example app](example/README.md) demonstrates typed dialog results,
`dismiss`/`block`/`passThrough`, nested Navigator suspension and cleanup,
moving anchors, and `refreshActive` versus `handle.refresh()`.

Traceability is recorded in the
[example coverage matrix](tool/verification/example_coverage_matrix.md). See
[CONTRIBUTING.md](CONTRIBUTING.md) for contributor gates,
[RELEASE.md](RELEASE.md) for the release checklist, and
[SECURITY.md](SECURITY.md) for vulnerability reporting policy.

## License

SuperOverlay is MIT licensed. See [LICENSE](LICENSE).
