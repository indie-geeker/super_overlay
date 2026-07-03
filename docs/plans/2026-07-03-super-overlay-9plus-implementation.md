# SuperOverlay 9+ Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild the public integration surface and stability contracts so every reviewed quality dimension reaches 9/10 or above for commercial Flutter app integration.

**Architecture:** Introduce a command-oriented public API backed by typed options, lifecycle handles, and explicit overlay policies. Reuse the current self-managed `OverlayEntry` runtime where it satisfies the new contracts, and refactor manager/controller behavior where the existing implementation leaks fluent-builder semantics or lifecycle ambiguity.

**Tech Stack:** Flutter package, Dart, Flutter widget tests, dartdoc, pub publish dry-run, GitHub Actions. Runtime dependencies remain limited to Flutter SDK only.

---

### Task 1: Lock The New Public API With Failing Consumer Tests

**Files:**
- Modify: `test/consumer_import_smoke_test.dart`
- Create: `test/super_overlay_command_api_test.dart`
- Modify later: `lib/super_overlay.dart`
- Modify later: `lib/src/super_overlay_core.dart`

**Step 1: Write failing consumer tests**

Replace the current fluent-builder consumer smoke expectations with the new command API:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  test('package entrypoint exports command API contracts', () {
    expect(SuperOverlay.init, isA<TransitionBuilder Function()>());
    expect(SuperOverlay.observer, isA<NavigatorObserver>());

    const dialogOptions = OverlayDialogOptions(
      tag: 'dialog',
      strategy: OverlayStrategy.replaceExisting,
      backBehavior: OverlayBackBehavior.dismiss,
    );
    expect(dialogOptions.tag, 'dialog');

    final handle = OverlayHandle<void>.detached();
    expect(handle.isVisible, isFalse);
  });
}
```

Add widget tests in `test/super_overlay_command_api_test.dart` for:

- `SuperOverlay.toast('Saved')`
- `SuperOverlay.loading.show(...).close()`
- `SuperOverlay.dialog.show(...).closed`
- `SuperOverlay.popup.show(...)`
- `SuperOverlay.notify.success(...)`

Use only `package:super_overlay/super_overlay.dart` imports.

**Step 2: Run tests and verify failure**

Run:

```bash
flutter test test/consumer_import_smoke_test.dart test/super_overlay_command_api_test.dart
```

Expected: fail because `SuperOverlay.init`, `OverlayDialogOptions`, `OverlayHandle`, and command services do not exist.

**Step 3: Commit tests only**

```bash
git add test/consumer_import_smoke_test.dart test/super_overlay_command_api_test.dart
git commit -m "test: lock command overlay public api"
```

### Task 2: Add Public Contract Types

**Files:**
- Create: `lib/src/api/overlay_handle.dart`
- Create: `lib/src/api/overlay_options.dart`
- Create: `lib/src/api/overlay_policy.dart`
- Modify: `lib/super_overlay.dart`

**Step 1: Implement contract types**

Add documented public types:

- `OverlayHandle<T>`
- `OverlayLifecycleState`
- `OverlayCloseReason`
- `OverlayStrategy`
- `OverlayBackBehavior`
- `OverlayDialogOptions`
- `OverlayPopupOptions`
- `OverlayLoadingOptions`
- `OverlayToastOptions`
- `OverlayNotifyOptions`

The handle needs:

```dart
class OverlayHandle<T> {
  OverlayHandle({
    required Future<void> visible,
    required Future<T?> closed,
    required Future<void> Function([T? result]) close,
    required VoidCallback refresh,
    required bool Function() isVisible,
  });

  factory OverlayHandle.detached();

  Future<void> get visible;
  Future<T?> get closed;
  bool get isVisible;
  Future<void> close([T? result]);
  void refresh();
}
```

Every public class, enum, and typedef must have Dart documentation comments.

**Step 2: Export only intended public contracts**

Update `lib/super_overlay.dart` to export the new API files and stop exporting obsolete internals that are no longer part of the consumer surface unless still intentionally supported.

**Step 3: Run focused tests**

Run:

```bash
flutter test test/consumer_import_smoke_test.dart
```

Expected: consumer contract tests compile; command service tests still fail.

**Step 4: Commit**

```bash
git add lib/src/api lib/super_overlay.dart test/consumer_import_smoke_test.dart
git commit -m "feat: add overlay public contracts"
```

### Task 3: Implement Command Services On Top Of Current Runtime

**Files:**
- Create: `lib/src/api/overlay_services.dart`
- Modify: `lib/src/super_overlay_core.dart`
- Modify: `lib/src/init_overlay.dart`
- Modify as needed: `lib/src/helper/overlay_manager.dart`
- Modify as needed: `lib/src/helper/overlay_manager_dismiss.dart`

**Step 1: Expose new entrypoints**

Implement:

```dart
class SuperOverlay {
  static TransitionBuilder init({...});
  static NavigatorObserver get observer;

  static final OverlayLoadingService loading = OverlayLoadingService._();
  static final OverlayDialogService dialog = OverlayDialogService._();
  static final OverlayPopupService popup = OverlayPopupService._();
  static final OverlayNotifyService notify = OverlayNotifyService._();

  static OverlayHandle<void> toast(String message, {OverlayToastOptions options = const OverlayToastOptions()});
}
```

Service methods:

- `OverlayLoadingService.show({String message, WidgetBuilder? builder, OverlayLoadingOptions options})`
- `OverlayLoadingService.close()`
- `OverlayDialogService.show<T>({required WidgetBuilder builder, OverlayDialogOptions options})`
- `OverlayPopupService.show<T>({BuildContext? targetContext, required WidgetBuilder builder, OverlayPopupOptions options})`
- `OverlayNotifyService.success/failure/warning/error/alert(...)`

**Step 2: Bridge to existing runtime**

Map options to current params:

- `OverlayStrategy.stack` -> no keep-single behavior.
- `OverlayStrategy.replaceExisting` -> close matching tag first, then show.
- `OverlayStrategy.keepExisting` -> if matching tag exists, return a handle tied to the existing overlay where possible; otherwise show.
- `OverlayBackBehavior.dismiss` -> current `BackType.normal`.
- `OverlayBackBehavior.block` -> current `BackType.block`.
- `OverlayBackBehavior.passThrough` -> current `BackType.ignore`.

Set current await behavior so `OverlayHandle.closed` receives dismiss results.

**Step 3: Run focused tests**

Run:

```bash
flutter test test/super_overlay_command_api_test.dart test/consumer_import_smoke_test.dart
```

Expected: command API happy paths pass.

**Step 4: Commit**

```bash
git add lib/src/api/overlay_services.dart lib/src/super_overlay_core.dart lib/src/init_overlay.dart lib/src/helper test
git commit -m "feat: add command overlay services"
```

### Task 4: Replace Fluent API Tests With Contract Tests

**Files:**
- Modify: `test/super_overlay_custom_cases.dart`
- Modify: `test/super_overlay_feedback_cases.dart`
- Modify: `test/super_overlay_notify_cases.dart`
- Modify: `test/super_overlay_popup_dismiss_cases.dart`
- Modify: `test/super_overlay_popup_geometry_cases.dart`
- Modify: `test/super_overlay_route_cases.dart`
- Modify: `test/super_overlay_back_cases.dart`
- Modify: `test/super_overlay_widget_binding_cases.dart`
- Modify: `test/super_overlay_test.dart`

**Step 1: Convert happy path tests**

Replace calls such as:

```dart
SuperOverlay.show(builder: ...).withTag('profile').fire<String>();
```

with:

```dart
final handle = SuperOverlay.dialog.show<String>(
  builder: ...,
  options: const OverlayDialogOptions(tag: 'profile'),
);
```

Use `await handle.visible` and `await handle.close('closed')` / `await handle.closed` explicitly.

**Step 2: Add lifecycle contract tests**

Cover:

- close can be called more than once.
- mask close and manual close settle `closed` once.
- result value is preserved.
- `visible` completes before `closed`.
- `refresh()` rebuilds the current child.

**Step 3: Run converted suite**

Run:

```bash
flutter test
```

Expected: all package tests pass.

**Step 4: Commit**

```bash
git add test
git commit -m "test: cover command overlay contracts"
```

### Task 5: Fix Runtime Gaps Exposed By The New Contract

**Files:**
- Modify: `lib/src/widget/helper/dialog_scope.dart`
- Modify: `lib/src/helper/overlay_manager_lifecycle.dart`
- Modify: `lib/src/helper/monitor_widget_helper.dart`
- Modify: `lib/src/widget/attach_dialog_widget.dart`
- Modify as needed: `lib/src/helper/overlay_manager.dart`
- Test: relevant files from Task 4

**Step 1: Add failing controller replacement test**

Test `replaceExisting` with a new controller:

1. Show tagged dialog with controller A.
2. Replace same tag with controller B.
3. Mutate content and call controller B refresh.
4. Expect replacement content to rebuild.
5. Call controller A refresh and expect no stale effect.

Expected failure before fix: B is not bound or A remains bound.

**Step 2: Fix `DialogScope` rebinding**

Add `didUpdateWidget`:

```dart
@override
void didUpdateWidget(covariant DialogScope oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (!identical(oldWidget.controller, widget.controller)) {
    oldWidget.controller?.dismiss();
    _setController(widget.controller);
  }
}
```

Ensure dispose clears only the currently bound callback.

**Step 3: Add widget/route/nested runtime tests**

Add coverage for:

- widget target unmount closes widget-bound overlay.
- invalid widget geometry does not render broken popup.
- route replacement/removal closes route-bound overlay.
- nested Navigator behavior is either supported or documented as unsupported.

**Step 4: Run runtime tests**

Run:

```bash
flutter test test/super_overlay_test.dart
```

Expected: all runtime contract tests pass.

**Step 5: Commit**

```bash
git add lib/src/widget/helper/dialog_scope.dart lib/src/helper lib/src/widget test
git commit -m "fix: harden overlay lifecycle contracts"
```

### Task 6: Remove Or Hide Obsolete Fluent Public API

**Files:**
- Modify: `lib/src/super_overlay_core.dart`
- Delete or stop using: `lib/src/builder/super_custom_overlay_builder.dart`
- Delete or stop using: `lib/src/builder/super_loading_overlay_builder.dart`
- Delete or stop using: `lib/src/builder/super_notify_overlay_builder.dart`
- Delete or stop using: `lib/src/builder/super_popup_overlay_builder.dart`
- Delete or stop using: `lib/src/builder/super_toast_overlay_builder.dart`
- Modify: `lib/super_overlay.dart`
- Modify: `test/consumer_import_smoke_test.dart`

**Step 1: Remove public fluent entrypoints**

Remove old public methods:

- `SuperOverlay.show`
- `SuperOverlay.showLoading`
- `SuperOverlay.showToast`
- `SuperOverlay.showPopup`
- `SuperOverlay.showNotify`
- old `dismiss` shape if replaced by typed service/handle close

Keep internal helpers only if they are private or not exported from the public library.

**Step 2: Run import smoke**

Run:

```bash
flutter test test/consumer_import_smoke_test.dart
```

Expected: public API smoke still passes through command API only.

**Step 3: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: no unused part files or public dead API warnings.

**Step 4: Commit**

```bash
git add lib test/consumer_import_smoke_test.dart
git commit -m "refactor: remove fluent overlay public api"
```

### Task 7: Update Example App To The New Business Flow API

**Files:**
- Modify: `example/lib/showcase/showcase_app.dart`
- Modify: `example/lib/showcase/showcase_home_actions.dart`
- Modify: `example/lib/showcase/showcase_home_page.dart`
- Modify: `example/lib/showcase/lifecycle_demo_page.dart`
- Modify: `example/lib/network_state/presentation/network_state_demo_page.dart`
- Modify: `example/test/widget_test.dart`
- Modify: `example/README.md`

**Step 1: Convert example calls**

Replace fluent calls with:

- `SuperOverlay.toast(...)`
- `SuperOverlay.loading.show(...)`
- `SuperOverlay.dialog.show(...)`
- `SuperOverlay.popup.show(...)`
- `SuperOverlay.notify.success(...)`

Keep the example focused on production recipes rather than every internal option.

**Step 2: Update example tests**

Cover:

- request loading
- form/result dialog
- anchored popup
- route-bound lifecycle
- network state split between overlay loading and page-owned empty/error UI

**Step 3: Run example verification**

Run:

```bash
cd example
flutter analyze
flutter test
flutter build web
```

Expected: all pass.

**Step 4: Commit**

```bash
git add example
git commit -m "docs: update example for command overlay api"
```

### Task 8: Rewrite Public Documentation And Dartdoc

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: all exported files under `lib/src/api/`
- Modify: exported config/policy files still in public surface
- Create: `SECURITY.md`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Create: `.github/ISSUE_TEMPLATE/issue.yml`

**Step 1: Rewrite README**

Structure:

1. Quick Start
2. Production Recipes
3. Contracts And Limits

Remove the public link to ignored `doc/reference-comparison.md`.

**Step 2: Add Dart documentation comments**

Every exported class, enum, typedef, option, handle, service, and public method needs a concise `///` comment explaining:

- when to use it
- default behavior
- important lifecycle or platform caveat

**Step 3: Add lightweight governance**

Create `SECURITY.md` with short private-report instructions.

Create one combined issue template for bugs and feature requests. Keep it short.

**Step 4: Run documentation gate**

Run:

```bash
dart doc --dry-run
flutter pub publish --dry-run
```

Expected: both pass with 0 warnings.

**Step 5: Commit**

```bash
git add README.md CHANGELOG.md SECURITY.md .github/ISSUE_TEMPLATE lib
git commit -m "docs: document production overlay integration"
```

### Task 9: Raise Coverage And CI Gates

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify or create tests as needed under `test/`

**Step 1: Add coverage threshold check**

Add a CI step after `flutter test --coverage`:

```bash
awk -F: '/^LH:/{hit+=$2} /^LF:/{found+=$2} END{coverage=hit*100/found; printf "coverage=%.1f%%\n", coverage; exit coverage < 90}' coverage/lcov.info
```

**Step 2: Add example web build to CI**

Add:

```yaml
- name: Build example web
  working-directory: example
  run: flutter build web
```

**Step 3: Run local gate**

Run:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
awk -F: '/^LH:/{hit+=$2} /^LF:/{found+=$2} END{coverage=hit*100/found; printf "coverage=%.1f%%\n", coverage; exit coverage < 90}' coverage/lcov.info
dart doc --dry-run
flutter pub publish --dry-run
(cd example && flutter analyze && flutter test && flutter build web)
```

Expected: all pass, coverage >= 90%, publish dry-run has 0 warnings.

**Step 4: Commit**

```bash
git add .github/workflows/ci.yml test
git commit -m "ci: enforce commercial package quality gate"
```

### Task 10: Final 9+ Review And Cleanup

**Files:**
- Inspect all changed files.
- Modify only files needed to satisfy the final review.

**Step 1: Check public API surface**

Run:

```bash
rg -n "SuperOverlay\\.show|showLoading|showToast|showPopup|showNotify|with[A-Z].*fire|doc/reference-comparison" README.md lib test example
```

Expected: no public docs or examples use obsolete fluent API or ignored internal doc links.

**Step 2: Check runtime dependency policy**

Run:

```bash
dart pub deps --style=compact
```

Expected: no new runtime dependencies beyond Flutter SDK.

**Step 3: Run full final gate**

Run:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
awk -F: '/^LH:/{hit+=$2} /^LF:/{found+=$2} END{coverage=hit*100/found; printf "coverage=%.1f%%\n", coverage; exit coverage < 90}' coverage/lcov.info
dart doc --dry-run
flutter pub publish --dry-run
(cd example && flutter analyze && flutter test && flutter build web)
git diff --check
```

Expected: all pass.

**Step 4: Re-score dimensions**

Re-score:

- functionality
- architecture
- integration experience
- code quality
- test quality
- release quality
- lightweight governance
- commercial stability

Expected: every dimension >= 9/10. If any score is below 9, add a targeted fix and rerun the relevant gate.

**Step 5: Final commit**

```bash
git add .
git commit -m "chore: finalize super overlay 9 plus quality baseline"
```
