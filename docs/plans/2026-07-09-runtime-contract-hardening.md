# SuperOverlay Runtime Contract Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make SuperOverlay's public lifecycle, replacement, popup input, host teardown, and tagged-result contracts reliable enough for 9.2+ commercial and open-source readiness.

**Architecture:** Preserve the command-oriented public API while replacing inferred lifecycle state with explicit runtime signals. Fix behavior in small TDD slices, then simplify the internal command-to-runtime mapping only after the contracts are locked by regression tests.

**Tech Stack:** Dart 3.7+, Flutter 3.29+, flutter_test, GitHub Actions.

---

### Task 1: Reliable handle visibility

Add failing tests for dialog, loading, popup, notification, and toast visibility. Introduce a real runtime visibility future that completes only after the overlay has rendered; invalid popup targets must fail and clean themselves up.

### Task 2: True popup mask ignore rectangles

Add hit-testing regressions for an arbitrary middle-screen rectangle, replace the padding interpretation with a true rectangular pass-through, and fix the example interaction.

### Task 3: Serialized replacement

Add same-microtask replacement regressions for dialog, popup, notification, and toast. Serialize operations by surface and business tag so only the latest replacement becomes visible.

### Task 4: Symmetric host lifecycle

Add host reconfiguration and teardown regressions. Clear init-level defaults, contexts, timers, queues, and pending handle futures when the host changes or disposes.

### Task 5: Tagged result type safety

Record the result type of tagged overlays and fail immediately when `keepExisting` tries to reuse a tag with an incompatible generic result type.

### Task 6: Complete example contract coverage

Add a command-contracts page for strategies, handles, existence checks, refresh-active toast, global cleanup, and all notification types, with widget tests for real interactions.

### Task 7: Runtime mapping cleanup

Introduce one internal runtime result carrying visible, closed, and identity data. Reduce command-path dependence on the legacy await-completion switch without changing the public API.

### Task 8: Open-source and release finish

Update README and CHANGELOG, add concise contribution and pull-request guidance, then run formatting, analysis, package tests with coverage, dartdoc, dependency inspection, example analysis/tests/Web build, diff checks, and publish dry-run.
