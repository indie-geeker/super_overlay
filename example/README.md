# SuperOverlay Example

This Flutter-only app demonstrates the package's production contracts through
runnable scenarios. It deliberately does not depend on `go_router`; package
tests cover `ShellRoute` and stateful branches while the example keeps nested
navigation understandable with Flutter's standard `Navigator` API.

The showcase and teaching entries share `ShowcaseTheme`; shared panels and the
header keep presentation code small. Desktop content has a bounded reading
width, and the same controls stack on narrow screens.

## Minimal Integration

[`minimal_main.dart`](lib/minimal_main.dart) creates one stable integration,
awaits a typed confirmation result using the handle supplied to its content
builder, and runs its task through `SuperOverlay.loading.run()` for automatic
cleanup after success or failure. It handles cancellation and disposal without adding
routing or state-management dependencies. Run it from `example/`:

```bash
flutter run --target lib/minimal_main.dart
```

The default entry below keeps the comprehensive showcase.

## Refresh And Resource Lifecycle

[`refresh_lifecycle_main.dart`](lib/refresh_lifecycle_main.dart) demonstrates
global `NotifyStyle` factories reading a captured progress value again through
`handle.refresh()`, explicit builder priority, and stopping updates on close.
It also opens a retained form: cover its owner route, return, and observe that
input survives while its business Timer/Stream keep running. Disposal releases
those resources. Run it from `example/`:

```bash
flutter run --target lib/refresh_lifecycle_main.dart
```

Custom dialog content owns keyboard avoidance. Use `AlertDialog`, as this
example does, or apply changing `MediaQuery.viewInsets` and scroll constraints
in your own content. Suspension stops hidden tickers, not arbitrary business
timers or stream subscriptions.

## Performance Workload

[`performance_main.dart`](lib/performance_main.dart) is a development entry
for idle, stationary/moving anchors, route suspension, repeated close and host
replacement. Follow the
[measurement protocol](../tool/verification/performance_protocol.md) for
profile timing and GC evidence. This entry deliberately imports internal
diagnostics and is not a recommended consumer API example.

## Demonstrated Scenarios

- Toast `replaceLatest`, `queue`, `stack`, and `refreshActive` policies.
- A separately tagged, handle-owned Toast updated only by `handle.refresh()`.
- Typed `OverlayHandle<bool>` confirmation results observed through `closed`.
- `OverlayBackBehavior.dismiss`, `block`, and `passThrough` with visible page
  outcomes.
- A nested Navigator with one scoped observer; route-owned dialogs suspend,
  resume, and close with their owner route.
- Moving anchored menus, popup geometry hooks, highlighted targets, and a fixed
  overlay-host `maskIgnoreArea`.
- Route-bound and widget-bound lifecycle cleanup.
- Request loading paired with page-owned empty, error, and image states.
- Custom loading, Toast, and notification styling configured by one stable
  `SuperOverlayIntegration` owned by `MyApp` state.

The app creates exactly one root integration. Its nested-navigation demo uses
`integration.navigatorObserver()` and disposes that scoped observer with the
nested Navigator; it never mounts a second root integration.

## Run

From the repository root:

```bash
cd example
flutter run
```

## Verify

```bash
# From the repository root, using the selected installed Flutter SDK:
dart tool/verify.dart --suite full
```

The shared gate analyzes/tests the package and example and builds the showcase,
minimal, refresh/lifecycle and performance Web entries. See
[CONTRIBUTING](../CONTRIBUTING.md) for minimum SDK, modern-router, focused checks
and retained diagnostics. Native software interaction and physical-device
checks remain separate.

Widget tests cover the core scenarios, safe-area padding, and responsive widths
of 320, 600, and 1200 logical pixels at normal and double text scale. Notification
controls are also exercised through all five types at the narrowest width. The
[coverage matrix](../tool/verification/example_coverage_matrix.md) maps each
package contract to its README section, runnable page, and automated test.

Simulation is not physical-device proof. Before release, record cutout,
orientation, keyboard, and moving-anchor results in the
[device verification matrix](../tool/verification/example_device_matrix.md).
