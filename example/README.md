# SuperOverlay Example

This Flutter-only app demonstrates the package's production contracts through
runnable scenarios. It deliberately does not depend on `go_router`; package
tests cover `ShellRoute` and stateful branches while the example keeps nested
navigation understandable with Flutter's standard `Navigator` API.

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
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build web
```

Widget tests cover the core scenarios, safe-area padding, and responsive widths
of 320, 600, and 1200 logical pixels. The
[coverage matrix](../tool/verification/example_coverage_matrix.md) maps each
package contract to its README section, runnable page, and automated test.

Simulation is not physical-device proof. Before release, record cutout,
orientation, keyboard, and moving-anchor results in the
[device verification matrix](../tool/verification/example_device_matrix.md).
