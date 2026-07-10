# Example Device Verification Matrix

Status: **manual checks pending**

Automated widget tests verify simulated safe-area padding, anchored popup
geometry, and responsive layouts at 320, 600, and 1200 logical pixels. They do
not constitute proof on real display-cutout hardware, with a physical keyboard,
or under device-specific edge-to-edge window behavior.

Do not mark the cutout issue as hardware-verified until at least one iPhone with
a notch or Dynamic Island and one edge-to-edge Android cutout device pass the
relevant rows below.

| Done | Device and orientation | Scenario | Expected result | Evidence |
| --- | --- | --- | --- | --- |
| [ ] | iPhone notch/Dynamic Island, portrait | Show each of the five notification types | Banner stays below the cutout with a visible gap | Device/OS and screenshot |
| [ ] | iPhone notch/Dynamic Island, landscape | Show each of the five notification types | Banner remains inside the safe area on both landscape directions | Device/OS and screenshot |
| [ ] | Edge-to-edge Android cutout, portrait | Show each of the five notification types | Banner does not overlap the status bar or cutout | Device/OS and screenshot |
| [ ] | Edge-to-edge Android cutout, landscape | Show each of the five notification types | Banner remains inside the current safe area | Device/OS and screenshot |
| [ ] | iPhone or Android after scrolling the home page | Open the sort dropdown from its trigger | Popup opens directly below the current on-screen trigger and keeps its width | Device/OS and screenshot |
| [ ] | iPhone or Android with the keyboard visible | Open the attachment menu | Upward menu opens above its trigger without covering the field or keyboard | Device/OS and screenshot |
| [ ] | iPhone or Android with the keyboard visible | Show a top notification | Notification stays below the cutout/status bar and is not displaced incorrectly | Device/OS and screenshot |

For each completed row, replace the Evidence placeholder with the device model,
OS version, and a screenshot or recording path. If a row fails, record the
exact orientation, scroll position, keyboard state, and reproduction steps.
