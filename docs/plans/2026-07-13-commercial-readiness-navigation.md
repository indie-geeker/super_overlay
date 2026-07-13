# SuperOverlay Commercial-Readiness Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the verified runtime blockers, support scoped nested navigation, and make the package's code, example, documentation, CI, and release evidence strong enough for an independent developer to use in a commercial Flutter product.

**Architecture:** Keep one self-managed root `OverlayEntry` runtime per Dart isolate. Add stable integration ownership, a two-phase host handoff, generation-bound handles, Navigator-scoped route ownership, and route-registered `PopEntry` back interception. Continue to render nested-route overlays in the one root host; scope controls lifecycle, focus, semantics, and back priority rather than creating another visual host.

**Tech Stack:** Dart 3.7+, Flutter 3.29+, `flutter_test`, go_router 14.8.1 as a dev-only compatibility fixture, GitHub Actions, LCOV.

---

## Execution Rules

- Work only in the dedicated implementation worktree/branch selected by
  `superpowers:executing-plans`; do not implement on `main`.
- Use `superpowers:test-driven-development` for every runtime or public API
  change. Observe the intended test fail before writing the implementation.
- Use `superpowers:systematic-debugging` if a failure differs from the expected
  contract. Do not weaken an assertion to make a test green.
- Preserve the current command API. New APIs are additive:
  `SuperOverlay.integration()`, `SuperOverlay.of(context)`, and disposable
  scoped observers.
- Keep package runtime dependencies at Flutter SDK only. `go_router: 14.8.1`
  belongs under `dev_dependencies`; that version declares Flutter `>=3.22.0`
  and therefore covers this package's Flutter 3.29 minimum.
- A route-bound or back-consuming command must fail in every build mode when
  its matching observer/current `ModalRoute` is missing. Never fall back to a
  different Navigator.
- Treat `ShellRoute` and ordinary nested Navigator as supported. Treat the
  default `StatefulShellRoute.indexedStack` container as supported. Custom
  stateful containers are supported only when Navigator-level `TickerMode`
  exposes exactly one active branch.
- Treat simultaneous root apps, multi-frame root-app transitions, and desktop
  multi-window routing as documented unsupported topologies.
- Commit after every task. Do not combine unrelated tasks into one commit.

## Verified Starting Point

Run these before editing and save the output in the implementation notes:

```bash
flutter pub get
flutter test --coverage
flutter test test/super_overlay_test.dart --plain-name 'dismiss back behavior closes overlay and blocks page pop'
```

Expected baseline:

- the complete package suite passes 139 tests;
- the isolated cold-start back test fails because the second page is popped;
- the isolated failure is a known defect, not permission to begin with any
  additional failing tests.

### Task 1: Add Stable Root Integration Ownership

**Files:**

- Create: `lib/src/api/super_overlay_integration.dart`
- Create: `lib/src/helper/overlay_host_lease.dart`
- Create: `test/super_overlay_integration_test.dart`
- Modify: `lib/src/super_overlay_core.dart`
- Modify: `lib/src/init_overlay.dart`
- Modify: `lib/src/helper/navigator_observer.dart`
- Modify: `lib/super_overlay.dart`
- Modify: `test/consumer_import_smoke_test.dart`

**Step 1: Write the public API contract tests**

Add tests that prove:

- two calls to `SuperOverlay.integration()` return different root observer
  instances;
- one integration returns the same observer for its lifetime;
- `integration.builder` installs a working host;
- the legacy `SuperOverlay.init()` and `SuperOverlay.observer` still install the
  default integration;
- `integration.navigatorObserver()` returns a distinct disposable scoped
  observer every time;
- every new public type is available through only
  `package:super_overlay/super_overlay.dart`.

Use the intended public shape:

```dart
final integration = SuperOverlay.integration(
  toastBuilder: (message) => Text('owned: $message'),
);

MaterialApp(
  builder: integration.builder,
  navigatorObservers: [integration.observer],
  home: const Scaffold(),
);
```

**Step 2: Run the contract tests and observe failure**

```bash
flutter test test/super_overlay_integration_test.dart test/consumer_import_smoke_test.dart
```

Expected: compilation fails because `SuperOverlay.integration`,
`SuperOverlayIntegration`, and the scoped observer API do not exist.

**Step 3: Implement the integration object**

In `super_overlay_integration.dart`, add a documented public
`SuperOverlayIntegration` that owns:

- one opaque owner identity;
- one stable root `SuperOverlayNavigatorObserver`;
- immutable init-level builder/style configuration;
- a `TransitionBuilder get builder`;
- `SuperOverlayNavigatorObserver navigatorObserver()`;
- an idempotent `dispose()` for observers it owns.

Keep the default singleton integration private in `SuperOverlay`. Make
`SuperOverlay.init(...)` configure/delegate to the legacy default path and make
`SuperOverlay.observer` return that default integration's observer. Do not
attach one observer to two Navigators.

**Step 4: Introduce a host lease without changing runtime behavior yet**

Move the host owner identity out of the process-global init widget. Pass the
integration owner into `SuperOverlayInit`, create an internal `OverlayHostLease`,
and require the lease for context capture and disposal. At this step there is
still only one active lease; Task 2 adds pending/conflict states.

**Step 5: Run focused verification**

```bash
dart format lib/src/api/super_overlay_integration.dart lib/src/helper/overlay_host_lease.dart lib/src/super_overlay_core.dart lib/src/init_overlay.dart lib/src/helper/navigator_observer.dart lib/super_overlay.dart test/super_overlay_integration_test.dart test/consumer_import_smoke_test.dart
flutter analyze
flutter test test/super_overlay_integration_test.dart test/consumer_import_smoke_test.dart test/super_overlay_host_lifecycle_test.dart
```

Expected: all pass and legacy integration remains source-compatible.

**Step 6: Commit**

```bash
git add lib/src/api/super_overlay_integration.dart lib/src/helper/overlay_host_lease.dart lib/src/super_overlay_core.dart lib/src/init_overlay.dart lib/src/helper/navigator_observer.dart lib/super_overlay.dart test/super_overlay_integration_test.dart test/consumer_import_smoke_test.dart
git commit -m "feat: add stable overlay integration ownership"
```

### Task 2: Make Host Handoff, Conflict, And Generations Deterministic

**Files:**

- Create: `test/super_overlay_host_ownership_test.dart`
- Modify: `lib/src/helper/overlay_host_lease.dart`
- Modify: `lib/src/helper/overlay_manager.dart`
- Modify: `lib/src/helper/overlay_manager_dismiss.dart`
- Modify: `lib/src/helper/overlay_manager_lifecycle.dart`
- Modify: `lib/src/helper/overlay_manager_lookup.dart`
- Modify: `lib/src/helper/overlay_manager_models.dart`
- Modify: `lib/src/api/overlay_services.dart`
- Modify: `lib/src/init_overlay.dart`
- Modify: `test/super_overlay_host_lifecycle_test.dart`

**Step 1: Add failing atomic-replacement tests**

Test a first `MaterialApp` with integration A, then atomically pump a second
`MaterialApp` with integration B. Assert after the frame boundary that:

- all A handles settle once;
- B's default Toast builder is active;
- A's stale disposal cannot reset B's defaults;
- an A-generation handle cannot close a same-tag B overlay.

**Step 2: Add failing simultaneous-host and recovery tests**

Mount two MaterialApps with different integrations in one widget tree. Assert:

- a show/global-close/exists call during the pending frame throws a transient
  `StateError` rather than returning a handle for an unknown generation;
- after the frame, new commands throw an unsupported-topology error while both
  roots remain mounted;
- handles from the retained active generation can still close themselves;
- removing the candidate restores the retained owner;
- removing the active owner while exactly one candidate remains promotes that
  candidate;
- two remaining candidates never win by registration order.

`pumpWidget` completes post-frame callbacks before returning, so capture the
transient error from a command probe placed in the candidate app's descendant
`initState`/first build. Give both MaterialApps distinct keys and integrations.
Use ordinary calls after `pumpWidget` only for the settled conflict/recovery
assertions.

**Step 3: Run the new tests and observe failure**

```bash
flutter test test/super_overlay_host_ownership_test.dart test/super_overlay_host_lifecycle_test.dart
```

Expected: current eager `initialize()` either destroys the first runtime or
silently routes to the last captured context.

**Step 4: Implement the host state machine**

Represent manager state explicitly:

```text
empty -> active
active + candidate -> pending
pending + old detached -> active(candidate)
pending + both mounted -> conflict
conflict + candidates detached -> active(old)
conflict + old detached + one candidate -> active(candidate)
```

Each lease owns its loading entry, captured host contexts, `FlutterView`, and
default builder snapshot. Do not insert one `OverlayEntry` into two overlay
trees. Promotion must close/settle the old generation before accepting new
commands. Competing views use the same unsupported-topology path with a
multi-window-specific message.

**Step 5: Bind handles and records to a generation**

Capture the active generation when creating every `OverlayHandle` and manager
record. Pass that generation into handle-owned close/refresh/isVisible paths.
A stale generation is a no-op after its own `closed` future settles and must
never target a later overlay that reused the same tag.

**Step 6: Run focused and regression tests**

```bash
dart format lib/src/helper/overlay_host_lease.dart lib/src/helper/overlay_manager.dart lib/src/helper/overlay_manager_dismiss.dart lib/src/helper/overlay_manager_lifecycle.dart lib/src/helper/overlay_manager_lookup.dart lib/src/helper/overlay_manager_models.dart lib/src/api/overlay_services.dart lib/src/init_overlay.dart test/super_overlay_host_ownership_test.dart test/super_overlay_host_lifecycle_test.dart
flutter analyze
flutter test test/super_overlay_host_ownership_test.dart test/super_overlay_host_lifecycle_test.dart test/super_overlay_replacement_race_test.dart test/super_overlay_command_api_test.dart
```

Expected: all pass; no candidate clears active state before promotion.

**Step 7: Commit**

```bash
git add lib/src/helper/overlay_host_lease.dart lib/src/helper/overlay_manager.dart lib/src/helper/overlay_manager_dismiss.dart lib/src/helper/overlay_manager_lifecycle.dart lib/src/helper/overlay_manager_lookup.dart lib/src/helper/overlay_manager_models.dart lib/src/api/overlay_services.dart lib/src/init_overlay.dart test/super_overlay_host_ownership_test.dart test/super_overlay_host_lifecycle_test.dart
git commit -m "fix: make overlay host handoff generation safe"
```

### Task 3: Fix Queued Toast And Loading Close Completion

**Files:**

- Create: `test/super_overlay_feedback_lifecycle_test.dart`
- Modify: `lib/src/custom/toast_tool.dart`
- Modify: `lib/src/custom/custom_loading.dart`
- Modify: `test/super_overlay_feedback_cases.dart`

**Step 1: Add the queued Toast regression**

Show two untagged queue Toasts with long display durations. Close one through
`SuperOverlay.close(target: OverlayCloseTarget.toast)`. Assert the first handle
closes and the second becomes visible without another Toast command.

**Step 2: Add the loading completion regression**

Show loading with a 500 ms `minimumVisibleDuration`, call `handle.close()` at
100 ms, and record whether the returned future completes. Assert:

- it is incomplete at 499 ms;
- loading is still visible at 499 ms;
- after the minimum duration and close animation, `close()` and `closed`
  complete and the overlay is gone;
- two close callers share the same eventual completion;
- host disposal still settles a pending minimum-duration close.

**Step 3: Run both tests and observe the verified failures**

```bash
flutter test test/super_overlay_feedback_lifecycle_test.dart
```

Expected: the second Toast never appears and loading `close()` completes early.

**Step 4: Centralize Toast finalization**

Create one internal async finalizer that removes the active Toast once, cancels
its timer, awaits animation dismissal, settles attached requests, clears
`_onlyRefreshToast` when relevant, and invokes `onDismissed` once. Route timer,
untagged, tagged, replace-latest, close-all, and host-reset paths through it.

**Step 5: Return the actual pending loading future**

Replace `_pendingDismiss` with a shared pending operation/completer. Every close
caller awaits the same real dismissal. A new loading generation must settle or
cancel the previous pending operation deterministically; do not overwrite a
callback that another handle is awaiting.

**Step 6: Verify and commit**

```bash
dart format lib/src/custom/toast_tool.dart lib/src/custom/custom_loading.dart test/super_overlay_feedback_lifecycle_test.dart test/super_overlay_feedback_cases.dart
flutter test test/super_overlay_feedback_lifecycle_test.dart test/super_overlay_test.dart test/super_overlay_command_api_test.dart
git add lib/src/custom/toast_tool.dart lib/src/custom/custom_loading.dart test/super_overlay_feedback_lifecycle_test.dart test/super_overlay_feedback_cases.dart
git commit -m "fix: settle feedback lifecycle operations reliably"
```

### Task 4: Replace Global Back Observation With Route Pop Entries

**Files:**

- Create: `lib/src/helper/overlay_pop_entry.dart`
- Create: `lib/src/helper/navigator_scope_registry.dart`
- Create: `test/super_overlay_back_dispatch_test.dart`
- Modify: `lib/src/helper/navigator_observer.dart`
- Modify: `lib/src/helper/overlay_manager.dart`
- Modify: `lib/src/helper/overlay_manager_lifecycle.dart`
- Modify: `lib/src/init_overlay.dart`
- Delete: `lib/src/helper/pop_route_monitor.dart`
- Modify: `test/super_overlay_back_cases.dart`
- Modify: `test/super_overlay_test.dart`

**Step 1: Move the cold-start case into a standalone test file**

Create a self-contained app and helper in
`super_overlay_back_dispatch_test.dart`. Do not import a test part whose global
state was initialized elsewhere. Retain this exact command as a permanent gate:

```bash
flutter test test/super_overlay_back_dispatch_test.dart --plain-name 'cold start dismiss closes overlay before page'
```

Expected before implementation: page pops and the test fails.

**Step 2: Add back edge-case tests**

Cover:

- `dismiss`, `block`, and `passThrough`;
- loading, notification, dialog/popup priority;
- a rapid second back while the first overlay is closing;
- programmatic route pop after the overlay is gone;
- a root builder installed without its matching observer;
- a route-binding/back-consuming command on a non-`ModalRoute`;
- coexistence with an application `PopScope` and `Form`, asserting the route
  stays but their failed-pop callbacks may receive `didPop == false`;
- host teardown unregistering every `PopEntry` and listener.

**Step 3: Run and confirm the intended failures**

```bash
flutter test test/super_overlay_back_dispatch_test.dart
```

Expected: cold start and observer-validation cases fail under the old late
`WidgetsBindingObserver` implementation.

**Step 4: Implement `OverlayPopEntry`**

Implement Flutter's public `PopEntry<Object?>` contract with a
`ValueNotifier<bool> canPopNotifier`. Ignore callbacks with `didPop == true`.
For `didPop == false`, ask the manager to execute the current back policy once.
Keep `canPop` false until close animation completes and the record is removed.

**Step 5: Register entries from observers**

For every observed `ModalRoute`, register one internal pop entry. Mirror the
global visible-overlay back disposition to all current observed modal routes,
not only the route owner. This lets root back dispatch close a nested-owned
overlay. Report a deterministic integration error when an operation requires a
current modal route and none exists.

**Step 6: Remove the process-global observer**

Delete `PopRouteMonitor`, remove registration from `SuperOverlayInit`, and
remove all imports. Escape support is added in Task 7 and must call the same
manager policy rather than recreating ordering.

**Step 7: Verify isolation, ordering, and cleanup**

```bash
dart format lib/src/helper/overlay_pop_entry.dart lib/src/helper/navigator_scope_registry.dart lib/src/helper/navigator_observer.dart lib/src/helper/overlay_manager.dart lib/src/helper/overlay_manager_lifecycle.dart lib/src/init_overlay.dart test/super_overlay_back_dispatch_test.dart test/super_overlay_back_cases.dart test/super_overlay_test.dart
flutter analyze
flutter test test/super_overlay_back_dispatch_test.dart
flutter test test/super_overlay_test.dart --plain-name 'dismiss back behavior closes overlay and blocks page pop'
flutter test test/super_overlay_test.dart
```

Expected: every command passes from a fresh process.

**Step 8: Commit**

```bash
git add lib/src/helper/overlay_pop_entry.dart lib/src/helper/navigator_scope_registry.dart lib/src/helper/navigator_observer.dart lib/src/helper/overlay_manager.dart lib/src/helper/overlay_manager_lifecycle.dart lib/src/init_overlay.dart lib/src/helper/pop_route_monitor.dart test/super_overlay_back_dispatch_test.dart test/super_overlay_back_cases.dart test/super_overlay_test.dart
git commit -m "fix: integrate overlay back handling with routes"
```

### Task 5: Add Navigator-Scoped Route Ownership

**Files:**

- Create: `lib/src/api/scoped_super_overlay.dart`
- Create: `lib/src/helper/overlay_route_owner.dart`
- Create: `test/super_overlay_nested_navigation_test.dart`
- Modify: `lib/src/super_overlay_core.dart`
- Modify: `lib/src/api/overlay_services.dart`
- Modify: `lib/src/builder/super_custom_overlay_builder.dart`
- Modify: `lib/src/builder/super_popup_overlay_builder.dart`
- Modify: `lib/src/data/show_param.dart`
- Modify: `lib/src/helper/navigator_scope_registry.dart`
- Modify: `lib/src/helper/navigator_observer.dart`
- Modify: `lib/src/helper/overlay_manager.dart`
- Modify: `lib/src/helper/overlay_manager_lookup.dart`
- Modify: `lib/src/helper/overlay_manager_lifecycle.dart`
- Modify: `lib/src/helper/overlay_manager_models.dart`
- Modify: `lib/src/custom/base_overlay.dart`
- Modify: `lib/src/custom/main_overlay.dart`
- Delete: `lib/src/helper/route_record.dart`
- Modify: `test/internal_coverage_test.dart`
- Modify: `test/super_overlay_route_cases.dart`

**Step 1: Replace the existing unsupported nested test**

Delete the assertion that a nested route push intentionally leaves a root-bound
overlay visible. Add separate tests proving:

- `SuperOverlay.dialog.show` inside a nested page remains root-bound for
  backward compatibility;
- `SuperOverlay.of(nestedContext).dialog.show` binds to the nested route;
- a nested push suspends that scoped overlay;
- a nested pop resumes it;
- a route pushed after command creation but before the overlay's first rendered
  frame moves it from `showing` to suspended without flashing;
- nested route removal closes it;
- a push in sibling Navigator B does not affect an overlay owned by A;
- `bindToRoute: false` stays visible;
- missing nested observer fails in every build mode;
- calling `dispose()` on a scoped observer closes its active route-bound
  overlays and removes registry entries.

**Step 2: Run and observe compile/behavior failures**

```bash
flutter test test/super_overlay_nested_navigation_test.dart
```

Expected: `SuperOverlay.of` does not exist and current global `RouteRecord`
cannot distinguish scopes.

**Step 3: Implement immutable route ownership**

Replace `RouteRecord` with per-observer stacks in
`NavigatorScopeRegistry`. Capture this internal value synchronously at command
creation:

```text
integration generation + scope identity + route identity + invocation context
```

Thread it explicitly through dialog/popup services, builders, show params, and
manager records. Never look up "whatever route is current" later when a queued
replacement finally fires.

**Step 4: Implement `SuperOverlay.of(context)`**

Add a documented `ScopedSuperOverlay` facade. It exposes the same command
surfaces; dialog and popup carry the captured route owner, while loading,
notification, Toast, global close, and exists still address the one active root
host. Keep handle-owned close as the scoped cleanup recommendation.

Resolve `ModalRoute.of(context)` and match it to the active integration's
registered observer. A shell chrome context above a nested Navigator therefore
resolves to its actual root/shell route; do not guess a branch.

**Step 5: Add suspended lifecycle state**

Replace a bare visual hide with explicit record state:

```text
showing -> visible -> suspended -> visible -> closing -> closed
showing -> suspended-before-visible -> showing -> visible
```

Suspended records must not participate in hit testing, semantics, focus, or
back priority. Timers continue. Resuming must not complete `visible` a second
time. If suspension happens before the first frame, `visible` remains pending
until the first actually visible frame; if the command closes while still
suspended, `visible` completes with the existing pre-render `StateError`.

**Step 6: Make observer cleanup deterministic**

The public scoped observer has idempotent `dispose()`. Store weak route and
Navigator references in idle registry entries. While a scope owns overlays,
check observer attachment at frame boundaries and close/prune it if it remains
detached. Also lazy-prune during host lifecycle, route events, and command
resolution.

**Step 7: Verify route isolation**

```bash
dart format lib/src/api/scoped_super_overlay.dart lib/src/helper/overlay_route_owner.dart lib/src/super_overlay_core.dart lib/src/api/overlay_services.dart lib/src/builder/super_custom_overlay_builder.dart lib/src/builder/super_popup_overlay_builder.dart lib/src/data/show_param.dart lib/src/helper/navigator_scope_registry.dart lib/src/helper/navigator_observer.dart lib/src/helper/overlay_manager.dart lib/src/helper/overlay_manager_lookup.dart lib/src/helper/overlay_manager_lifecycle.dart lib/src/helper/overlay_manager_models.dart lib/src/custom/base_overlay.dart lib/src/custom/main_overlay.dart test/super_overlay_nested_navigation_test.dart test/internal_coverage_test.dart test/super_overlay_route_cases.dart
flutter analyze
flutter test test/super_overlay_nested_navigation_test.dart test/super_overlay_test.dart test/internal_coverage_test.dart
```

**Step 8: Commit**

```bash
git add lib/src/api/scoped_super_overlay.dart lib/src/helper/overlay_route_owner.dart lib/src/super_overlay_core.dart lib/src/api/overlay_services.dart lib/src/builder/super_custom_overlay_builder.dart lib/src/builder/super_popup_overlay_builder.dart lib/src/data/show_param.dart lib/src/helper/navigator_scope_registry.dart lib/src/helper/navigator_observer.dart lib/src/helper/overlay_manager.dart lib/src/helper/overlay_manager_lookup.dart lib/src/helper/overlay_manager_lifecycle.dart lib/src/helper/overlay_manager_models.dart lib/src/custom/base_overlay.dart lib/src/custom/main_overlay.dart lib/src/helper/route_record.dart test/super_overlay_nested_navigation_test.dart test/internal_coverage_test.dart test/super_overlay_route_cases.dart
git commit -m "feat: support navigator-scoped overlay lifecycles"
```

### Task 6: Verify Real ShellRoute And Stateful Shell Behavior

**Files:**

- Modify: `pubspec.yaml`
- Create: `test/super_overlay_shell_route_test.dart`
- Modify: `lib/src/helper/navigator_scope_registry.dart`
- Modify: `lib/src/helper/overlay_manager_lifecycle.dart`

**Step 1: Add the dev-only router fixture**

Add exactly this under root `dev_dependencies`:

```yaml
go_router: 14.8.1
```

Run:

```bash
flutter pub get
```

Do not add `go_router` to package runtime dependencies or the example app.

**Step 2: Add a real `ShellRoute` test**

Create stable root and shell observer fields before constructing `GoRouter`.
Assert a route-bound overlay created from a page descendant context below the
shell Navigator suspends/resumes/closes with the shell's route stack. Also
assert a shell AppBar context above that Navigator resolves to the root/shell
route rather than silently choosing the branch.

**Step 3: Add a default `StatefulShellRoute.indexedStack` test**

Give every `StatefulShellBranch` its own stable observer. Show an overlay in
branch A, switch to B, and assert A's record is suspended and excluded from
back priority. Switch to A and assert it resumes. Remove A's route and assert it
closes.

**Step 4: Add the custom-container boundary test**

Build a custom container that wraps branch Navigators in Navigator-level
`TickerMode`. Assert exactly one active branch works. Do not attempt to detect
two visible branches generically: two simultaneously active nested Navigators
may be a legitimate split-view layout, so a custom stateful container without
an activity signal remains a documented unsupported topology.

Read activity from the branch Navigator context (above page-local TickerMode),
using a non-listening inherited-widget lookup compatible with Flutter 3.29.
Do not let a page-local `TickerMode(enabled: false)` suspend the whole branch.

**Step 5: Run stable and minimum-version-compatible tests**

```bash
dart format test/super_overlay_shell_route_test.dart lib/src/helper/navigator_scope_registry.dart lib/src/helper/overlay_manager_lifecycle.dart
flutter analyze
flutter test test/super_overlay_shell_route_test.dart test/super_overlay_nested_navigation_test.dart
```

Expected: all pass without a runtime dependency change.

**Step 6: Commit**

```bash
git add pubspec.yaml test/super_overlay_shell_route_test.dart lib/src/helper/navigator_scope_registry.dart lib/src/helper/overlay_manager_lifecycle.dart
git commit -m "test: verify shell route overlay scoping"
```

### Task 7: Add Modal Semantics, Focus, And Keyboard Contracts

**Files:**

- Create: `lib/src/widget/helper/overlay_accessibility_scope.dart`
- Create: `test/super_overlay_accessibility_test.dart`
- Modify: `lib/src/api/overlay_options.dart`
- Modify: `lib/src/data/show_param.dart`
- Modify: `lib/src/builder/super_custom_overlay_builder.dart`
- Modify: `lib/src/builder/super_loading_overlay_builder.dart`
- Modify: `lib/src/builder/super_notify_overlay_builder.dart`
- Modify: `lib/src/builder/super_toast_overlay_builder.dart`
- Modify: `lib/src/custom/main_overlay.dart`
- Modify: `lib/src/widget/overlay_dialog_widget.dart`
- Modify: `lib/src/widget/attach_dialog_widget.dart`
- Modify: `lib/src/widget/helper/mask_event.dart`
- Modify: `lib/src/helper/overlay_manager_lifecycle.dart`
- Modify: `test/core_types_test.dart`

**Step 1: Add failing focus tests**

Test that a modal dialog and loading overlay:

- capture focus after the first rendered frame;
- keep Tab and Shift-Tab inside a closed loop;
- restore the previously focused page control after close;

For a route-bound dialog specifically, also assert it releases focus while its
route/branch is suspended, reacquires it on resume only when its focus policy
requests it, and does not consume Escape or system back while suspended.
Loading remains root-neutral and is never suspended by a nested route change.

Test that a popup is non-modal by default, restores target focus on close, and
handles Escape only while focus is inside it. Toast and notification must not
steal focus.

**Step 2: Add failing semantics tests**

Using `tester.ensureSemantics()`, assert:

- modal content scopes a semantic route/container;
- background semantics are blocked while a modal is visible and restored after
  close;
- a dismissible barrier exposes a localized dismiss action/label;
- Toast and notification content are live regions;
- suspended overlays leave no active semantics nodes;
- RTL and text scale 2.0 do not throw or clip the default loading, Toast, and
  notification surfaces.

**Step 3: Add failing keyboard tests**

Send `LogicalKeyboardKey.escape` and assert it follows the exact
`OverlayBackBehavior` policy for dismiss, block, and passThrough. It must call
the same manager back coordinator as system back.

Run:

```bash
flutter test test/super_overlay_accessibility_test.dart
```

Expected: focus remains on the page, semantics are not modal, and Escape has no
contract.

**Step 4: Add typed accessibility options**

Add documented, additive options with useful defaults:

- dialog/loading `requestFocus`;
- dialog/loading optional `semanticsLabel` and `barrierSemanticsLabel`;
- popup optional `requestFocus`, default false.

Thread an internal accessibility mode (`modal`, `popup`, or `liveRegion`)
through show params. Do not infer modal behavior solely from the shared
`OverlayDialogWidget`, because dialog, loading, notification, and Toast all use
that renderer.

**Step 5: Implement the accessibility scope**

Use owned `FocusScopeNode`, closed-loop traversal, `BlockSemantics`, `Semantics`,
`Shortcuts`, and `Actions`. Capture the previous focus node weakly/safely and
restore only if it can still request focus. Make suspension a first-class input
so hidden overlays release focus and leave traversal/back priority.

**Step 6: Verify and commit**

```bash
dart format lib/src/widget/helper/overlay_accessibility_scope.dart lib/src/api/overlay_options.dart lib/src/data/show_param.dart lib/src/builder/super_custom_overlay_builder.dart lib/src/builder/super_loading_overlay_builder.dart lib/src/builder/super_notify_overlay_builder.dart lib/src/builder/super_toast_overlay_builder.dart lib/src/custom/main_overlay.dart lib/src/widget/overlay_dialog_widget.dart lib/src/widget/attach_dialog_widget.dart lib/src/widget/helper/mask_event.dart lib/src/helper/overlay_manager_lifecycle.dart test/super_overlay_accessibility_test.dart test/core_types_test.dart
flutter analyze
flutter test test/super_overlay_accessibility_test.dart test/core_types_test.dart test/super_overlay_back_dispatch_test.dart test/super_overlay_nested_navigation_test.dart
git add lib/src/widget/helper/overlay_accessibility_scope.dart lib/src/api/overlay_options.dart lib/src/data/show_param.dart lib/src/builder/super_custom_overlay_builder.dart lib/src/builder/super_loading_overlay_builder.dart lib/src/builder/super_notify_overlay_builder.dart lib/src/builder/super_toast_overlay_builder.dart lib/src/custom/main_overlay.dart lib/src/widget/overlay_dialog_widget.dart lib/src/widget/attach_dialog_widget.dart lib/src/widget/helper/mask_event.dart lib/src/helper/overlay_manager_lifecycle.dart test/super_overlay_accessibility_test.dart test/core_types_test.dart
git commit -m "feat: add accessible modal and keyboard behavior"
```

### Task 8: Keep Anchored Popups Synchronized While Targets Move

**Files:**

- Create: `test/super_overlay_popup_anchor_tracking_test.dart`
- Modify: `lib/src/widget/attach_dialog_widget.dart`
- Modify: `lib/src/helper/monitor_widget_helper.dart`
- Modify: `lib/src/helper/overlay_manager.dart`
- Modify: `lib/src/helper/overlay_manager_lifecycle.dart`
- Modify: `lib/src/helper/overlay_manager_models.dart`
- Modify: `test/super_overlay_popup_geometry_cases.dart`

**Step 1: Add moving-anchor regressions**

Show an anchored popup inside a `Scrollable`. Assert after scrolling that:

- popup placement follows the target in the next frame;
- highlight cutout and its target hit testing use the same target rectangle;
- an explicit `maskIgnoreArea` remains fixed in its documented host
  coordinates rather than moving with the target;
- moving by less than the chosen tolerance does not cause rebuild churn;
- an unmounted or invalid target fails closed and removes the record.

Repeat the placement case with a `styleBuilder` that adds Padding and a
`Transform.translate`; assert the popup is positioned in the root Overlay's
local coordinate system rather than assuming global screen origin `(0, 0)`.

Add a test with two anchored popups to ensure one target's movement does not
refresh the other.

**Step 2: Run and observe stale geometry**

```bash
flutter test test/super_overlay_popup_anchor_tracking_test.dart
```

Expected: the target moves but the popup remains at its original global
position.

**Step 3: Add measured-anchor tracking**

While anchored records exist, convert each mounted target rect from global
coordinates into the active root Overlay render box's local coordinates, then
compare it with the last rendered local rect once per frame. If the difference
exceeds 0.5 logical pixels, schedule exactly one refresh for that entry. Pass
one immutable local rect snapshot into popup layout, highlight, and mask
calculations.

Disable monitoring when there are no anchored, scoped, or widget-bound records.
Do not add a required target wrapper or runtime dependency in this milestone.

**Step 4: Verify and commit**

```bash
dart format lib/src/widget/attach_dialog_widget.dart lib/src/helper/monitor_widget_helper.dart lib/src/helper/overlay_manager.dart lib/src/helper/overlay_manager_lifecycle.dart lib/src/helper/overlay_manager_models.dart test/super_overlay_popup_anchor_tracking_test.dart test/super_overlay_popup_geometry_cases.dart
flutter analyze
flutter test test/super_overlay_popup_anchor_tracking_test.dart test/super_overlay_test.dart test/super_overlay_command_api_test.dart
git add lib/src/widget/attach_dialog_widget.dart lib/src/helper/monitor_widget_helper.dart lib/src/helper/overlay_manager.dart lib/src/helper/overlay_manager_lifecycle.dart lib/src/helper/overlay_manager_models.dart test/super_overlay_popup_anchor_tracking_test.dart test/super_overlay_popup_geometry_cases.dart
git commit -m "fix: track moving popup anchors"
```

### Task 9: Make The Example Demonstrate The Core Contracts

**Files:**

- Create: `example/lib/showcase/nested_navigation_demo_page.dart`
- Create: `example/test/dialog_result_test.dart`
- Create: `example/test/nested_navigation_demo_test.dart`
- Create: `example/test/back_behavior_demo_test.dart`
- Modify: `example/test/instant_feedback_panel_test.dart`
- Modify: `example/lib/showcase/dialog_demo_panel.dart`
- Modify: `example/lib/showcase/lifecycle_demo_page.dart`
- Modify: `example/lib/showcase/instant_feedback_panel.dart`
- Modify: `example/lib/showcase/showcase_home_page.dart`
- Modify: `example/lib/showcase/showcase_app.dart`
- Modify: existing affected files under `example/test/`

**Step 1: Write example tests first**

Add tests proving the runnable app demonstrates:

- a real `OverlayHandle<bool>` confirmation result through `await closed`;
- the public back terms `dismiss`, `block`, and `passThrough`, with observable
  behavior for all three;
- a nested Navigator whose scoped dialog suspends, resumes, and closes with its
  inner route;
- the distinction between starting a new `refreshActive` Toast command and
  calling `refresh()` on content owned by an existing handle.

Run:

```bash
cd example
flutter test test/dialog_result_test.dart test/nested_navigation_demo_test.dart test/back_behavior_demo_test.dart test/instant_feedback_panel_test.dart
```

Expected: files or controls are missing.

**Step 2: Implement the scenarios**

Keep the example Flutter-only; do not add go_router to `example/pubspec.yaml`.
Convert `MyApp` to own one stable `SuperOverlayIntegration` in State, use that
object's builder/root observer, and dispose it with the app. Pass the same
integration to the nested demo; its State creates one
`integration.navigatorObserver()` outside build and disposes that observer.
Never create a second root integration inside the nested page.

Extend `instant_feedback_panel_test.dart` so `refreshActive` proves it updates
the active policy-owned Toast, while a separately tagged Handle-owned Toast is
updated only by its own `refresh()` and remains unaffected by the policy run.
Close both families explicitly at test teardown.

Keep the current scenario language in this milestone, but use the exact public
API identifiers `dismiss`, `block`, `passThrough`, and `refreshActive` wherever
the UI teaches a contract. Do not turn this task into a partial localization;
full example localization is a separate P3 product decision.

**Step 3: Run the complete example gate**

```bash
cd example
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build web
```

Expected: all pass and every new page is reachable from the home page.

**Step 4: Commit**

```bash
git add example/lib example/test
git commit -m "feat(example): demonstrate scoped production contracts"
```

### Task 10: Document Support Boundaries And Open-Source Operations

**Files:**

- Create: `RELEASE.md`
- Create: `tool/verification/example_coverage_matrix.md`
- Create: `test/documentation_contract_test.dart`
- Create: `test/repository_contract_test.dart`
- Modify: `README.md`
- Modify: `example/README.md`
- Modify: `CHANGELOG.md`
- Modify: `SECURITY.md`
- Modify: `.github/ISSUE_TEMPLATE/issue.yml`
- Modify: `.github/ISSUE_TEMPLATE/config.yml`
- Modify: public Dart files added in Tasks 1, 5, and 7
- Modify: `test/consumer_import_smoke_test.dart`

**Step 1: Add documentation checks to tests**

Extend the consumer smoke test to compile root integration, scoped commands,
disposable observers, and new accessibility options using only the package
entrypoint. In `test/documentation_contract_test.dart`, create compile-backed
root, nested-Navigator, `ShellRoute`, and stateful-branch fixture builders.
Mark their source regions with stable snippet IDs, place the same snippets in
README, then normalize/extract and compare them in the test. Also check that
every documented local link resolves and the example coverage matrix is linked.

Add `test/repository_contract_test.dart` to parse the repository's top-level
pubspec blocks and assert:

- direct runtime dependencies are exactly the Flutter SDK;
- `go_router` exists only under `dev_dependencies`;
- README's install version and `example/pubspec.lock` agree with the root
  package version once a release candidate is prepared;
- every advertised platform has an explicit support tier.

Run the focused checks and observe missing content before editing docs.

**Step 2: Rewrite integration and limits documentation**

Add concise runnable sections for:

- stable single-root integration;
- replacement-safe integration pair stored outside build;
- generic nested Navigator;
- go_router `ShellRoute` and `StatefulShellBranch.observers`;
- the requirement to call `SuperOverlay.of` from below the target Navigator;
- scoped observer disposal;
- modal focus, semantics, Escape, predictive back, and the failed-pop callback
  interaction with application `PopScope`/`Form`;
- moving popup anchors;
- unsupported simultaneous MaterialApps, multi-frame root transitions, custom
  stateful containers without Navigator-level `TickerMode`, non-ModalRoute back
  consumption, and desktop multi-window routing;
- an explicit platform matrix: Android/iOS supported with recorded device
  evidence, Web supported and CI-built, and macOS/Windows/Linux best-effort
  single-window support unless a build/manual result is recorded for that
  release;
- the `OverlayHandle.detached` exception to first-render `visible` semantics;
- `refreshActive` versus handle-owned `refresh()`.

**Step 3: Add traceable maintenance documents**

Create a capability-to-README-to-example-to-test matrix. Create `RELEASE.md`
with automated gates, device evidence, version/changelog, remote CI, tag, and
publish steps.

Before editing `SECURITY.md`, perform a read-only check that GitHub private
vulnerability reporting is enabled and that an external reporter can reach the
repository's private advisory path. If it is not enabled, pause and ask the
user either to authorize enabling it or to provide a real private contact; do
not change repository settings or invent an email. Write response-time goals as
best-effort maintainer targets, not a guaranteed SLA.

Require package version, Flutter version, reproduction, expected result, and
actual result in the issue form; keep blank issues disabled unless a documented
reason remains.

Update `CHANGELOG.md` under `Unreleased`; do not assign a release date yet.

**Step 4: Run docs and package-surface checks**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test test/consumer_import_smoke_test.dart test/documentation_contract_test.dart test/repository_contract_test.dart
dart doc --dry-run
flutter pub publish --dry-run
```

Expected: all pass; a dirty-tree warning from publish dry-run is informational,
but archive errors or undocumented public API are failures.

**Step 5: Commit**

```bash
git add README.md example/README.md CHANGELOG.md SECURITY.md RELEASE.md tool/verification/example_coverage_matrix.md .github/ISSUE_TEMPLATE/issue.yml .github/ISSUE_TEMPLATE/config.yml lib/src/api/super_overlay_integration.dart lib/src/api/scoped_super_overlay.dart lib/src/api/overlay_options.dart lib/src/helper/navigator_observer.dart lib/src/super_overlay_core.dart lib/super_overlay.dart test/consumer_import_smoke_test.dart test/documentation_contract_test.dart test/repository_contract_test.dart
git diff --cached --name-only
git commit -m "docs: define commercial support and release contracts"
```

Before committing, compare the staged names with this task's file list and
unstage anything unrelated.

### Task 11: Harden CI Against Regressions And Supply-Chain Drift

**Files:**

- Modify: `.github/workflows/ci.yml`
- Create or Modify: `.github/dependabot.yml`
- Modify: `RELEASE.md`

**Step 1: Add deterministic workflow policy**

Set top-level:

```yaml
permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Add `timeout-minutes` to every job. Resolve official action tag commit SHAs from
their upstream repositories, pin every `uses:` line to a full 40-character SHA,
and retain a version comment such as `# v4`. Do not guess a SHA. Configure
Dependabot to propose GitHub Actions updates.

**Step 2: Add critical standalone and randomized gates**

Before aggregate coverage, run:

```bash
git diff --check
flutter pub deps --style=compact
flutter test test/repository_contract_test.dart
flutter test test/super_overlay_back_dispatch_test.dart
flutter test test/super_overlay_host_ownership_test.dart
flutter test test/super_overlay_shell_route_test.dart
flutter test --test-randomize-ordering-seed=20260713
```

Keep `flutter test --coverage` and the 90% threshold as a separate step. The
fixed seed makes failures reproducible; local release verification also runs a
fresh random seed.

**Step 3: Strengthen minimum-version coverage**

In the Flutter 3.29 job, run package analyze/tests plus example analyze/tests.
The stable job continues docs, publish dry-run, and example Web build.

**Step 4: Validate locally**

Mirror every shell command from the workflow locally. Inspect the YAML diff for
minimal permissions and valid full SHAs. If `actionlint` is installed, run it;
otherwise record that remote CI is the authoritative workflow parser.

After a later authorized push, release readiness requires the remote CI run URL
for the exact release-candidate commit SHA. A local pass alone may be reported
as source code-ready, not release-ready.

**Step 5: Commit**

```bash
git add .github/workflows/ci.yml .github/dependabot.yml RELEASE.md
git commit -m "ci: harden commercial release gates"
```

### Task 12: Run The Commercial-Readiness Gate And Prepare Release Evidence

**Files:**

- Modify: `tool/verification/example_device_matrix.md`
- Modify: `RELEASE.md`
- Modify only after all evidence passes: `README.md`
- Modify only after all evidence passes: `example/pubspec.lock`
- Modify only after all evidence passes: `pubspec.yaml`
- Modify only after all evidence passes: `CHANGELOG.md`

**Step 1: Run formatting and static gates**

```bash
git diff --check
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter pub deps --style=compact
flutter test test/repository_contract_test.dart test/documentation_contract_test.dart
dart doc --dry-run
```

Expected: zero changes, zero analyzer issues, zero doc errors.

**Step 2: Run isolated, randomized, and aggregate package tests**

```bash
flutter test test/super_overlay_back_dispatch_test.dart
flutter test test/super_overlay_host_ownership_test.dart
flutter test test/super_overlay_shell_route_test.dart
flutter test --test-randomize-ordering-seed=20260713
flutter test --test-randomize-ordering-seed=random
flutter test --coverage
awk -F: '/^LH:/{hit+=$2} /^LF:/{found+=$2} END{if (found == 0) exit 2; coverage=hit*100/found; printf "hit=%d found=%d coverage=%.3f%%\n", hit, found, coverage; exit coverage < 90}' coverage/lcov.info
```

Expected: all pass and coverage remains at least 90%.

**Step 3: Run example and publish gates**

```bash
cd example
flutter analyze
flutter test
flutter build web
flutter build apk --debug
cd ..
flutter pub publish --dry-run
```

Run any additional platform build promised by the README support matrix. Do not
upgrade macOS/Windows/Linux from best-effort to supported without a build or
manual result for that platform.

Also copy the repository to a temporary directory without `.git` and repeat
publish dry-run there, so git-dirty warnings are separated from package archive
problems. Use normal file-copy tooling; do not modify the source tree to make
the warning disappear.

**Step 4: Complete the manual device matrix**

Record device/model, OS, orientation, screenshot/evidence path, and result for:

- one cutout iPhone in portrait and landscape;
- one edge-to-edge Android device in portrait and landscape;
- keyboard-open anchored popup and dialog focus restoration;
- Android system back and predictive-back gesture;
- desktop Tab, Shift-Tab, Escape, and popup focus;
- stateful shell branch switching with an active modal;
- moving popup anchor inside a scrolling view.

Do not mark rows complete from widget-test simulation. If the required hardware
is unavailable, stop with the source code-ready but release gate blocked.

**Step 5: Prepare, but do not publish, the release candidate**

Verify the current package registry state from the official pub.dev package API
and reconcile it with local git tags, `pubspec.yaml`, and `CHANGELOG.md` before
editing a version:

- if pub.dev already has `0.2.0` and no newer release, prepare `0.3.0` for the
  new public integration/navigation APIs;
- if pub.dev is still on `0.1.x` while local `0.2.0` was never published, pause
  and ask the user whether this accumulated milestone should become `0.2.0` or
  `0.3.0`;
- if pub.dev is newer than the checkout, stop and reconcile the missing release
  history;
- if the package is absent or ownership cannot be verified, stop before a
  release-number decision.

After the version is chosen, update `pubspec.yaml`, README's install example,
and the dated changelog together. Run `flutter pub get` in `example/` so
`example/pubspec.lock` records the same path package version. Search the full
repository for stale version literals, then rerun the repository contract test
and every gate above.

Do not tag, push, create a GitHub release, or publish to pub.dev without explicit
user authorization and a successful remote CI run.

**Step 6: Commit release-candidate metadata only after the gate passes**

```bash
git add tool/verification/example_device_matrix.md RELEASE.md README.md example/pubspec.lock pubspec.yaml CHANGELOG.md
git diff --cached --name-only
git commit -m "chore: prepare release candidate metadata"
```

If the manual matrix is blocked, commit only truthful documentation updates;
leave version and dated changelog unchanged.

## Completion Criteria

Implementation is code-ready only when:

- every isolated and aggregate automated gate passes from a fresh process;
- no static observer is shared by two Navigators;
- cold-start back, rapid double back, host handoff/conflict, Toast queue,
  loading close, nested/ShellRoute scoping, suspended state, accessibility, and
  moving anchors have public-contract regressions;
- package runtime dependencies remain Flutter-only;
- every advertised platform has an evidence-backed support tier;
- README, example, Dartdoc, support table, and test matrix agree;
- the example is runnable and demonstrates typed results plus scoped nested
  navigation.

The package is release-ready only when the device matrix, clean publish archive,
remote CI, versioned changelog, and release checklist are also complete.
