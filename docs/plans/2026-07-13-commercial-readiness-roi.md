# SuperOverlay Commercial Readiness ROI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the highest-ROI runtime and release-contract gaps, prepare a coherent `0.3.0` candidate, and leave real-device verification as the final manual gate.

**Architecture:** Preserve the existing single-host `OverlayEntry` runtime, host generations, Navigator scope registry, and serialized replacement queue. Narrow route ownership to Route/scope identity, validate close results before queue mutation, make replacement semantics uniform, and derive accessibility modality from event consumption rather than adding new public policy types.

**Tech Stack:** Dart 3.7+, Flutter 3.29+, `flutter_test`, go_router 14.8.1 as a dev-only fixture, GitHub Actions, LCOV.

---

## Execution Rules

- Work only on `codex/commercial-readiness-roi` in its dedicated worktree.
- Use `superpowers:test-driven-development` for every runtime or behavior
  change. Record the expected red result before production edits.
- Commit each task separately. Do not mix version metadata with runtime fixes.
- Do not add public features, compatibility shims, or a global keyboard
  dispatcher.
- Do not mark any device row complete without the maintainer's manual result.
- Do not publish, create the stable version tag, or claim release completion.

### Task 1: Make Scoped Ownership Independent Of Invocation Widget Lifetime

**Files:**

- Modify: `lib/src/helper/overlay_route_owner.dart`
- Modify: `lib/src/helper/navigator_scope_registry.dart`
- Modify: `lib/src/helper/overlay_manager_lifecycle.dart`
- Modify: `test/super_overlay_nested_navigation_test.dart`

**Step 1: Change the existing regression into the desired contract**

Rename `unmounted invocation context closes its scoped overlay` to
`unmounted invocation widget keeps its route-scoped overlay`. After removing
the invocation child, assert that the route-scoped dialog remains visible and
its `closed` future is incomplete. Then close it through the handle and verify
normal settlement.

Keep or add a separate `bindToWidget` test proving that explicit widget binding
still closes when the bound widget unmounts.

**Step 2: Run the focused test and verify RED**

```bash
flutter test test/super_overlay_nested_navigation_test.dart --plain-name 'unmounted invocation widget keeps its route-scoped overlay'
```

Expected: FAIL because the current frame monitor closes the overlay after the
captured invocation context unmounts.

**Step 3: Implement the minimal ownership correction**

- Remove `invocationContext` from `OverlayRouteOwner`.
- Stop passing a context from root and scoped owner capture.
- In `_handleWidgetBindingFrame`, treat a route-bound record as attached when
  `NavigatorScopeRegistry.isOwnerTracked(owner)` is true. Keep suspend/resume
  behavior based on `isOwnerCurrent(owner)`.
- Leave `record.bindWidget` monitoring unchanged.

**Step 4: Verify GREEN and regressions**

```bash
dart format lib/src/helper/overlay_route_owner.dart lib/src/helper/navigator_scope_registry.dart lib/src/helper/overlay_manager_lifecycle.dart test/super_overlay_nested_navigation_test.dart
flutter analyze
flutter test test/super_overlay_nested_navigation_test.dart
flutter test test/super_overlay_widget_binding_test.dart
```

Expected: all pass.

**Step 5: Commit**

```bash
git add lib/src/helper/overlay_route_owner.dart lib/src/helper/navigator_scope_registry.dart lib/src/helper/overlay_manager_lifecycle.dart test/super_overlay_nested_navigation_test.dart
git commit -m "fix: keep scoped overlays owned by their route"
```

### Task 2: Validate Typed Global Close Before Mutation

**Files:**

- Create: `test/super_overlay_global_close_type_test.dart`
- Modify: `lib/src/super_overlay_core.dart`
- Modify: `lib/src/custom/main_overlay.dart`
- Modify: `lib/src/helper/overlay_manager_dismiss.dart`

**Step 1: Add failing type-safety tests**

Create a typed `OverlayHandle<bool>` dialog and call:

```dart
await SuperOverlay.close<String>(
  target: OverlayCloseTarget.dialog,
  result: 'wrong',
);
```

Assert that the future throws `StateError`, the dialog stays visible, and the
original handle can still close with `true`. Also assert that a non-null result
with `allDialogs`, `allPopups`, `allNotifications`, `allToasts`, or `all` is
rejected before any overlay closes.

**Step 2: Run and verify RED**

```bash
flutter test test/super_overlay_global_close_type_test.dart
```

Expected: FAIL because the current implementation removes the record before
the completer discovers the incompatible result.

**Step 3: Implement preflight validation**

Add an internal method on `MainOverlay` equivalent to:

```dart
void validateDismissResult<T>({required String? tag, required T? result}) {
  if (result == null || _resultType == null || _resultType == T) return;
  throw StateError(
    'Overlay tag "${tag ?? '<unknown>'}" uses result type $_resultType '
    'and cannot be closed with $T.',
  );
}
```

Call it in `_closeSingle` before setting `closing`, removing the record, or
starting dismissal. In `SuperOverlay.close`, reject non-null results for bulk
targets before resolving a host generation.

**Step 4: Verify GREEN and related contracts**

```bash
dart format lib/src/super_overlay_core.dart lib/src/custom/main_overlay.dart lib/src/helper/overlay_manager_dismiss.dart test/super_overlay_global_close_type_test.dart
flutter analyze
flutter test test/super_overlay_global_close_type_test.dart test/super_overlay_tag_type_test.dart test/super_overlay_command_api_test.dart
```

Expected: all pass and a rejected close leaves the original handle usable.

**Step 5: Commit**

```bash
git add lib/src/super_overlay_core.dart lib/src/custom/main_overlay.dart lib/src/helper/overlay_manager_dismiss.dart test/super_overlay_global_close_type_test.dart
git commit -m "fix: validate global close result types"
```

### Task 3: Make `replaceExisting` Remove Every Same-Tag Match

**Files:**

- Modify: `lib/src/api/overlay_policy.dart`
- Modify: `lib/src/api/overlay_services.dart`
- Modify: `lib/src/helper/overlay_manager_dismiss.dart`
- Modify: `test/super_overlay_replacement_race_test.dart`

**Step 1: Add failing cross-surface replacement tests**

For dialog, popup, notification, and Toast:

1. Show two same-tag entries with `OverlayStrategy.stack`.
2. Show a third with `OverlayStrategy.replaceExisting`.
3. Assert both earlier handles close and only the replacement remains.

Retain existing same-turn serialization and canceled-replacement tests.

**Step 2: Run and verify RED**

```bash
flutter test test/super_overlay_replacement_race_test.dart
```

Expected: dialog/popup/notification cases fail because only the latest matching
record is closed; Toast already satisfies the desired behavior.

**Step 3: Implement uniform replacement**

- Document `replaceExisting` as closing every same-surface, same-tag match.
- Route replacement preparation through an all-matches dismissal for the
  selected `DismissStatus` and generation.
- Preserve the existing replacement serialization key and cancellation rules.
- Do not change ordinary singular global-close behavior.

**Step 4: Verify GREEN and race coverage**

```bash
dart format lib/src/api/overlay_policy.dart lib/src/api/overlay_services.dart lib/src/helper/overlay_manager_dismiss.dart test/super_overlay_replacement_race_test.dart
flutter analyze
flutter test test/super_overlay_replacement_race_test.dart test/super_overlay_command_api_test.dart test/super_overlay_internal_runtime_test.dart
flutter test --test-randomize-ordering-seed=20260713
```

Expected: all pass. This commit is the internal RC 1 checkpoint.

**Step 5: Commit**

```bash
git add lib/src/api/overlay_policy.dart lib/src/api/overlay_services.dart lib/src/helper/overlay_manager_dismiss.dart test/super_overlay_replacement_race_test.dart
git commit -m "fix: unify tagged replacement semantics"
```

### Task 4: Align Non-Modal Pointer And Semantics Behavior

**Files:**

- Modify: `lib/src/api/overlay_options.dart`
- Modify: `lib/src/builder/super_custom_overlay_builder.dart`
- Modify: `lib/src/widget/helper/overlay_accessibility_scope.dart`
- Modify: `test/super_overlay_accessibility_test.dart`
- Modify: `README.md`

**Step 1: Add a failing semantics regression**

Show a dialog with `consumeEvents: false`, a semantic label on the page, and a
semantic label in the dialog. Assert both labels remain in the semantics tree.
Retain the existing modal test that expects background semantics to be blocked.

**Step 2: Run and verify RED**

```bash
flutter test test/super_overlay_accessibility_test.dart --plain-name 'non-modal dialog preserves background semantics'
```

Expected: FAIL because the dialog always selects modal accessibility mode.

**Step 3: Implement and document the minimal policy**

- Select non-modal accessibility mode when `consumeEvents` is false.
- Keep modal focus trapping and `BlockSemantics` unchanged when it is true.
- Clarify that `requestFocus: false` leaves keyboard focus with the page and
  that overlay Escape handling requires focus inside the overlay.
- Do not add a host-level keyboard dispatcher.

**Step 4: Verify GREEN**

```bash
dart format lib/src/api/overlay_options.dart lib/src/builder/super_custom_overlay_builder.dart lib/src/widget/helper/overlay_accessibility_scope.dart test/super_overlay_accessibility_test.dart
flutter analyze
flutter test test/super_overlay_accessibility_test.dart
```

Expected: modal and non-modal semantics contracts both pass.

**Step 5: Commit**

```bash
git add lib/src/api/overlay_options.dart lib/src/builder/super_custom_overlay_builder.dart lib/src/widget/helper/overlay_accessibility_scope.dart test/super_overlay_accessibility_test.dart README.md
git commit -m "fix: align non-modal overlay semantics"
```

### Task 5: Make The Existing Example Prove Moving Anchors And Accessibility

**Files:**

- Modify: `example/lib/showcase/anchored_menu_panel.dart`
- Modify: `example/lib/showcase/dialog_demo_panel.dart`
- Modify: `example/test/anchored_menu_panel_test.dart`
- Modify: `example/test/dialog_result_test.dart`
- Modify: `tool/verification/example_coverage_matrix.md`

**Step 1: Add failing example tests**

- Open a popup, move or animate its anchor while it remains open, and assert
  the popup's global position changes with the anchor.
- Open the confirmation dialog and assert its route label, barrier label, and
  keyboard behavior are observable from the runnable example.

**Step 2: Run and verify RED**

```bash
cd example
flutter test test/anchored_menu_panel_test.dart test/dialog_result_test.dart
cd ..
```

Expected: the new interactions or labels do not yet exist.

**Step 3: Implement inside existing panels**

- Add one compact moving-anchor interaction to `AnchoredMenuPanel`; do not add
  a page or another navigation destination.
- Add explicit semantics and barrier labels to the existing confirmation flow.
- Update the coverage matrix with explicit surface, handle, strategy, route,
  moving-anchor, and accessibility rows backed by real files/tests.

**Step 4: Verify GREEN and example regression suite**

```bash
dart format example/lib/showcase/anchored_menu_panel.dart example/lib/showcase/dialog_demo_panel.dart example/test/anchored_menu_panel_test.dart example/test/dialog_result_test.dart
cd example
flutter analyze
flutter test
flutter build web
cd ..
```

Expected: all pass with no new demo page.

**Step 5: Commit**

```bash
git add example/lib/showcase/anchored_menu_panel.dart example/lib/showcase/dialog_demo_panel.dart example/test/anchored_menu_panel_test.dart example/test/dialog_result_test.dart tool/verification/example_coverage_matrix.md
git commit -m "feat(example): prove moving anchor and semantics contracts"
```

### Task 6: Prepare Coherent `0.3.0` Candidate Metadata

**Files:**

- Modify: `pubspec.yaml`
- Modify: `example/pubspec.lock`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `RELEASE.md`
- Modify: `tool/verification/example_device_matrix.md`
- Modify: `test/repository_contract_test.dart`

**Step 1: Add or update repository contract tests**

Assert that:

- package, README installation, and example lock all identify `0.3.0`;
- the changelog has one `0.3.0` section relative to published `0.2.0` and no
  remaining `Unreleased` runtime entries;
- the device matrix distinguishes mobile release blockers from claim-only
  desktop/optional topology evidence;
- every manual result remains unchecked until the maintainer fills it.

**Step 2: Run and verify RED**

```bash
flutter test test/repository_contract_test.dart
```

Expected: FAIL while metadata still identifies `0.2.0` and the matrix has one
undifferentiated blocker list.

**Step 3: Update candidate metadata**

- Set `version: 0.3.0` and run `flutter pub get` in root and example.
- Change README installation to `super_overlay: ^0.3.0`.
- Move the current `Unreleased` entries under `## 0.3.0` without assigning a
  release date before manual approval.
- Rewrite candidate status as code-ready pending exact remote CI and the final
  maintainer-run Android/iOS matrix.
- Split device evidence into required mobile release rows and claim-only rows.
  Do not check any row.

**Step 4: Verify repository contracts**

```bash
dart format test/repository_contract_test.dart
flutter analyze
flutter test test/repository_contract_test.dart test/documentation_contract_test.dart
flutter pub publish --dry-run
```

Expected: tests pass and the publish dry-run reports zero package warnings.

**Step 5: Commit**

```bash
git add pubspec.yaml example/pubspec.lock README.md CHANGELOG.md RELEASE.md tool/verification/example_device_matrix.md test/repository_contract_test.dart
git commit -m "chore: prepare 0.3.0 release candidate"
```

### Task 7: Run The Automated RC 2 Gate And Hand Off Manual Verification

**Files:**

- Modify only if evidence text is stale: `RELEASE.md`
- Do not modify results: `tool/verification/example_device_matrix.md`

**Step 1: Run the full package gate**

```bash
git diff --check
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter pub deps --style=compact
flutter test --test-randomize-ordering-seed=20260713
flutter test --test-randomize-ordering-seed=random
flutter test --coverage
awk -F: '/^LH:/{hit+=$2} /^LF:/{found+=$2} END{coverage=hit*100/found; printf "hit=%d found=%d coverage=%.3f%%\n", hit, found, coverage; exit found == 0 || coverage < 90}' coverage/lcov.info
dart doc --dry-run
flutter pub publish --dry-run
```

Expected: every command exits zero, coverage is at least 90%, dartdoc reports
zero warnings/errors, and the package dry-run reports zero warnings.

**Step 2: Run the full example gate**

```bash
cd example
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build web
flutter build apk --debug
cd ..
```

Expected: every command exits zero.

**Step 3: Review the complete diff**

Confirm every requirement in the approved design is represented, no device
result was invented, no unrelated feature entered the diff, and the worktree
is clean after commits.

**Step 4: Remote candidate gate**

Push the candidate branch only as the authorized RC workflow, then require the
exact candidate SHA's stable and Flutter 3.29 jobs to pass. Do not create the
stable tag or publish the package.

**Step 5: Manual handoff**

Give the maintainer the unchecked mobile matrix. If all required Android/iOS
rows pass, only evidence/version-release metadata may change before the final
CI rerun and stable tag. If a row fails, create a narrowly scoped RC 3 defect
plan and retest only affected rows plus the baseline smoke.

## Completion Criteria

- Route-scoped overlays survive invocation-child removal and still close on
  route/scope or explicit widget-owner removal.
- Invalid typed global close leaves the overlay intact.
- `replaceExisting` removes all same-tag matches uniformly.
- Non-modal dialogs preserve background semantics.
- Existing example panels prove moving-anchor and accessibility behavior.
- Metadata consistently identifies the unpublished `0.3.0` candidate.
- Local automated gates and exact remote CI pass.
- The real-device matrix remains pending for the maintainer; therefore the
  package is code-ready, not release-complete.
