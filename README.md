# SuperOverlay

English | [简体中文](README.zh-CN.md)

SuperOverlay is a Flutter package for app-level dialogs, loading indicators,
toasts, target-attached popups, highlighted guides, and notifications backed by
a self-managed `OverlayEntry` host. It provides typed handles, route and widget
ownership, nested-Navigator scoping, back policies, keyboard/focus behavior,
and moving-anchor tracking without installing a package-owned navigator key.

## Install

This README describes the **0.4.0 API**. Add the pub.dev dependency:

```yaml
dependencies:
  super_overlay: ^0.4.0
```

For local development, use a path dependency:

```yaml
dependencies:
  super_overlay:
    path: ../super_overlay
```

The package requires Dart `>=3.7.0 <4.0.0` and Flutter `>=3.29.0`. Runtime
dependencies are limited to the Flutter SDK; `go_router` is used only as a
dev-time compatibility fixture.

## Migrating From 0.3.1

0.4.0 includes breaking API changes. Update these calls together with the
dependency:

| 0.3.1 | 0.4.0 |
| --- | --- |
| Dialog/Popup `builder(context)` | `builder(context, overlay)`; close content with `overlay.close(result)` |
| `OverlayCloseTarget.topMost` | `OverlayCloseTarget.highestPriority`; surface priority remains independent of visual stacking |
| Scoped `loading`, `notify`, `toast`, `close`, `exists` | Call the same member on global `SuperOverlay`; scoped facades expose only Dialog/Popup |

Existing manual `loading.show()` / `handle.close()` flows remain supported.
`SuperOverlay.loading.run(task)` is the new automatic-cleanup alternative.

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
  late final integration = SuperOverlay.integration();

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

## Command And Handle Basics

Ordinary calls need no options. Use `SuperOverlay.of(context)` for page-owned
Dialog and Popup content, and the global `SuperOverlay` for Loading, Toast and
notifications. The scoped facade exposes only Dialog and Popup commands.

| Need | Entry point | Default behavior |
| --- | --- | --- |
| Message | `SuperOverlay.toast('Saved')` | Queued; closes after 2 seconds |
| Notification | `SuperOverlay.notify.success('Saved')` | Closes after 2.5 seconds; preserves focus |
| Task | `SuperOverlay.loading.run(task)` | Returns the task result and closes this Loading after success or failure |
| Dialog | `SuperOverlay.of(context).dialog.show<T>(...)` | Route-owned; mask tap or back dismisses |
| Anchored menu | `SuperOverlay.of(context).popup.show<T>(...)` | Tracks the target; closes when it becomes unavailable |

The content builder receives `(context, overlay)`. Call `overlay.close(result)`
directly without declaring a `late final handle`. This complete example confirms
an action, runs it with loading, and shows feedback:

```dart
// snippet:quick-commands:start
Future<bool?> confirmAndSync(
  BuildContext context,
  Future<void> Function() syncProfile,
) async {
  final confirmed =
      await SuperOverlay.of(context).dialog
          .show<bool>(
            builder:
                (_, dialog) => AlertDialog(
                  title: const Text('Sync profile?'),
                  actions: [
                    TextButton(
                      onPressed: () => dialog.close(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => dialog.close(true),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
          )
          .closed;
  if (confirmed == true) {
    await SuperOverlay.loading.run(syncProfile, message: 'Syncing profile...');
    SuperOverlay.toast('Saved');
  }
  return confirmed;
}
// snippet:quick-commands:end
```

For manual control, keep the handle returned by `loading.show()` and call
`await handle.close()` in `finally`. Loading has one active display slot.
Overlapping `show` or `run` calls display the latest call; an older task finishing
cannot close a newer Loading. Tasks run independently. Back, dismissal and host
teardown do not cancel business work.
Handle operations use that call's identity rather than its business tag, also
while a close waits for the minimum duration or a replacement waits to display.
A colliding business tag does not grant an older handle ownership of the new
Loading; global tag-based lookup and close remain available.
Back also belongs to the Loading selected when the event was dispatched. An
older back callback cannot close its replacement. Repeated back during a close
waits for that close without cancelling a replacement waiting to display;
explicit global cleanup can still cancel matching pending replacements.

Mask callbacks also belong to the instance that rendered the mask. A tap on an
old mask during replacement or closing cannot dismiss the new instance or
cancel a pending Loading replacement. Delayed Popup target-failure callbacks
likewise close only the Popup that scheduled them, even when tags collide.
Automatic expiry and route/widget cleanup also close the original instance;
they do not repeat a global tag lookup. Explicit global tag cleanup retains
its matching rules.

`minimumVisibleDuration` starts after Loading's first rendered frame. A positive
minimum also delays a close requested before that frame until the frame and
minimum interval complete. Each replacement gets its own interval; host teardown
settles pending closes immediately. `displayDuration` schedules a close when this
Loading becomes the active display, before first paint, and respects this minimum.

Use a `tag` only for deduplication, replacement or global lookup. A non-null tag
groups calls across the same app host and surface, including calls from different
routes. `stack` adds another entry, `keepExisting` preserves the original content,
and `replaceExisting` closes every match before showing new content. A null tag
has no conflict group.

Prefer the content's handle for dismissal. Use an explicit target for global
cleanup:

```dart
await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
await SuperOverlay.close(target: OverlayCloseTarget.allDialogs, tag: 'checkout');
```

Bulk close waits for matching active overlays and existing close operations,
including their animations. It preserves existing results and does not wait for
other tags. `all` starts every surface's cleanup before awaiting any of them;
overlays created after the call are outside its snapshot. Clearing all untagged
Toasts removes their queue and content immediately. `highestPriority` selects one
target in Loading → notification → Dialog/Popup → Toast order, independently of
visual stacking. Global cleanup can also close suspended overlays.

## Handle Lifecycle

`OverlayHandle.visible` completes after the first rendered frame. It fails with
`StateError` if the command is rejected or closes before rendering, including
an invalid popup target or a route removed before first paint. The deliberate
exception is `OverlayHandle.detached()`: it represents a no-op owner, completes
`visible` immediately, and is never visible.

`OverlayHandle.closed` settles exactly once with the optional result. Repeated
`close()` calls share one close future. A suspended route-bound overlay reports
`isVisible == false` until it resumes.
Command-created handles release their content builders after closing; keeping a
closed handle does not keep its disposed content alive. The optional close
result remains available from `closed`.
If suspension precedes the first visibility acknowledgement, `visible` waits
for a rendered frame after resume; closing before resume still rejects it.
If a valid route-owned Dialog or Popup loses its route or observer while
`replaceExisting` waits, the pending command is cancelled: `visible` fails and
`closed` completes normally without displaying its content. An invalid owner
at the initial call still throws immediately.
For Dialogs with `bindToWidget`, widget ownership is checked before replacement
cleanup and again before activation. Anchored Popups make the same check for
their `targetContext`. If that widget has unmounted, the pending command is
cancelled without building content: `visible` fails with `StateError` and
`closed` completes normally. Cancellation before replacement cleanup leaves
existing matches intact; a close already started is not undone. A close result
already supplied is preserved. Popup geometry validation still applies
independently.

## Back, Focus, And Semantics

`OverlayBackBehavior.dismiss` closes the highest-priority consuming overlay,
`block` keeps it visible and blocks the route, and `passThrough` skips that
overlay and inspects the next consuming overlay. If every overlay passes through,
the application handles back. A closing consuming overlay holds back until its
close operation settles. Android predictive back is coordinated through the
same `ModalRoute` `PopEntry` protocol used by `PopScope`.

On keyboard platforms, Escape is focus-local: it uses the same overlay policy
only while keyboard focus is inside the overlay. `requestFocus` controls only
initial focus capture. With `requestFocus: false`, the page retains focus
initially, so Escape remains with the page until focus enters the overlay.
SuperOverlay does not install a host-level keyboard dispatcher.
Focused content handles Escape first: when a text field's selection toolbar is
open, the first press hides that toolbar. Unhandled Escape then falls back to
the overlay policy, including when a content action is disabled. Content that
handles the key or stops its propagation retains that Flutter behavior.
When Flutter text input dispatches `DismissIntent` and no overlay consumes back,
an application `Actions` handler receives it when supplied. Without such a
handler, the intent safely does nothing.

Application `ContextAction` handlers are enabled and invoked with the invocation
context (the focused context for a shortcut), through its `ActionDispatcher`.
Programmatic `Actions.invoke` retains the application's original return value.
Application action results retain their key semantics: `ignored` continues to
outer shortcuts, while `handled` and `skipRemainingHandlers` stop shortcut
propagation as Flutter defines. Other ancestor shortcut maps may independently
dispatch an ignored key again; SuperOverlay does not add a second fallback
invocation at the same shortcut boundary.
Custom dispatchers may intercept an action, change its returned value, or invoke
another action before returning, including through native child `Shortcuts`.
When the shortcut selects the overlay bridge, any actual back consumption
within that dispatch makes Escape handled even if the dispatcher changes the
returned value or reenters before or after delegation. Otherwise the application
action converts the dispatcher's final returned value; nested application return
values do not replace it. If a custom dispatcher intercepts without invoking
the bridge, even a `block` or `dismiss` overlay does not claim that key: the
application action converts the final value. Without an application action,
the bridge uses Flutter's default key consumption. Each shortcut boundary and
subsequent key uses independent state. Programmatic calls retain their original
returned values.

Some Flutter content consumes Escape even with no menu open. For example, a
focused editable `DropdownMenu` does this on the verified SDKs, and a closed
`MenuAnchor` wrapping a `TextField` does this on Flutter 3.29. Native Flutter
dialogs exhibit the same behavior. SuperOverlay preserves these content actions;
provide an explicit close button when using those combinations.

Flutter notifies every `PopEntry` after a failed pop. An application `PopScope`
or `Form` callback may therefore also receive `didPop == false` while
SuperOverlay blocks the route. Keep failed-pop callbacks idempotent and avoid
destructive side effects until `didPop` is true.

Modal dialogs and loading surfaces capture focus by default, use a closed-loop
focus scope, block background semantics, expose a semantic route, and restore
prior focus when possible. `semanticsLabel` labels the overlay's semantic
container. A non-empty label becomes the route name for modal dialogs and
loading, taking precedence over names in content such as AlertDialog. Without
a label, content can supply its own route name. Supply labels when the
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
  builder: (_, popup) => const FilterMenu(),
  options: const OverlayPopupOptions(
    tag: 'filter-menu',
    alignment: Alignment.bottomCenter,
    strategy: OverlayStrategy.replaceExisting,
  ),
);
```

An unmounted or invalid target fails closed and removes its registry record.
Partial clipping at any Overlay viewport edge remains valid and continues to
track. Once the mounted target has no positive-area intersection with the
Overlay viewport, it fails closed as unavailable.
`maskIgnoreArea` is different: it remains fixed in overlay-host coordinates and
does not move relative to the target.

Popup content is constrained to the host's safe area and current keyboard
insets. When the requested edge has insufficient space and the opposite edge
fits, default placement flips to that edge. An alignment returned from
`adjustmentBuilder` overrides automatic flipping; final placement is still
clamped to the usable viewport. Wrap long content in a scrollable widget to
keep every action reachable within these constraints. Anchor and highlight
coordinates remain in the host coordinate system.

Toast layout responds to keyboard opening, height changes, and dismissal without
retaining an offset after the keyboard closes. Top-aligned feedback keeps its
position while it already fits above the keyboard.

## Refresh Contracts

`OverlayToastDisplayPolicy.refreshActive` starts a new toast command in the
policy-owned refresh lane or replaces that lane's content. It is not a handle
content refresh.

Only the latest request owns that lane's content and tag. Superseded builders and
their captured values are released; historical handles' `closed` futures still
wait for the lane to close. Closing or refreshing an older handle does not affect
the latest request.
Unretained refresh commands do not accumulate historical lifecycle objects or
close listeners as the lane stays active. Retained handles and explicit close
observers still track their own requested lifetimes. A historical `closed`
future also completes correctly when first read after the lane has closed.

`handle.refresh()` rebuilds only content owned by that existing handle, across
dialog, popup, loading, notification, and toast surfaces. Use it
for progress or mutable presentation state without starting another command.
Global `NotifyStyle` factories are called again on refresh; an explicit command
builder takes precedence and bypasses the global factory. The runnable example
displays both families side by side.

For persistent notifications, set
`OverlayNotifyOptions(displayDuration: null)`. Omitting the option retains the
2500 ms default; an explicit null disables automatic dismissal.

## Atomic Root Replacement

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
  builder: (_, dialog) => const ConfirmDeleteDialog(),
);
```

Scoped route-bound dialogs and popups suspend while their route is covered,
resume when it becomes current, and close when the owner route or observer is
removed. Route-neutral toast, loading, and notification surfaces remain rooted
at the one app host.

Suspension preserves the state of content that has already been displayed,
including form input and scroll position. Suspended content has no pointer,
semantic, keyboard-focus, or ticker activity. Content suspended before its first
frame remains unbuilt until its route becomes active. Widget-bound overlays
close if their target unmounts, even while suspended.

Suspension does not pause business `Timer`s or stream subscriptions. Content
owns their cancellation in `dispose`; the
[refresh/lifecycle example](example/lib/refresh_lifecycle_main.dart) demonstrates
this boundary along with global notification refresh and explicit builder
priority. Custom dialog content also owns keyboard avoidance: use
`AlertDialog` or respond to `MediaQuery.viewInsets` with suitable scroll/layout
constraints.

`SuperOverlay.of(context)` also captures local `InheritedTheme` overrides at
facade creation, including for popup replacement/adjustment content. Obtain a
new facade after changing a local theme. Arbitrary inherited state (such as a
page-local provider or localization override) is not captured: pass required
values explicitly or wrap the content. The content builder runs in the root
host, so use the owning handle to close it and an application-owned context or
Navigator key for navigation.
The builder context has no inherited Navigator. Widgets that push routes
internally, such as `DropdownButton`, require an explicit Navigator in their
subtree. `SuperOverlay.popup` and `MenuAnchor` can provide menus in the root host
without adding that Navigator.

Read provider values and localized text in the owning page before calling the
helper. This example passes the text explicitly and wraps the content with the
captured locale. Custom page-local localization delegates must also be passed
to `Localizations.override(delegates: ...)` when required. Captured values are
snapshots; obtain updated values and a new facade after they change.

```dart
// snippet:explicit-local-values:start
OverlayHandle<void> showLocalizedConfirmation(
  BuildContext owner,
  String confirmationText,
) {
  final locale = Localizations.localeOf(owner);
  return SuperOverlay.of(owner).dialog.show<void>(
    builder:
        (overlayContext, _) => Localizations.override(
          context: overlayContext,
          locale: locale,
          child: AlertDialog(content: Text(confirmationText)),
        ),
  );
}
// snippet:explicit-local-values:end
```

## go_router ShellRoute

Locally verified combinations: Flutter 3.29.0 with go_router 14.8.1, and Flutter
3.47.4 with go_router 14.8.1 / 18.0.2. The newer combination is checked in an
[independent compatibility fixture](tool/compatibility/go_router_18/README.md).
go_router 18 forwards shell events to root observers by default; SuperOverlay
filters these by Navigator ownership. Each shell/branch still needs its own
scoped observer. These combinations are test evidence, not a promise for every
router version or device.

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
