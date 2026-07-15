# Example English, Safe Notification, and Popup Motion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the entire example English-only, simplify its first feedback card, keep notifications below physical display cutouts, and make anchored popups expand away from their target edge.

**Architecture:** Keep copy and scenario cleanup in `example/`, but fix the two reusable layout behaviors in the package. `OverlayDialogWidget` will preserve physical top/side view padding even after inherited safe padding is consumed; attached popups will use the existing size animation with an anchor-aware axis origin. No new public options or dependencies are introduced.

**Tech Stack:** Flutter 3.29+, Dart 3.7+, Material 3, `flutter_test`, SuperOverlay's existing `OverlayEntry` host.

---

### Task 1: Protect notifications when inherited safe padding is consumed

**Files:**
- Modify: `test/super_overlay_notify_cases.dart`
- Modify: `lib/src/widget/overlay_dialog_widget.dart`

**Step 1: Write the failing regression test**

Add a widget test that preserves physical view padding but consumes the normal
`MediaQuery.padding` before the SuperOverlay host is built:

```dart
testWidgets('notify honors physical cutout after safe padding is consumed', (
  tester,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);

  final integration = SuperOverlay.integration(
    notifyStyle: NotifyStyle(
      warningBuilder:
          (message) => Container(
            key: const ValueKey('consumed-padding-notify'),
            child: Text(message),
          ),
    ),
  );
  addTearDown(integration.dispose);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(padding: EdgeInsets.zero),
          child: integration.builder(context, child),
        );
      },
      navigatorObservers: [integration.observer],
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );

  final handle = SuperOverlay.notify.warning(
    'Physical cutout notification',
    options: const OverlayNotifyOptions(displayDuration: null),
  );
  await tester.pump();

  expect(
    tester.getTopLeft(
      find.byKey(const ValueKey('consumed-padding-notify')),
    ).dy,
    greaterThanOrEqualTo(44),
  );

  final close = handle.close();
  await tester.pumpAndSettle();
  await close;
});
```

**Step 2: Run the test to verify RED**

Run:

```bash
flutter test test/super_overlay_notify_cases.dart \
  --plain-name "notify honors physical cutout after safe padding is consumed"
```

Expected: FAIL because the custom surface starts above 44 logical pixels when
`MediaQuery.padding.top` is zero.

**Step 3: Make `SafeArea` retain physical top and side insets**

In `OverlayDialogWidget.build`, read `MediaQuery.viewPaddingOf(context)` and
pass it as the left/top/right minimum while leaving bottom behavior unchanged:

```dart
final viewPadding = MediaQuery.viewPaddingOf(context);

SafeArea(
  minimum: EdgeInsets.only(
    left: viewPadding.left,
    top: viewPadding.top,
    right: viewPadding.right,
  ),
  child: Align(
    // existing alignment/material/body
  ),
)
```

**Step 4: Run notification regressions to verify GREEN**

Run:

```bash
flutter test test/super_overlay_notify_cases.dart
cd example && flutter test test/widget_test.dart \
  --plain-name "custom notify keeps a visual gap below the safe area"
```

Expected: both commands PASS; the example surface remains at least physical
safe padding plus its 12-pixel visual gap.

**Step 5: Commit**

```bash
git add test/super_overlay_notify_cases.dart \
  lib/src/widget/overlay_dialog_widget.dart
git commit -m "fix: keep overlays outside physical display cutouts"
```

### Task 2: Expand anchored popups from the target-facing edge

**Files:**
- Create: `test/super_overlay_popup_animation_test.dart`
- Modify: `lib/src/config/attach_dialog_config.dart`
- Modify: `lib/src/widget/animation/size_animation.dart`

**Step 1: Add failing default-animation and origin tests**

Create a popup test harness with one keyed target and show four popups in turn.
For each popup, find the `SizeTransition` ancestor of the keyed surface and
assert the axis and origin:

```dart
expect(const AttachDialogConfig().animationType, AnimationType.size);

OverlayHandle<void>? currentHandle;

Future<SizeTransition> openPopup(Alignment alignment) async {
  final handle = SuperOverlay.popup.show<void>(
    targetContext: targetContext,
    builder: (_) => const SizedBox(
      key: ValueKey('animated-popup'),
      width: 120,
      height: 80,
    ),
    options: OverlayPopupOptions(alignment: alignment),
  );
  currentHandle = handle;
  await tester.pump();
  final transition = find.ancestor(
    of: find.byKey(const ValueKey('animated-popup')),
    matching: find.byType(SizeTransition),
  );
  return tester.widget<SizeTransition>(transition);
}

Future<void> closeCurrentPopup() async {
  final handle = currentHandle;
  currentHandle = null;
  if (handle == null) {
    return;
  }
  final close = handle.close();
  await tester.pumpAndSettle();
  await close;
}

final below = await openPopup(Alignment.bottomCenter);
expect(below.axis, Axis.vertical);
expect(below.axisAlignment, -1);
await closeCurrentPopup();

final above = await openPopup(Alignment.topCenter);
expect(above.axis, Axis.vertical);
expect(above.axisAlignment, 1);
await closeCurrentPopup();

final right = await openPopup(Alignment.centerRight);
expect(right.axis, Axis.horizontal);
expect(right.axisAlignment, -1);
await closeCurrentPopup();

final left = await openPopup(Alignment.centerLeft);
expect(left.axis, Axis.horizontal);
expect(left.axisAlignment, 1);
await closeCurrentPopup();
```

The final test must close and settle each handle before opening the next popup,
so only one transition is present at a time.

**Step 2: Run the test to verify RED**

Run:

```bash
flutter test test/super_overlay_popup_animation_test.dart
```

Expected: FAIL because the default is `centerScaleOtherSlide` and no
`SizeTransition` is mounted.

**Step 3: Change the default and implement edge origins**

Set `AttachDialogConfig.animationType` to `AnimationType.size`. Update
`SizeAnimation` to pass an alignment-specific `axisAlignment`:

```dart
return SizeTransition(
  axis: _axis,
  axisAlignment: _axisAlignment,
  sizeFactor: controller,
  child: child,
);

double get _axisAlignment {
  if (alignment == Alignment.bottomLeft ||
      alignment == Alignment.bottomCenter ||
      alignment == Alignment.bottomRight ||
      alignment == Alignment.centerRight) {
    return -1;
  }
  if (alignment == Alignment.topLeft ||
      alignment == Alignment.topCenter ||
      alignment == Alignment.topRight ||
      alignment == Alignment.centerLeft) {
    return 1;
  }
  return 0;
}
```

**Step 4: Verify popup animation and geometry**

Run:

```bash
flutter test test/super_overlay_popup_animation_test.dart
flutter test test/super_overlay_popup_geometry_cases.dart
flutter test test/super_overlay_popup_anchor_tracking_test.dart
cd example && flutter test test/anchored_menu_panel_test.dart
```

Expected: all PASS. Final placement and moving-anchor tracking remain unchanged.

**Step 5: Commit**

```bash
git add test/super_overlay_popup_animation_test.dart \
  lib/src/config/attach_dialog_config.dart \
  lib/src/widget/animation/size_animation.dart
git commit -m "fix: reveal anchored popups from their target edge"
```

### Task 3: Remove integration controls from the first card

**Files:**
- Modify: `example/test/instant_feedback_panel_test.dart`
- Modify: `example/lib/showcase/instant_feedback_panel.dart`

**Step 1: Add the failing home-card contract**

Extend the panel test after `pumpWidget`:

```dart
expect(find.textContaining('refreshActive'), findsNothing);
expect(find.textContaining('handle.refresh()'), findsNothing);
expect(find.text('创建两类刷新 Toast'), findsNothing);
expect(
  find.byKey(const ValueKey('feedback-notification-selector')),
  findsOneWidget,
);
```

**Step 2: Run the test to verify RED**

Run:

```bash
cd example && flutter test test/instant_feedback_panel_test.dart
```

Expected: FAIL because the first card still renders refresh integration actions.

**Step 3: Remove the duplicated integration demo**

Delete from `InstantFeedbackPanel`:

- `_refreshActiveToastTag` and `_handleOwnedToastTag`;
- `_handleOwnedToast`, `_refreshActiveRevision`, and `_handleRevision`;
- the complete refresh-contract UI block between the status banner and divider;
- `_createRefreshDemo`, `_runRefreshActive`, `_showRefreshActiveToast`, and
  `_refreshHandleContent`;
- refresh-handle cleanup from `dispose`.

Retain the Toast policy status banner and the notification selector/action.

**Step 4: Run the test to verify GREEN**

Run:

```bash
cd example && flutter test test/instant_feedback_panel_test.dart
```

Expected: PASS.

**Step 5: Commit**

```bash
git add example/test/instant_feedback_panel_test.dart \
  example/lib/showcase/instant_feedback_panel.dart
git commit -m "refactor(example): focus feedback card on user scenarios"
```

### Task 4: Translate the complete example application to English

**Files:**
- Create: `example/test/english_copy_test.dart`
- Modify: `example/lib/network_state/data/fake_catalog_remote_data_source.dart`
- Modify: `example/lib/network_state/presentation/network_state_demo_page.dart`
- Modify: `example/lib/network_state/presentation/network_state_widgets.dart`
- Modify: `example/lib/showcase/advanced_popup_panel.dart`
- Modify: `example/lib/showcase/anchored_menu_panel.dart`
- Modify: `example/lib/showcase/dialog_demo_panel.dart`
- Modify: `example/lib/showcase/guided_mask_panel.dart`
- Modify: `example/lib/showcase/instant_feedback_panel.dart`
- Modify: `example/lib/showcase/lifecycle_demo_page.dart`
- Modify: `example/lib/showcase/nested_navigation_demo_page.dart`
- Modify: `example/lib/showcase/overlay_control_lab_page.dart`
- Modify: `example/lib/showcase/showcase_home_page.dart`
- Modify: `example/lib/showcase/showcase_overlay_surfaces.dart`
- Modify: every `example/test/*.dart` file whose assertions reference translated copy

**Step 1: Add a failing English-only source guard**

Create `example/test/english_copy_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('example application source contains no Han characters', () {
    final sourceFiles =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'));
    final han = RegExp(r'[\u3400-\u9fff]');
    final violations = <String>[];

    for (final file in sourceFiles) {
      if (han.hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty, reason: 'Untranslated source: $violations');
  });
}
```

**Step 2: Run the guard to verify RED**

Run:

```bash
cd example && flutter test test/english_copy_test.dart
```

Expected: FAIL and list the 13 untranslated source files.

**Step 3: Translate by scenario, preserving API identifiers**

Use these final headings and action labels consistently:

- Home: `Common Scenarios`, `Interaction Guidance`, `Advanced Capabilities`,
  `Open Network State Demo`, `Open Lifecycle Demo`, `Open Control Lab`, and
  `Open Nested Navigator Demo`.
- Instant feedback: `Instant Feedback`, `Toast Display Policy`,
  `Replace Latest`, `Queue`, `Stack`, `Run Toast Demo`, `Top Notification`,
  `Notification Type`, and `Show Notification`.
- Anchored menus: `Anchored Menus`, `Sort By`, `Newest`, `Price: Low to High`,
  `Top Rated`, `Attachment Source`, `Message`, `Add Attachment`, `Camera`,
  `Photo Library`, and `Choose File`.
- Dialog and guide: `Custom Dialog`, `Open Confirmation Dialog`,
  `Confirm this action?`, `Cancel`, `Confirm`, `Guided Highlight`, `Start Guide`,
  and `Step 1` / `Step 2` / `Step 3`.
- Network state: `Global Request Feedback`, `Success`, `Empty`, `Failure`,
  `Load Data`, `Page-owned States`, `Waiting to Load`, `Load Failed`, `No Data`,
  `Reload`, `Image Loading`, `Image Loaded`, and `Image Failed`.
- Lifecycle: `Route Binding`, `Widget Binding`, `Back Handling`,
  `Show Route-bound Dialog`, `Push Covering Route`, `Show Widget-bound Dialog`,
  `Remove Target Widget`, and `Restore Target Widget`.
- Control lab and advanced popup copy must be natural English while preserving
  literal API tokens such as `replaceExisting`, `keepExisting`,
  `refreshActive`, `handle.refresh()`, `handle.close()`, and `await handle.closed`.
- Nested navigation must preserve `SuperOverlayIntegration`,
  `navigatorObserver()`, and scoped-overlay terminology.

Translate status messages, overlay body copy, fake product data, empty/error
descriptions, image-state labels, and semantics/tooltips—not only headings.

**Step 4: Update behavioral tests to the displayed English copy**

Replace Chinese `find.text(...)`, `find.textContaining(...)`, and expected
status values in these tests:

```text
example/test/anchored_menu_panel_test.dart
example/test/back_behavior_demo_test.dart
example/test/dialog_result_test.dart
example/test/guided_mask_panel_test.dart
example/test/instant_feedback_panel_test.dart
example/test/nested_navigation_demo_test.dart
example/test/overlay_control_lab_test.dart
example/test/showcase_home_layout_test.dart
example/test/widget_test.dart
```

Do not weaken geometry, lifecycle, replacement, focus, or result assertions.

**Step 5: Run the guard and example suite to verify GREEN**

Run:

```bash
cd example
flutter test test/english_copy_test.dart
flutter test
rg -n "[\x{4e00}-\x{9fff}]" lib test -g '*.dart'
```

Expected: both test commands PASS. `rg` returns no matches.

**Step 6: Commit**

```bash
git add example/lib example/test
git commit -m "feat(example): present all showcase content in English"
```

### Task 5: Run the complete verification gate

**Files:**
- Modify only if a verification failure exposes a scoped regression

**Step 1: Format check**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test example/lib example/test
```

Expected: exit 0 with no changed files.

**Step 2: Package checks**

Run:

```bash
flutter analyze
flutter test
```

Expected: analysis reports no issues and all package tests pass.

**Step 3: Example checks**

Run:

```bash
cd example
flutter analyze
flutter test
flutter build web
```

Expected: analysis, all example tests, and the web build pass.

**Step 4: Diff and requirement audit**

Run:

```bash
git diff --check
rg -n "[\x{4e00}-\x{9fff}]" example/lib example/test -g '*.dart'
git status --short
```

Expected: no whitespace errors, no Han-character matches, and only intentional
implementation changes if they have not yet been committed.

**Step 5: Review the four acceptance criteria**

Confirm from tests and code:

1. top notifications use physical cutout padding plus the example's visual gap;
2. the entire example is English-only;
3. the first card contains no refresh/handle integration controls;
4. anchored popup size animation expands away from the target edge.
