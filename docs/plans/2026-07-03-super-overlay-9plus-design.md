# SuperOverlay 9+ Quality Design

## Goal

Raise every quality dimension of `super_overlay` to 9/10 or above for independent developers shipping commercial Flutter applications. The package should be simple to integrate, predictable in complex business flows, and stable across Flutter's supported platforms.

## Confirmed Direction

- Primary target: production integration in commercial Flutter apps.
- Priority: complete business flows, not isolated feedback widgets.
- Compatibility: breaking public API and architecture changes are allowed.
- Migration notes: not required for this rewrite.
- Platforms: Android, iOS, Web, macOS, Windows, and Linux.
- Runtime dependencies: none beyond Flutter.
- Dev dependencies: allowed when they improve tests, linting, or documentation.
- Public docs and examples: English first.
- Verification bar: commercial package quality, including coverage at or above 90%.
- Open-source governance: keep lightweight, only enough to support trust.

## Recommended Approach

Use a layered rewrite rather than a full ground-up rewrite. Redesign the public API and internal contracts first, then reuse current runtime pieces where they fit the new contract. Refactor or replace internals only when the current implementation blocks a simpler API or stronger stability guarantee.

This keeps the existing proven behavior around overlays, popups, route binding, widget binding, back handling, and publish gates, while removing the current fluent-builder-first API from the primary consumer experience.

## Public API Design

The default API should be command-oriented and grouped by business use case:

```dart
SuperOverlay.toast('Saved');

final loading = SuperOverlay.loading.show(message: 'Loading...');
await loading.close();

final result = await SuperOverlay.dialog.show<String>(
  builder: (_) => const ConfirmDialog(),
);

await SuperOverlay.popup.show(
  targetContext: context,
  builder: (_) => const MenuPanel(),
);

SuperOverlay.notify.success('Done');
```

Advanced behavior should be configured with typed options and handles, not long fluent chains:

```dart
final handle = await SuperOverlay.dialog.show<String>(
  builder: (_) => const EditorDialog(),
  options: const OverlayDialogOptions(
    tag: 'editor',
    dismissOnMaskTap: true,
    bindToRoute: true,
    backBehavior: OverlayBackBehavior.dismiss,
  ),
);

final result = await handle.closed;
```

The old `SuperOverlay.show(...).withX().fire()` shape does not need to remain public. It can be removed or used internally if that makes implementation cheaper.

## Architecture Design

The package should expose a small runtime model:

- `OverlayHost`: installed through `MaterialApp.builder`, owns the app-level overlay root.
- `OverlayService`: facade behind `SuperOverlay`, split by dialog/loading/toast/popup/notify.
- `OverlayRegistry`: tracks active overlays, tags, handles, queue policy, and route/widget bindings.
- `OverlayPolicy`: centralizes dismissal, back behavior, route behavior, tag strategy, await behavior, and default stacking rules.
- `OverlayRenderer`: converts registry records into `OverlayEntry` widgets without owning business policy.

The implementation may continue using self-managed `OverlayEntry` as the primary runtime because it fits tag, queue, popup geometry, widget binding, and multiple feedback surface semantics better than route-backed dialogs. However, the implementation is allowed to change if a specific contract is clearer or safer with a different internal structure.

Navigator remains a route-state source through an observer. It should not become the default dialog host unless a later feature explicitly needs route-backed modal behavior.

## Functional Contracts

### Overlay Lifecycle

Every overlay follows a stable lifecycle:

```text
idle -> showing -> visible -> closing -> closed
```

Public handles expose only stable operations:

- `close([result])`
- `refresh()`
- `isVisible`
- `visible`
- `closed`

Closing is idempotent. Mask taps, system back, route removal, timers, and manual close must settle the same `closed` future once.

### Await Semantics

`show()` returns an `OverlayHandle<T>`. Call sites can wait for explicit lifecycle futures:

- `handle.visible`: completed after the overlay is visible.
- `handle.closed`: completed after the overlay closes.

The primary documentation should recommend explicit lifecycle futures rather than hiding behavior behind `fire()` semantics.

### Tag And Queue Strategy

Replace implicit `keepSingle` behavior with explicit strategy:

- `OverlayStrategy.stack`
- `OverlayStrategy.replaceExisting`
- `OverlayStrategy.keepExisting`

Default strategy by surface:

- loading: singleton / replace existing
- toast: queue
- notify: stack unless tag strategy says otherwise
- dialog: stack
- popup: stack

Tags are stable business identifiers. Untagged overlays receive internal IDs.

### Route, Widget, And Back Behavior

Route and widget binding are first-class supported behavior:

- Route-bound overlay hides when its route is covered.
- Route-bound overlay reappears when its route returns.
- Route-bound overlay closes when its route is removed.
- Widget-bound overlay closes when the target unmounts.
- Invalid widget geometry hides or closes according to the overlay type contract.
- System back is handled in a deterministic priority order: loading, notify, dialog/popup.
- Back behavior is explicit: dismiss, block, or pass through.

### Popup Geometry

Popup geometry must be deterministic:

- Target context provides a target rect when valid.
- Target point may override target context origin.
- Target rect builder may transform the final target rect.
- Alignment mode decides inside, edge-centered, or outside placement.
- Screen bounds clamp popup placement.
- Highlight masks use the same target rect.
- Mask ignore areas only affect the mask layer.
- Invalid geometry fails closed without throwing and without rendering a misplaced popup.

## Documentation Design

Rewrite public docs around the integration journey:

1. Quick Start
   - install
   - initialize host
   - toast
   - loading
   - dialog result

2. Production Recipes
   - request loading
   - confirm dialog
   - form dialog result
   - anchored menu popup
   - route-bound overlay
   - widget-bound popup
   - system back behavior
   - global defaults
   - custom widget rendering

3. Contracts And Limits
   - lifecycle
   - handle futures
   - tag and queue strategies
   - route/widget binding
   - popup geometry
   - platform support
   - known limitations

Remove public references to ignored internal files such as `doc/reference-comparison.md`.

All exported public classes, enums, typedefs, options, policies, and handles need Dart documentation comments.

## Testing And Verification Design

Commercial package gate:

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- `flutter test --coverage`
- coverage >= 90%
- `dart doc --dry-run`
- `flutter pub publish --dry-run`
- example `flutter analyze`
- example `flutter test`
- example `flutter build web`

Required test categories:

- consumer import smoke test using only `package:super_overlay/super_overlay.dart`
- toast/loading/dialog/popup/notify happy paths
- idempotent close
- result completes once
- handle visible and closed futures
- tag strategy: stack, replace existing, keep existing
- route hide, restore, and remove
- widget unmount cleanup
- controller replacement and refresh
- back priority and pass-through behavior
- popup target context, target point, target rect, clamp, highlight, and fail-closed geometry
- publish archive and README examples kept in sync through tests where practical

CI should run the same gate. If the declared minimum Flutter SDK cannot be exercised in CI immediately, README should state the declared minimum and the validated CI channel clearly.

## Lightweight Open-Source Governance

Keep only the minimum trust surface:

- `LICENSE`
- `README.md`
- `CHANGELOG.md`
- `THIRD_PARTY_NOTICES.md`
- `SECURITY.md`
- one combined GitHub issue template for bug reports and feature requests

Do not add heavyweight governance in this pass:

- no `CONTRIBUTING.md`
- no PR template
- no Code of Conduct
- no funding files
- no multi-template issue workflow
- no complex version support matrix

CI is still required because it is a quality gate, not governance overhead.

## Acceptance Criteria

The project reaches the 9+ target when:

- Public command-oriented API is the documented default path.
- All public API docs are meaningful and visible through dartdoc.
- README teaches a production integration path without linking to internal ignored docs.
- The full commercial package gate passes.
- Coverage is at least 90%.
- Example app demonstrates complete business flows through the new API.
- The package keeps zero runtime dependencies.
- Lightweight governance files exist and are short.
- A fresh review scores every dimension at 9/10 or above.
