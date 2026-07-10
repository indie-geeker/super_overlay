# SuperOverlay Example Experience Redesign

**Date:** 2026-07-10

## Goal

Redesign the example so a developer can understand the package through real
interaction scenarios before entering API-level lifecycle demonstrations. The
home page should answer what each overlay solves, what an action will do, and
which package capability produced the result.

The redesign must also fix the misleading Toast action state, notification
safe-area presentation, popup anchoring, overlapping notification gallery, and
the low-value global activity log.

## Product Direction

Use a layered example:

1. The home page presents common development scenarios.
2. Advanced pages explain lifecycle, tags, strategies, and handles.
3. Status feedback stays next to the interaction that produced it.

The example should not expose every low-level option on the home page. Advanced
geometry cases remain available through the control lab where they have enough
context to be useful.

## Current Problems and Root Causes

### Misleading Toast selection

`单个 Toast` uses a filled action button while its peers use outlined buttons.
The action has no selected state, but its styling makes it look permanently
selected. The design currently conflates configuration state with action
hierarchy.

### Notification obstruction risk

The shared overlay surface contains a `SafeArea`, but the example's custom
success notification has no visual inset. There is also no geometry regression
test that proves a custom notification remains below a simulated display
cutout. The core safe-area contract and example styling therefore cannot be
distinguished from the current evidence.

### Popup anchored to the wrong element

The current popup actions share a `Builder` around the entire button `Wrap`.
The popup is positioned relative to that group instead of the control the user
clicked. The top, bottom, left, and right selector describes a technical option
without demonstrating a recognizable dropdown or upward menu.

### Command Contracts is organized around implementation terms

The page presents `Handle`, `exists`, tag strategy, and `refreshActive` before
explaining when an application needs them. Its notification gallery also mixes
surface styling with lifecycle control.

`Show all notification types` creates five top-center notifications with a
stack strategy. Stack permits coexistence; it does not calculate vertical
offsets. The five independent surfaces therefore overlap by design.

### Live Status has no teaching purpose

The global log records unrelated home-page actions. Its only unique case,
awaiting an overlay lifecycle, belongs in the advanced lifecycle demonstration.

## Information Architecture

The home page is divided into three sections.

### Common scenarios

- Instant feedback
- Anchored menus
- Custom dialog
- Network request states

### Interaction enhancement

- Guided mask and highlighted targets

### Advanced capabilities

- Route and widget lifecycle binding
- Overlay control lab

Remove the `CapabilityStats` row, the `Live Status` panel, and the app-bar
notification shortcut. They add visual weight without helping developers choose
or understand a capability.

On narrow layouts, cards appear in one column. On wide layouts, common-scenario
cards use two columns. The guided-mask scenario may use the full section width,
and advanced capabilities use compact navigation cards. Differently sized
content should not be placed in one global `Wrap`.

UI copy uses Chinese for scenarios and actions. API identifiers remain in
English and use code styling.

## Instant Feedback Design

Rename `Toast Deck` to `即时反馈` and separate configuration from execution.

### Toast display policy

Use a segmented selector with these choices:

- `替换最新`: simulate repeated saves and keep only the latest feedback.
- `依次排队`: simulate three file uploads completing in order.
- `同时显示`: simulate three independent background tasks.

A single filled `运行 Toast 演示` button executes the selected scenario. The
segmented selector is allowed to show persistent selected styling because it
represents real state; the action button does not represent a selected mode.

### Notification type gallery

Use a compact type selector for success, failure, warning, error, and alert,
plus one `显示通知` action. Every gallery notification uses the same tag and
`replaceExisting`, so switching type never leaves overlapping notifications.

Loading moves into the network request scenario, where it participates in a
complete loading-to-result flow instead of appearing as an isolated button.

### Safe-area contract

Before changing public API, add a geometry regression with a simulated top
`viewPadding`. The expected notification top is the system safe inset plus a
12-pixel visual gap.

- If the core host fails to preserve the safe inset, fix the core context or
  layout contract.
- If the core geometry is correct, add the visual gap to the example's custom
  notification presentation.
- Do not mask an unknown core failure with an arbitrary fixed top margin.

## Anchored Menu Design

Rename `Popup Window` to `锚点菜单` and replace the option playground with two
real controls.

### Dropdown selector

An input-like `排序方式` control displays the current selection. Tapping it
opens an option list immediately below the control. Choosing an item closes the
popup and updates the field.

### Upward action menu

An `添加附件` control opens a menu immediately above itself with camera, gallery,
and file actions. Choosing an item closes the popup and displays the last action
in the card.

Each trigger owns its own `Builder` or `GlobalKey`. The target context must be
the concrete interactive control, never a wrapper around multiple actions. The
dropdown uses bottom-center target alignment and the upward menu uses top-center
target alignment. Popup width follows the target where appropriate.

Point positioning, replacement builders, adjustment builders, scale origins,
and mask-ignore geometry move to the advanced lab.

## Overlay Control Lab

Rename `Command Contracts` to `Overlay 控制实验室`. The page begins by explaining
that it is for overlays that must be deduplicated, updated, awaited, or closed
after being shown.

### Repeated-trigger strategy

Use a scenario in which two network failures request the same login dialog.
Developers choose `stack`, `keepExisting`, or `replaceExisting`, then run two
triggers. The result panel explains the observable outcome:

- Stack keeps both; closing the top dialog reveals the first.
- Keep-existing preserves the original dialog.
- Replace-existing leaves only the latest dialog.

### Owned overlay handle

Use an upload-task scenario with `开始任务`, `更新进度`, and `取消任务`. Show a
local lifecycle state:

`未创建 -> 已显示 -> 已刷新 -> 已关闭`

The demonstration maps the scenario to `OverlayHandle`, `visible`, `refresh`,
`close`, and `SuperOverlay.exists`. Controls are enabled only when their action
is valid.

### Awaited lifecycle

Move the old Await case into a local timeline:

1. Handle created.
2. First rendered frame visible.
3. Overlay closed.
4. Closed future completed.

This is the only place that needs a multi-event log because the timeline itself
is the feature being taught.

### Cleanup

The primary cleanup action closes only handles and tags owned by this page. A
separate danger action demonstrates global cleanup and explicitly warns that it
affects overlays created elsewhere.

The notification type gallery does not appear on this page.

## Component Boundaries

Split interactive state by scenario:

```text
ShowcaseHomePage
|- InstantFeedbackPanel
|- AnchoredMenuPanel
|- DialogDemoPanel
|- NetworkState entry
|- GuidedMaskPanel
`- AdvancedDemoLinks
   |- LifecycleDemoPage
   `- OverlayControlLabPage
```

`ShowcaseHomePage` composes sections and performs navigation. Each interactive
panel owns its local mode, selection, handles, and cleanup. Reuse
`FeaturePanel`, `CodeStrip`, and a new `DemoStatusBanner`. No application state
framework is needed.

The normal data flow is:

`select mode -> run scenario -> create overlay -> update local status -> close`

## Error and Lifecycle Handling

- Rapid repeated actions use an explicit toast or tag strategy.
- A popup closes when its target becomes unavailable and reports that outcome
  locally where useful.
- Asynchronous callbacks check `mounted` before updating state.
- Page disposal closes only page-owned handles and tags.
- The global cleanup demonstration is visually marked as destructive.
- Notification gallery variants share a tag and replace one another.
- Local status banners use `Semantics(liveRegion: true)`.
- Existing route, widget-binding, and back-behavior demonstrations remain
  separate from the command lab.

## Verification

### Package tests

- A custom top notification remains below simulated top safe padding.
- Notification replacement leaves only one matching notification.
- Popup target removal closes the popup.

### Example widget tests

- Toast mode state and the run action have distinct semantics.
- Replace-latest, queue, and stack scenarios show their expected content.
- Notification type switching never overlaps variants.
- Dropdown content is below its exact trigger.
- Upward-menu content is above its exact trigger.
- Selecting a menu item closes the popup and updates local state.
- Stack, keep-existing, and replace-existing are observable in the control lab.
- Handle visible, refresh, close, and exists state stay consistent.
- Leaving the control lab preserves overlays owned elsewhere.
- The old Live Status panel, notification shortcut, and show-all-notifications
  action are absent.

### Responsive and build gates

- Verify 320, 600, and 1200 logical-pixel widths without overflow.
- Run package and example formatting, analysis, and tests.
- Build the example for macOS and Web.

### Manual device checks

- Test one iPhone with a notch or Dynamic Island.
- Test one edge-to-edge Android device with a display cutout.
- Keep at least 12 pixels between the notification and the safe-region edge.
- Recheck notification placement after orientation changes.
- Recheck popup anchoring after scrolling.
- Verify the upward menu and top notification remain usable with the keyboard
  visible.

## Acceptance Criteria

- No action looks selected unless it represents a selected mode.
- Notifications neither overlap nor enter a display cutout.
- Dropdown and upward menus visibly attach to their triggers.
- The home page contains scenario-first demonstrations only.
- The advanced lab explains why and how to use strategies, handles, existence
  checks, refresh, and awaited lifecycle state.
- Live Status is removed and its useful Await behavior is taught locally.
- Copy, hierarchy, spacing, and action styling are consistent across widths.
