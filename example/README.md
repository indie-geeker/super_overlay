# SuperOverlay Example

This Flutter app presents the current SuperOverlay API through development
scenarios instead of a list of unrelated commands.

The home page is organized into three sections:

* **Common scenarios** compares replace-latest, queued, and stacked Toast
  policies; shows every notification type one at a time; demonstrates a real
  dropdown below its field and an attachment menu above its trigger; and links
  to custom-dialog and network-state flows.
* **Interaction enhancements** demonstrates a highlighted, step-by-step guide
  whose mask only accepts taps on the active target.
* **Advanced capabilities** links to route/widget lifecycle behavior and the
  Overlay Control Lab.

The Overlay Control Lab makes command behavior observable through repeated
login prompts (`stack`, `keepExisting`, and `replaceExisting`), an upload Toast
controlled through its own `OverlayHandle`, and a visible `visible`/`closed`
timeline. Advanced popup geometry remains available there for explicit points,
replacement and adjustment hooks, scale origins, and mask ignore areas.

The app also configures init-level loading, Toast, and Notify builders. Top
notifications include a gap below the safe area so content remains clear of
display cutouts.

Run it from the repository root with:

```bash
cd example
flutter run
```

Run the example's interaction tests with:

```bash
flutter test
```

Widget tests cover scenario behavior, popup geometry, responsive layouts, and
simulated safe-area padding. Simulation is not proof on a physical cutout
device. Before a release, complete the repository's
[`example_device_matrix.md`](../tool/verification/example_device_matrix.md) on
at least one cutout iPhone and one edge-to-edge Android device.
