# Example Device Verification Matrix

Status: **manual checks pending**

Release status: **blocked until every required mobile row has real device
evidence**. Claim-only rows do not block publication unless those platform or
topology claims are made for this release.

Automated widget tests verify simulated safe-area padding, anchored popup
geometry, and responsive layouts at 320, 600, and 1200 logical pixels. They do
not constitute proof on real display-cutout hardware, with a physical keyboard,
or under device-specific edge-to-edge window behavior.

Do not mark the cutout issue as hardware-verified until at least one iPhone with
a notch or Dynamic Island and one edge-to-edge Android cutout device pass the
relevant rows below.

## Historical Automated Baseline

The following source checks passed locally on 2026-07-13 with Flutter 3.41.6,
before the current release-candidate metadata and subsequent hardening changes.
This snapshot is historical context, not a current RC result, and it does not
complete any manual row:

- 246 package tests under fixed and fresh randomized ordering;
- 91.138% package line coverage (3507 of 3848 lines);
- 26 example widget tests;
- example Web build;
- example Android debug APK build;
- publish dry-run from both the Git worktree and a copy without `.git`, with
  zero warnings.

The current source passed the refreshed local gates on 2026-07-14 with 298
package tests, 90.9398% line coverage (3774 of 4150 lines), 29 example tests,
and successful Web and Android debug APK builds. Flutter stable and Flutter
3.29 passed in GitHub Actions run #9 for the earlier source commit
`daa9af70608e887f4ee3361eb78a1d851e917d24`. Subsequent local blocker fixes
still require exact-SHA remote CI. The required mobile evidence below also
remains pending.

## Required Mobile Release Blockers

Every row in this section requires real Android or iOS device evidence before
publication.

| Done | Device and orientation | Scenario | Expected result | Evidence |
| --- | --- | --- | --- | --- |
| [ ] | iPhone notch/Dynamic Island, portrait | Show each of the five notification types | Banner stays below the cutout with a visible gap | Device/OS and screenshot |
| [ ] | iPhone notch/Dynamic Island, landscape | Show each of the five notification types | Banner remains inside the safe area on both landscape directions | Device/OS and screenshot |
| [ ] | Edge-to-edge Android cutout, portrait | Show each of the five notification types | Banner does not overlap the status bar or cutout | Device/OS and screenshot |
| [ ] | Edge-to-edge Android cutout, landscape | Show each of the five notification types | Banner remains inside the current safe area | Device/OS and screenshot |
| [ ] | iPhone or Android after scrolling the home page | Open the sort dropdown from its trigger | Popup opens directly below the current on-screen trigger and keeps its width | Device/OS and screenshot |
| [ ] | iPhone or Android with the keyboard visible | Open the attachment menu | Upward menu opens above its trigger without covering the field or keyboard | Device/OS and screenshot |
| [ ] | iPhone or Android with the keyboard visible | Show a top notification | Notification stays below the cutout/status bar and is not displaced incorrectly | Device/OS and screenshot |
| [ ] | iPhone or Android with the keyboard visible | Focus a field, open and close a modal dialog | Focus is trapped inside the modal and restored to the original field after close | Device/OS and recording |
| [ ] | Android with gesture navigation | Use system back with `dismiss`, `block`, and `passThrough` dialogs | Overlay and route behavior matches the selected policy without a double pop | Device/OS and recording |
| [ ] | Android with predictive back enabled | Start, cancel, then complete predictive back with an active modal | Preview and completion respect the modal policy and never expose a stale route | Device/OS and recording |
| [ ] | iPhone or Android in a scrolling view | Move a popup anchor partially and then fully outside the viewport, then remove it | Popup follows while partially visible and closes after full exit or target removal | Device/OS and recording |

## Claim-Only And Optional Evidence

These rows support desktop or optional topology claims. They are not release
blockers unless the corresponding claim is included in release notes or other
release messaging.

| Done | Platform or topology | Scenario | Expected result | Evidence |
| --- | --- | --- | --- | --- |
| [ ] | Desktop with a physical keyboard | Exercise Tab, Shift-Tab, and Escape in a modal and focused popup | Focus remains scoped correctly and Escape follows the documented back policy | OS/build and recording |
| [ ] | Stateful shell example or fixture on a device | Switch branches while a branch-scoped modal is active, then return | Inactive overlay suspends and resumes without blocking the active branch | Device/OS and recording |

For each completed row, replace the Evidence placeholder with the device model,
OS version, and a screenshot or recording path. If a row fails, record the
exact orientation, scroll position, keyboard state, and reproduction steps.
