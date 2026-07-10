# SuperOverlay Example

This Flutter app demonstrates the current SuperOverlay API:

* Custom overlay with tag-based dismiss.
* Loading, toast, popup, highlighted popup, and notify overlays.
* Targetless point popups, popup replacement/adjustment, scale-origin control,
  and mask ignore areas.
* Init-level default toast/loading/notify builders.
* Handle lifecycle futures with a visible event log.
* An interactive Command Contracts page covering tagged strategies, handle
  refresh and close, `SuperOverlay.exists`, refresh-active toasts, all
  notification variants, and global cleanup.
* Route-bound overlays that hide and reappear with navigation.
* Back-button handling with `OverlayBackBehavior`.

Run it from the repository root with:

```bash
cd example
flutter run
```

Run the example's interaction tests with:

```bash
flutter test
```
