# Example Command Contracts Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a runnable example page that demonstrates the command API's lifecycle, tag strategy, lookup, toast refresh, notification, and cleanup contracts.

**Architecture:** Add a self-contained stateful demo page reached from one new home-page panel. The page calls only the public `SuperOverlay` API and exposes deterministic status text for widget tests.

**Tech Stack:** Flutter, Dart, `super_overlay`, `flutter_test`

---

### Task 1: Specify the interactive contract flow

**Files:**
- Modify: `example/test/widget_test.dart`

**Step 1: Write the failing test**

Add a widget test that opens `Command Contracts`, verifies the four sections, exercises `Show owned handle` and `Close owned handle`, checks tagged replace behavior, refreshes an active toast, triggers all notification variants, and runs global cleanup.

**Step 2: Run test to verify it fails**

Run: `cd example && flutter test test/widget_test.dart --plain-name "command contracts page demonstrates public lifecycle APIs"`

Expected: FAIL because the `Command Contracts` entry does not exist.

### Task 2: Add the command contracts page

**Files:**
- Create: `example/lib/showcase/command_contracts_demo_page.dart`
- Modify: `example/lib/showcase/showcase_home_page.dart`

**Step 1: Implement the page state**

Store an `OverlayHandle<void>?` for the owned dialog, a refresh counter, and a status string. Guard asynchronous `setState` calls with `mounted`.

**Step 2: Implement public API actions**

Use stable tags and the public API:

```dart
SuperOverlay.dialog.show<void>(
  builder: (_) => const Text('Replacement winner'),
  options: const OverlayDialogOptions(
    tag: 'contracts-strategy',
    strategy: OverlayStrategy.replaceExisting,
  ),
);

final exists = SuperOverlay.exists(tag: 'contracts-owned');
await SuperOverlay.close(target: OverlayCloseTarget.all, force: true);
```

Add equivalent controls for stack, keep-existing, handle refresh/close, `refreshActive` toast, and all five notification methods.

**Step 3: Add the home-page entry**

Import the page, add a `Command Contracts` feature panel, and navigate with the existing `_pushPage` helper.

**Step 4: Run focused analysis and test**

Run: `cd example && flutter analyze && flutter test test/widget_test.dart --plain-name "command contracts page demonstrates public lifecycle APIs"`

Expected: analysis clean and test PASS.

### Task 3: Verify and commit the example

**Files:**
- Test: `example/test/widget_test.dart`
- Verify: all files under `example/lib/`

**Step 1: Run all example tests**

Run: `cd example && flutter test`

Expected: all tests PASS.

**Step 2: Check formatting and diff**

Run: `dart format --output=none --set-exit-if-changed example/lib example/test && git diff --check`

Expected: both commands exit 0.

**Step 3: Commit**

```bash
git add example/lib/showcase/command_contracts_demo_page.dart example/lib/showcase/showcase_home_page.dart example/test/widget_test.dart docs/plans/2026-07-09-example-command-contracts.md
git commit -m "feat: demonstrate command API contracts"
```
