# SuperOverlay Example Experience Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the API-first showcase home with scenario-first feedback and anchored-menu demos, move lifecycle controls into an understandable advanced lab, and prove notification safe-area behavior.

**Architecture:** Keep `ShowcaseHomePage` as a section composer and move interactive state into focused panels. Reuse the package's command API without adding a state-management dependency; every panel owns and cleans up its handles and tags. Preserve technical popup and lifecycle coverage in advanced pages while keeping common scenarios on the home page.

**Tech Stack:** Flutter 3.29+, Dart 3.7+, Material 3, `flutter_test`, SuperOverlay command APIs.

---

## Execution Phases

Execute sequentially because the tasks share `showcase_home_page.dart`, shared
surfaces, and example integration tests.

- **Phase A — behavior:** Tasks 1-4 fix notification spacing, feedback
  semantics, popup anchoring, and the control lab. Stop for a checkpoint after
  Task 4.
- **Phase B — structure and documentation:** Tasks 5-6 remove the global status
  panel, reorganize the home page, add responsive coverage, and update docs.
- **Release gate:** Task 7 runs only after both phases are green.

Implementation must preserve overlays owned outside each demo. In particular,
do not use `OverlayToastDisplayPolicy.refreshActive` for the control-lab upload:
its first activation intentionally resets the global toast deck. Use a tagged
stack toast with `OverlayStrategy.replaceExisting`, then update the owned
surface through `OverlayHandle.refresh()`.

### Task 1: Prove and polish notification safe-area behavior

**Files:**
- Modify: `test/super_overlay_notify_cases.dart`
- Modify: `example/test/widget_test.dart`
- Modify: `example/lib/showcase/showcase_app.dart`

**Step 1: Add a core safe-area regression test**

Add this case to `registerNotifyOverlayTests()`:

```dart
testWidgets('every custom notify stays below display cutout padding', (
  tester,
) async {
  tester.view.padding = const FakeViewPadding(top: 44);
  addTearDown(tester.view.resetPadding);

  Widget surface(OverlayNotificationType type, String message) {
    return Container(
      key: ValueKey('safe-notify-${type.name}'),
      child: Text(message),
    );
  }

  await tester.pumpWidget(
    buildNotifyOverlayApp(
      const SizedBox.shrink(),
      notifyStyle: NotifyStyle(
        successBuilder:
            (message) => surface(OverlayNotificationType.success, message),
        failureBuilder:
            (message) => surface(OverlayNotificationType.failure, message),
        warningBuilder:
            (message) => surface(OverlayNotificationType.warning, message),
        errorBuilder:
            (message) => surface(OverlayNotificationType.error, message),
        alertBuilder:
            (message) => surface(OverlayNotificationType.alert, message),
      ),
    ),
  );

  final handles = [
    SuperOverlay.notify.success('success'),
    SuperOverlay.notify.failure('failure'),
    SuperOverlay.notify.warning('warning'),
    SuperOverlay.notify.error('error'),
    SuperOverlay.notify.alert('alert'),
  ];
  for (final type in OverlayNotificationType.values) {
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(ValueKey('safe-notify-${type.name}'))).dy,
      greaterThanOrEqualTo(44),
    );
  }
  await SuperOverlay.close(
    target: OverlayCloseTarget.allNotifications,
    force: true,
  );
  await Future.wait(handles.map((handle) => handle.closed));
});
```

This test is diagnostic: it should pass with the existing shared `SafeArea`. If
it fails, stop and fix the overlay host before touching example styling.

**Step 2: Run the core regression**

Run:

```bash
flutter test test/super_overlay_notify_cases.dart \
  --plain-name "every custom notify stays below display cutout padding"
```

Expected: PASS. If it fails, inspect the `MediaQuery` inherited by
`OverlayDialogWidget` and make the smallest core fix before continuing.

**Step 3: Add the failing example visual-gap test**

Add a test to `example/test/widget_test.dart` that sets the same 44-pixel top
padding, directly opens all five example notification styles, and measures each
keyed decorated surface rather than its padded text:

```dart
testWidgets('custom notify keeps a visual gap below the safe area', (
  tester,
) async {
  tester.view.padding = const FakeViewPadding(top: 44);
  addTearDown(tester.view.resetPadding);

  await tester.pumpWidget(const MyApp());
  final handles = [
    SuperOverlay.notify.success('success'),
    SuperOverlay.notify.failure('failure'),
    SuperOverlay.notify.warning('warning'),
    SuperOverlay.notify.error('error'),
    SuperOverlay.notify.alert('alert'),
  ];

  for (final type in OverlayNotificationType.values) {
    await tester.pump();
    final surface = find.byKey(ValueKey('init-notify-${type.name}'));
    expect(surface, findsOneWidget);
    expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(56));
  }

  await SuperOverlay.close(
    target: OverlayCloseTarget.allNotifications,
    force: true,
  );
  await Future.wait(handles.map((handle) => handle.closed));
});
```

**Step 4: Run the example test and verify the failure**

Run:

```bash
cd example
flutter test test/widget_test.dart \
  --plain-name "custom notify keeps a visual gap below the safe area"
```

Expected: FAIL because only success has an init-level custom builder and that
surface starts at the safe-area edge instead of 12 pixels below it.

**Step 5: Add the example-only visual inset**

Replace the success-only builder with one shared type-aware builder and register
it for every `NotifyStyle` variant in `example/lib/showcase/showcase_app.dart`:

```dart
notifyStyle: NotifyStyle(
  successBuilder:
      (message) => _notifyBuilder(OverlayNotificationType.success, message),
  failureBuilder:
      (message) => _notifyBuilder(OverlayNotificationType.failure, message),
  warningBuilder:
      (message) => _notifyBuilder(OverlayNotificationType.warning, message),
  errorBuilder:
      (message) => _notifyBuilder(OverlayNotificationType.error, message),
  alertBuilder:
      (message) => _notifyBuilder(OverlayNotificationType.alert, message),
),

Widget _notifyBuilder(OverlayNotificationType type, String message) {
  final colors = switch (type) {
    OverlayNotificationType.success =>
      (const Color(0xFFEFF6EE), const Color(0xFF2E7D32)),
    OverlayNotificationType.failure =>
      (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    OverlayNotificationType.warning =>
      (const Color(0xFFFFF7ED), const Color(0xFFB45309)),
    OverlayNotificationType.error =>
      (const Color(0xFFFFF1F2), const Color(0xFFBE123C)),
    OverlayNotificationType.alert =>
      (const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
  };
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DecoratedBox(
      key: ValueKey('init-notify-${type.name}'),
      decoration: BoxDecoration(
        color: colors.$1,
        border: Border.all(color: colors.$2.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(message, style: TextStyle(color: colors.$2)),
      ),
    ),
  );
}
```

Do not add a new public option while the core test proves the package already
respects safe padding.

**Step 6: Run both regressions**

Run:

```bash
flutter test test/super_overlay_notify_cases.dart \
  --plain-name "every custom notify stays below display cutout padding"
cd example
flutter test test/widget_test.dart \
  --plain-name "custom notify keeps a visual gap below the safe area"
```

Expected: both PASS.

**Step 7: Commit**

```bash
git add test/super_overlay_notify_cases.dart \
  example/test/widget_test.dart \
  example/lib/showcase/showcase_app.dart
git commit -m "fix(example): keep notifications below display cutouts"
```

### Task 2: Replace Toast Deck with the instant-feedback scenario

**Files:**
- Create: `example/lib/showcase/instant_feedback_panel.dart`
- Create: `example/test/instant_feedback_panel_test.dart`
- Modify: `example/lib/showcase/showcase_home_page.dart`
- Modify: `example/lib/showcase/showcase_home_actions.dart`
- Modify: `example/lib/showcase/showcase_widgets.dart`
- Modify: `example/test/widget_test.dart`

**Step 1: Write the failing panel test**

Create `example/test/instant_feedback_panel_test.dart` and pump `MyApp`. Verify
the three policies, the single run action, and notification replacement:

```dart
testWidgets('instant feedback separates policy state from actions', (
  tester,
) async {
  await tester.pumpWidget(const MyApp());

  expect(find.text('即时反馈'), findsOneWidget);
  expect(find.text('替换最新'), findsOneWidget);
  expect(find.text('依次排队'), findsOneWidget);
  expect(find.text('同时显示'), findsOneWidget);
  expect(find.text('运行 Toast 演示'), findsOneWidget);

  await tester.tap(find.text('运行 Toast 演示'));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('保存结果 3'), findsOneWidget);
  expect(find.text('保存结果 1'), findsNothing);

  await SuperOverlay.close(target: OverlayCloseTarget.allToasts, force: true);
  await tester.pumpAndSettle();
});
```

Add separate cases that select `依次排队` and observe file 1 before file 2,
select `同时显示` and observe all three task labels, then change notification
type twice and assert only the latest notification remains.

**Step 2: Run the new test to verify it fails**

Run:

```bash
cd example
flutter test test/instant_feedback_panel_test.dart
```

Expected: FAIL because `即时反馈` and its scenario controls do not exist.

**Step 3: Add a reusable local status banner**

Add to `example/lib/showcase/showcase_widgets.dart`:

```dart
class DemoStatusBanner extends StatelessWidget {
  const DemoStatusBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ShowcaseColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ShowcaseColors.border),
        ),
        child: Text(message),
      ),
    );
  }
}
```

**Step 4: Implement the instant-feedback panel**

Create a stateful `InstantFeedbackPanel` with:

```dart
enum ToastDemoPolicy { replaceLatest, queue, stack }

const _feedbackNotifyTag = 'showcase-feedback-notify';

class InstantFeedbackPanel extends StatefulWidget {
  const InstantFeedbackPanel({super.key});

  @override
  State<InstantFeedbackPanel> createState() =>
      _InstantFeedbackPanelState();
}
```

Use `SegmentedButton<ToastDemoPolicy>` for the three real modes and one filled
`运行 Toast 演示` button. Map the modes as follows:

```dart
void _runToastDemo() {
  switch (_policy) {
    case ToastDemoPolicy.replaceLatest:
      for (var index = 1; index <= 3; index++) {
        SuperOverlay.toast(
          '保存结果 $index',
          options: const OverlayToastOptions(
            displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
          ),
        );
      }
      return;
    case ToastDemoPolicy.queue:
      for (var index = 1; index <= 3; index++) {
        SuperOverlay.toast(
          '文件 $index 已上传',
          options: const OverlayToastOptions(
            displayPolicy: OverlayToastDisplayPolicy.queue,
            displayDuration: Duration(milliseconds: 900),
          ),
        );
      }
      return;
    case ToastDemoPolicy.stack:
      for (final message in ['后台同步完成', '权限校验通过', '缓存预热完成']) {
        SuperOverlay.toast(
          message,
          options: const OverlayToastOptions(
            displayPolicy: OverlayToastDisplayPolicy.stack,
            alignment: Alignment.topRight,
          ),
        );
      }
      return;
  }
}
```

Use `DropdownButtonFormField<OverlayNotificationType>` for the five notification
types. Route the chosen value to the matching notify service. Every call uses:

```dart
const OverlayNotifyOptions(
  tag: _feedbackNotifyTag,
  strategy: OverlayStrategy.replaceExisting,
  displayDuration: Duration(seconds: 3),
)
```

Show the selected policy or notification result in `DemoStatusBanner`.

**Step 5: Replace the old Toast panel**

Import and place `const InstantFeedbackPanel()` from
`showcase_home_page.dart`. Remove `_buildToastPanel` and the old home actions for
single, queued, multi, default toast, default loading, and default notify. Keep
network loading in `NetworkStateDemoPage`.

The Task 1 visual-gap test is independent of home-page labels and needs no
follow-up change here.

**Step 6: Run focused and existing example tests**

Run:

```bash
cd example
flutter test test/instant_feedback_panel_test.dart
flutter test test/widget_test.dart
```

Expected: PASS. The old test assertions for removed Toast buttons must be
replaced with the new scenario labels and outcomes.

**Step 7: Commit**

```bash
git add example/lib/showcase/instant_feedback_panel.dart \
  example/lib/showcase/showcase_home_page.dart \
  example/lib/showcase/showcase_home_actions.dart \
  example/lib/showcase/showcase_widgets.dart \
  example/test/instant_feedback_panel_test.dart \
  example/test/widget_test.dart
git commit -m "feat(example): redesign instant feedback scenarios"
```

### Task 3: Add real dropdown and upward anchored menus

**Files:**
- Create: `example/lib/showcase/anchored_menu_panel.dart`
- Create: `example/test/anchored_menu_panel_test.dart`
- Modify: `example/lib/showcase/showcase_home_page.dart`
- Modify: `example/lib/showcase/showcase_home_actions.dart`
- Modify: `example/lib/showcase/showcase_overlay_surfaces.dart`
- Modify: `example/test/widget_test.dart`

**Step 1: Write failing geometry and selection tests**

Create `example/test/anchored_menu_panel_test.dart` with two cases. The dropdown
case must measure exact keyed render boxes:

```dart
testWidgets('sort menu opens below its own trigger and applies selection', (
  tester,
) async {
  await tester.pumpWidget(const MyApp());
  final trigger = find.byKey(const ValueKey('sort-menu-trigger'));

  await tester.ensureVisible(trigger);
  await tester.tap(trigger);
  await tester.pumpAndSettle();

  final popup = find.byKey(const ValueKey('sort-menu-popup'));
  expect(
    tester.getTopLeft(popup).dy,
    greaterThanOrEqualTo(tester.getBottomLeft(trigger).dy),
  );

  await tester.tap(find.text('评分最高'));
  await tester.pumpAndSettle();
  expect(popup, findsNothing);
  expect(find.text('当前排序：评分最高'), findsOneWidget);
});
```

The upward-menu case asserts
`tester.getBottomLeft(popup).dy <= tester.getTopLeft(trigger).dy`, chooses
`从相册选择`, and verifies the local result.

**Step 2: Run the tests and verify they fail**

Run:

```bash
cd example
flutter test test/anchored_menu_panel_test.dart
```

Expected: FAIL because the keyed triggers and realistic menus do not exist.

**Step 3: Implement `AnchoredMenuPanel`**

Build each trigger inside its own `Builder`:

```dart
Builder(
  builder:
      (targetContext) => InkWell(
        onTap: () => _showSortMenu(targetContext),
        child: Container(
          key: const ValueKey('sort-menu-trigger'),
          // input-like decoration and current value
        ),
      ),
)
```

Create the dropdown with the exact trigger context and target width:

```dart
late final OverlayHandle<void> handle;
handle = SuperOverlay.popup.show<void>(
  targetContext: targetContext,
  builder: (_) => const SizedBox.shrink(),
  options: OverlayPopupOptions(
    tag: 'showcase-sort-menu',
    strategy: OverlayStrategy.replaceExisting,
    alignment: Alignment.bottomCenter,
    replacementBuilder:
        (info) => SizedBox(
          key: const ValueKey('sort-menu-popup'),
          width: info.targetSize.width,
          child: AnchoredMenuSurface(
            items: const ['最新发布', '价格从低到高', '评分最高'],
            onSelected: (value) {
              setState(() => _sort = value);
              unawaited(handle.close());
            },
          ),
        ),
  ),
);
```

Use the same pattern for `attachment-menu-trigger`, with
`Alignment.topCenter` and camera, gallery, and file actions. Track active
handles and close them from `dispose()`.

Add `AnchoredMenuSurface` to `showcase_overlay_surfaces.dart` or keep it private
to the new panel if it has no other consumer.

**Step 4: Replace the old popup playground on the home page**

Place `const AnchoredMenuPanel()` in the common-scenarios section. Remove the
old placement selector, choice popup, and its state from the home page/actions.
Do not delete the technical geometry action implementations until Task 4 moves
them to the advanced lab.

**Step 5: Run focused and smoke tests**

Run:

```bash
cd example
flutter test test/anchored_menu_panel_test.dart
flutter test test/widget_test.dart
```

Expected: PASS, including explicit above/below coordinate assertions.

**Step 6: Commit**

```bash
git add example/lib/showcase/anchored_menu_panel.dart \
  example/lib/showcase/showcase_home_page.dart \
  example/lib/showcase/showcase_home_actions.dart \
  example/lib/showcase/showcase_overlay_surfaces.dart \
  example/test/anchored_menu_panel_test.dart \
  example/test/widget_test.dart
git commit -m "feat(example): add anchored menu scenarios"
```

### Task 4: Replace Command Contracts with the overlay control lab

**Files:**
- Create: `example/lib/showcase/overlay_control_lab_page.dart`
- Create: `example/lib/showcase/advanced_popup_panel.dart`
- Create: `example/test/overlay_control_lab_test.dart`
- Delete: `example/lib/showcase/command_contracts_demo_page.dart`
- Modify: `example/lib/showcase/showcase_home_page.dart`
- Modify: `example/lib/showcase/showcase_overlay_surfaces.dart`
- Modify: `example/test/widget_test.dart`

**Step 1: Write failing strategy tests**

Create `example/test/overlay_control_lab_test.dart`. Navigate through
`打开控制实验室`, then verify:

```dart
expect(find.text('Overlay 控制实验室'), findsWidgets);
expect(find.text('重复触发应该怎样处理？'), findsOneWidget);
expect(find.text('已经显示的 Overlay 怎样控制？'), findsOneWidget);
expect(find.text('等待生命周期'), findsOneWidget);
```

Add separate tests for:

- `允许多个`: both `登录提示 #1` and `登录提示 #2` exist.
- `保留已有`: only `登录提示 #1` exists.
- `替换已有`: only `登录提示 #2` remains after settling.
- Upload handle: start, wait for visible, refresh progress, close, and observe
  `exists(tag): false`.
- Starting and refreshing the upload handle preserves an externally owned
  stacked toast.
- Await timeline: created, visible, closed, and completed events appear in
  order.
- Page disposal preserves an externally owned toast.

**Step 2: Run the tests and verify they fail**

Run:

```bash
cd example
flutter test test/overlay_control_lab_test.dart
```

Expected: FAIL because the scenario-first control lab does not exist.

**Step 3: Implement repeated-trigger strategy**

Create `OverlayControlLabPage` with a segmented `OverlayStrategy` selector and
one `模拟连续触发两次` action. Use business tag `control-lab-auth`.

Before each run, close prior matching dialogs. Then issue two calls with the
selected strategy. Each dialog must label its revision. Show a local
`DemoStatusBanner` describing the expected observable result.

Do not offset or cosmetically fake stack behavior. For stack, both widgets may
occupy the same alignment; the teaching copy tells the user that closing the
top reveals the first.

**Step 4: Implement the owned upload handle**

Use a long-lived non-consuming toast so page controls remain usable:

```dart
_uploadHandle = SuperOverlay.toast(
  '上传进度 $_uploadProgress%',
  builder:
      (_) => ToastSurface(
        icon: Icons.cloud_upload_outlined,
        text: '上传进度 $_uploadProgress%',
        accent: ShowcaseColors.info,
      ),
  options: const OverlayToastOptions(
    tag: 'control-lab-upload',
    strategy: OverlayStrategy.replaceExisting,
    displayPolicy: OverlayToastDisplayPolicy.stack,
    displayDuration: Duration(minutes: 1),
  ),
);
```

Store the handle, await `visible`, update progress and call `refresh()`, then
close it from the cancel action. Disable update/cancel when no active handle
exists. Keep a local lifecycle state and show
`SuperOverlay.exists(tag: 'control-lab-upload')` in developer-facing code text.
The test must create an external stack toast before starting the upload and
assert that it remains visible after start, refresh, cancel, and page disposal.

**Step 5: Implement the awaited lifecycle timeline**

Create one tagged overlay and append local events when the handle is created,
`visible` completes, the overlay closes, and `closed` completes. Check
`mounted` before every state update. Make this local timeline the only event log
in the example.

**Step 6: Move technical popup cases into the advanced panel**

Create `AdvancedPopupPanel` and move these existing demonstrations without
changing their package behavior:

- targetless point popup;
- replacement and adjustment builder;
- scale-origin builder;
- mask-ignore area.

Every context-bound action gets its own `Builder`; do not reintroduce a shared
button-group target.

**Step 7: Add scoped and global cleanup**

The primary cleanup closes only `control-lab-*` handles/tags and advanced popup
tags. The global cleanup action must be in a danger-styled section and require
confirmation before calling:

```dart
await SuperOverlay.close(target: OverlayCloseTarget.all, force: true);
```

On `dispose`, run only scoped cleanup. Never call global cleanup during page
disposal.

**Step 8: Replace the old page and update tests**

Delete `command_contracts_demo_page.dart`, point the home navigation to
`OverlayControlLabPage`, and remove notification-gallery assertions from
`widget_test.dart`. Preserve equivalent regression coverage in the new focused
test.

**Step 9: Run the control-lab tests**

Run:

```bash
cd example
flutter test test/overlay_control_lab_test.dart
flutter test test/widget_test.dart
```

Expected: PASS. No `Show all notification types` action remains.

**Step 10: Commit**

```bash
git add example/lib/showcase/overlay_control_lab_page.dart \
  example/lib/showcase/advanced_popup_panel.dart \
  example/lib/showcase/showcase_home_page.dart \
  example/lib/showcase/showcase_overlay_surfaces.dart \
  example/test/overlay_control_lab_test.dart \
  example/test/widget_test.dart
git rm example/lib/showcase/command_contracts_demo_page.dart
git commit -m "feat(example): redesign overlay control lab"
```

### Task 5: Recompose the home page and remove global Live Status

**Files:**
- Create: `example/lib/showcase/dialog_demo_panel.dart`
- Create: `example/lib/showcase/guided_mask_panel.dart`
- Create: `example/test/showcase_home_layout_test.dart`
- Modify: `example/lib/showcase/showcase_home_page.dart`
- Modify: `example/lib/showcase/showcase_widgets.dart`
- Delete: `example/lib/showcase/showcase_home_actions.dart`
- Modify: `example/test/widget_test.dart`

**Step 1: Write the failing home-structure test**

Create `example/test/showcase_home_layout_test.dart`:

```dart
testWidgets('home is organized by scenarios and advanced links', (
  tester,
) async {
  await tester.pumpWidget(const MyApp());

  for (final label in ['常用场景', '交互增强', '高级能力']) {
    expect(find.text(label), findsOneWidget);
  }
  for (final removed in [
    'Live Status',
    'Await 事件',
    'Show all notification types',
    'Overlay modes',
    'Live log',
  ]) {
    expect(find.text(removed), findsNothing);
  }
  expect(find.byTooltip('Notify'), findsNothing);
});
```

**Step 2: Run the test and verify it fails**

Run:

```bash
cd example
flutter test test/showcase_home_layout_test.dart
```

Expected: FAIL because the current page still contains stats, global status,
and the app-bar notification action.

**Step 3: Extract dialog and guide state**

Move the current dialog switches/actions into `DialogDemoPanel`. Move guide
keys, active step, handle, and guide actions into `GuidedMaskPanel`. Each panel
owns its `setState`, checks `mounted` in asynchronous work, and closes its handle
from `dispose()`.

Reuse existing `DialogSurface`, `GuideTarget`, and `GuideBubble` widgets.

**Step 4: Add section widgets**

Add a small `ShowcaseSectionTitle` to `showcase_widgets.dart` and a responsive
two-column helper to the home page. Do not use a fixed-height `GridView` that
can overflow translated text. Use a `LayoutBuilder` that renders one `Column`
below 920 logical pixels and a `Row` of two `Expanded` children above it.

**Step 5: Rebuild `ShowcaseHomePage` as a composer**

Make the page stateless and order content as:

```text
ShowcaseHeader
常用场景
  InstantFeedbackPanel | AnchoredMenuPanel
  DialogDemoPanel       | Network State entry
交互增强
  GuidedMaskPanel
高级能力
  Lifecycle entry       | Overlay Control Lab entry
```

Remove `CapabilityStats`, `_events`, `_log`, `ActivityRow`, `StatPill`, the
app-bar notification action, and the Live Status panel. Delete
`showcase_home_actions.dart` after all surviving actions have owners.

Translate remaining English scenario titles while retaining code/API terms in
English.

**Step 6: Run home and integration tests**

Run:

```bash
cd example
flutter test test/showcase_home_layout_test.dart
flutter test test/widget_test.dart
```

Expected: PASS.

**Step 7: Commit**

```bash
git add example/lib/showcase/dialog_demo_panel.dart \
  example/lib/showcase/guided_mask_panel.dart \
  example/lib/showcase/showcase_home_page.dart \
  example/lib/showcase/showcase_widgets.dart \
  example/test/showcase_home_layout_test.dart \
  example/test/widget_test.dart
git rm example/lib/showcase/showcase_home_actions.dart
git commit -m "refactor(example): organize showcase by development scenario"
```

### Task 6: Verify responsive layouts and update documentation

**Files:**
- Create: `example/test/responsive_layout_test.dart`
- Create: `tool/verification/example_device_matrix.md`
- Modify: `example/README.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Step 1: Write responsive tests**

Create a helper that sets a one-to-one test view and resets it afterward:

```dart
Future<void> pumpAtWidth(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}
```

At 320, 600, and 1200 pixels, visit or reveal every home section and assert
`tester.takeException()` is null. At 1200, assert the first two common-scenario
panels have different horizontal positions and approximately equal top
positions. At 320, assert they share the same horizontal origin and the second
starts below the first. Add stable keys to the panel roots:

```dart
const ValueKey('instant-feedback-panel')
const ValueKey('anchored-menu-panel')
const ValueKey('dialog-demo-panel')
const ValueKey('network-state-panel')
```

Geometry tests must locate these keys instead of relying on translated text or
widget order.

**Step 2: Run the responsive test and fix only real layout failures**

Run:

```bash
cd example
flutter test test/responsive_layout_test.dart
```

Expected: PASS after adjusting flexible widths, segmented controls, and text
wrapping. Do not silence overflow by clipping content.

**Step 3: Rewrite example documentation**

Update `example/README.md` to describe:

- scenario-first home sections;
- instant-feedback policies;
- anchored dropdown and upward menus;
- lifecycle page;
- overlay control lab and advanced geometry;
- the distinction between widget tests and real cutout-device checks.

Update the root README's Example section to use the new page names. Replace the
old Unreleased changelog bullet about Command Contracts with a bullet covering
the scenario-first example, control lab, popup anchoring, and notification
safe-area regression.

**Step 4: Add the manual device matrix**

Create `tool/verification/example_device_matrix.md` with unchecked rows for:

- iPhone notch/Dynamic Island portrait and landscape;
- edge-to-edge Android cutout portrait and landscape;
- popup after scrolling;
- upward menu with the keyboard visible;
- notification with the keyboard visible.

Record that automation verifies simulated padding but does not constitute real
device proof. A completed implementation may report automated acceptance as
green while this matrix remains pending, but it must not claim the reported
cutout issue is verified on hardware until at least one iPhone and one Android
cutout device are checked.

**Step 5: Run documentation and example checks**

Run:

```bash
dart format --output=none --set-exit-if-changed example/lib example/test
cd example
flutter analyze
flutter test
```

Expected: no formatting changes, no analysis issues, all example tests pass.

**Step 6: Commit**

```bash
git add example/test/responsive_layout_test.dart \
  tool/verification/example_device_matrix.md \
  example/README.md README.md CHANGELOG.md
git commit -m "docs: update scenario-first example guide"
```

### Task 7: Run the complete release-quality gate

**Files:**
- No expected source changes

**Step 1: Check formatting**

Run:

```bash
dart format --output=none --set-exit-if-changed .
```

Expected: exit 0 and zero files changed.

**Step 2: Analyze and test the package**

Run:

```bash
flutter analyze
flutter test --coverage
```

Expected: no issues and all package tests pass.

**Step 3: Analyze and test the example**

Run:

```bash
cd example
flutter analyze
flutter test
```

Expected: no issues and all example tests pass.

**Step 4: Build both verified example targets**

Run:

```bash
cd example
flutter build macos --debug
flutter build web
```

Expected: both builds complete successfully.

**Step 5: Re-run package documentation and publish checks**

Run:

```bash
dart doc --dry-run
flutter pub publish --dry-run
```

Expected: documentation has no warnings or errors. Publish dry-run has no
package-content warnings; a dirty-git warning is acceptable only if the plan is
being executed before its final commit.

**Step 6: Review the final diff and repository state**

Run:

```bash
git diff --check
git status --short --branch
git log --oneline -8
```

Expected: no whitespace errors, only intentional files changed, and the planned
atomic commits are present. Report the manual iOS/Android device matrix as
pending unless it was actually completed on real hardware.
