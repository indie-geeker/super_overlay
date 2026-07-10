# Example Command Contracts Design

## Goal

Make the example a runnable reference for the command API contracts that are difficult to infer from visual surface demos alone: tagged display strategies, handle lifecycle, existence checks, refresh-active toast behavior, notification variants, and global cleanup.

## Chosen approach

Add one discoverable panel to the showcase home page and navigate to a dedicated `CommandContractsDemoPage`. Keeping the contract controls on a separate page avoids overcrowding the existing surface showcase while making every contract directly testable. Embedding all controls in the home page would reduce navigation but make the current page harder to scan; documenting the contracts without interactive controls would not prove that the example works.

## Page structure and data flow

The page owns only demo state: the latest status message and any handle it needs to close explicitly. Each action calls the public `SuperOverlay` command API, then updates status from `visible`, `closed`, or `SuperOverlay.exists`. Tagged strategy actions use stable demo tags so the rendered result is deterministic. A cleanup action calls `SuperOverlay.close(target: OverlayCloseTarget.all, force: true)` and resets page state.

The controls are grouped into four compact sections:

1. Tagged strategies: stack, keep-existing, and replace-existing.
2. Handle and lookup: show, refresh, close, and `exists` state.
3. Toast policy: demonstrate `refreshActive` with visibly updated content.
4. Notifications and cleanup: trigger all five variants and close every surface.

## Error handling

Actions remain usable after overlays close externally. Handle callbacks check `mounted` before updating the page, and cleanup is safe when no overlays exist. The page does not suppress lifecycle failures; it reports them in the status area so the example teaches the public contract.

## Verification

Widget tests navigate from the home page, exercise tagged strategy behavior, prove `exists` changes around an owned handle, verify refresh-active toast content, render all notification variants, and confirm global cleanup. The existing example tests continue to cover the visual showcase and popup interactions.
