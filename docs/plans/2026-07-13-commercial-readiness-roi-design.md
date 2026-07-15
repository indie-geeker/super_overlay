# SuperOverlay Commercial Readiness ROI Design

**Status:** Approved

**Date:** 2026-07-13

## Context

The existing commercial-readiness work already delivered the command-first API,
host generations, scoped Navigator observers, PopEntry back handling, moving
popup anchors, accessibility foundations, a scenario-based example, more than
90% line coverage, and hardened CI. This follow-up must not repeat that work or
expand the package with new features.

The final review found three high-return runtime contract gaps and three smaller
release/DX gaps:

1. A route-scoped overlay is implicitly tied to the `BuildContext` used to
   create the scoped facade, even though widget lifetime is already represented
   by `bindToWidget`.
2. A global typed close can remove an overlay before discovering that the
   supplied result type is incompatible with the handle.
3. `replaceExisting` removes one matching dialog/popup/notification but all
   matching Toasts.
4. `consumeEvents: false` permits pointer penetration while still blocking the
   background semantics tree.
5. The example claims moving-anchor and accessibility coverage more strongly
   than its interactive scenarios prove.
6. The checkout implements the next public API while package metadata and the
   README still identify published `0.2.0`.

## Goals

- Close the three runtime contract gaps before the next stable release.
- Align non-modal pointer and semantics behavior without adding a new policy
  abstraction.
- Make the existing example prove moving-anchor and keyboard/semantics behavior
  without adding another demo page.
- Prepare one coherent `0.3.0` candidate relative to published `0.2.0`.
- Leave real-device verification as the final, manual release gate.
- Stop once these release-risk reductions are complete.

## Non-Goals

- Desktop multi-window routing.
- A host-level global keyboard dispatcher for `requestFocus: false`.
- New overlay surfaces or public configuration layers.
- Raising coverage above the existing 90% gate.
- Exhaustive platform, window-size, router, or device matrices.
- Filling in real-device evidence without an actual manual run.

## Version Stages

### Internal RC 1: Runtime Contracts

RC 1 removes the invocation-context lifetime coupling, validates typed global
close results before mutation, and makes `replaceExisting` mean “remove every
same-surface, same-tag match, then show the replacement” on every surface that
supports `OverlayStrategy`.

These are internal branch milestones, not pub.dev prereleases. The package
version remains unchanged while the runtime work is in progress.

### Internal RC 2: Accessibility, Example, And Candidate Metadata

RC 2 aligns non-modal semantics, adds focused interactions/tests to existing
example panels, updates the coverage matrix, and prepares coherent `0.3.0`
metadata. It then runs the full local gate and the exact candidate's remote CI.

`requestFocus: false` remains a documented opt-out: Escape handling is only
promised while focus is inside the overlay. This avoids introducing a global
keyboard ownership system for a best-effort desktop contract.

### Stable 0.3.0: Manual Device Acceptance

After all automated evidence is green, the maintainer manually verifies the
required Android and iOS rows. Desktop keyboard and optional router topologies
are claim gates, not blockers for the supported mobile release.

If manual verification finds a defect, only that release-blocking defect is
fixed in another internal RC. No unrelated feature or refactor enters the
release branch.

## Runtime Decisions

### Route Ownership

`OverlayRouteOwner` contains host generation, integration identity, Navigator
scope identity, and exact Route identity. It does not retain the invocation
context. Route removal, scope disposal, host replacement, or explicit
`bindToWidget` closes an overlay; removal of an unrelated child widget does not.

### Typed Global Close

A non-null result is validated against the stored result type before a record is
marked closing or removed from the queue. Bulk targets reject non-null results
because one value cannot safely complete multiple potentially heterogeneous
handles. A failed validation leaves the overlay visible and closable through
its original handle.

### Replacement

For a non-null tag and `OverlayStrategy.replaceExisting`, every active or
queued match in the same surface and generation is closed before the new item
is shown. Replacement remains serialized by the existing replacement queue.

### Non-Modal Accessibility

`consumeEvents: false` selects non-modal accessibility behavior and does not
wrap the background in `BlockSemantics`. Modal overlays retain focus trapping,
barrier semantics, Escape handling, and focus restoration.

## Release Boundary

Automated gates establish code readiness. Release readiness additionally
requires the maintainer's real-device evidence. The implementation must leave
the matrix pending and must not tag, publish, or claim stable completion before
that evidence exists.

## Stop Line

The work stops after the three runtime contracts, non-modal semantics, two
small example proofs, coherent `0.3.0` metadata, and automated gates are done.
Multi-window support, performance redesign, additional demo pages, and broader
test matrices remain unplanned unless production evidence later justifies them.
