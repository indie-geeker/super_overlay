# Reproducible Overlay Performance Checks

Use the development-only `example/lib/performance_main.dart` entry. It imports
internal diagnostics intentionally; consumers should use the public library.
The normal package does not collect these timing samples or allocate resource
snapshots until explicitly queried.

From `example/`, with an installed, fixed Flutter SDK:

```bash
flutter run -d macos --profile --target lib/performance_main.dart \
  --dart-define=OVERLAY_BENCHMARK_AUTORUN=true
```

Run the same source workload before and after a change, including any prior
uncommitted fixes in both copies. Do not compare a HEAD-only archive with a
dirty candidate. Record source fingerprints, Flutter/Dart, OS/machine, build
mode, logical window dimensions/DPR, warmup and sample size. Keep raw logs,
VM allocation snapshots and local reports in ignored `docs/local/performance/`.

The harness warms up 30 moving frames, then runs three rounds of seven phases:
500 ms idle; eight stationary popups over 120 existing frames; one/eight moving
anchors over 120 frames; a retained form covered for 600 ms and resumed for
350 ms; ten close cycles;
five host replacements. A 750 ms timing flush separates phases. Each
`OVERLAY_SAMPLE` JSON record includes UI/raster/total frame samples, builder
counts and before/after logical resource counts. Completion is explicitly
marked `OVERLAY_BENCHMARK_DONE`; a partial run is not a completed comparison.

Calculate per-round median and p90 timings, frame counts and their range.
Compare builder counts and resource baselines as separate contracts. Idle
producing zero frames is expected; no timing percentile exists for that phase.
The stationary phase supplies frames externally to exercise monitoring without
misrepresenting idle rendering. Moving popup content currently rebuilds when
the anchor updates; a lower file count is not a performance result.

Use the profile VM service `getAllocationProfile` with `gc: true` after the
workload to inspect current instances of overlay records and retained content.
An active host/observer or registered persistent callback may legitimately
remain. Logical counters and a bounded post-GC sample are evidence for the
tested workload, not proof that every consumer or path is leak-free.

Business Timer/Stream owners release resources on dispose. Their activity
during route suspension is recorded intentionally and must not be interpreted
as a package failure. `super_overlay_resource_pressure_test.dart` independently
checks repeated close, unmount, host replacement and reused-tag cleanup.

Use separate Web metrics if desktop profile is unavailable; do not invent
native raster timing for the browser. Background load, warmup and GC can
dominate small timings. Report overlapping ranges as inconclusive and retain
the structural change without speculative caches or speedup percentages.
