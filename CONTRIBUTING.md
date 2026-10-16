# Contributing To SuperOverlay

Thanks for improving SuperOverlay. Bug fixes, focused features, documentation,
and reproducible issue reports are welcome.

## Set Up The Repository

Install Flutter stable, clone the repository, and fetch dependencies:

```bash
flutter --version
flutter pub get
cd example
flutter pub get
cd ..
```

The package supports Dart `>=3.7.0 <4.0.0` and Flutter `>=3.29.0`. CI runs the
full gate on Flutter stable and repeats package analysis and tests on Flutter
3.29.0.

## Make A Focused Change

Public API changes belong under `lib/src/api/` and must remain exported through
`package:super_overlay/super_overlay.dart`. Runtime implementation stays under
the other `lib/src/` folders. Add package tests under `test/`; add runnable user
flows to `example/` when a feature benefits from an interactive demonstration.

For behavior changes, first add the smallest test that reproduces the missing
contract. Keep unrelated formatting or refactors out of the same change.

## Run The Release Gates

Run these commands from the repository root before opening a pull request:

```bash
dart tool/verify.dart --suite full --publish-check
dart tool/verify.dart --suite minimum --flutter /path/to/flutter-3.29/bin/flutter
dart tool/verify.dart --suite router --flutter /path/to/flutter-3.47.4/bin/flutter
```

The same entry runs in CI. It copies the current source, including uncommitted
changes, to an isolated workspace before resolving dependencies. It does not
download SDKs, alter the source lockfiles, publish, commit, or push. The full
suite combines coverage and seed `20260713` in one package test run, enforces
90% line coverage, checks API docs, and builds all four example Web entries.
`--publish-check` adds a dry run from that clean copy; it is accepted only for
the full suite.

Package tests enable the VM service on both SDK suites. Toast retention
regressions use weak references and an explicit VM garbage collection to verify
that superseded builders can be released even while callers retain their handles.
They connect only to the test process's local VM service. To run these directly:

```bash
flutter test --enable-vmservice test/super_overlay_toast_retention_test.dart
```

Use `flutter test --enable-vmservice` when running the entire package directly.

Per-step logs and `report.json` include commands, SDK, exit codes and unrun
steps after a failure. Output defaults to a system temporary directory; use
`--output docs/local/verification/my-run` to retain it privately and
`--keep-workspace` to inspect the generated artifacts. The command returns the
first failure's nonzero status. `git diff --check` still checks the original
working tree.

For a focused isolated check use `--only package-test`, `--only example-test`,
or `--only package-analyze`. Dependencies are resolved first; `--only coverage`
also runs the package tests to generate a fresh LCOV file. For a single test,
use Flutter directly as below. Geometry and close ownership are documented in
[the runtime responsibilities](docs/design/overlay-runtime-responsibilities.md).
For timing changes, follow the
[performance protocol](tool/verification/performance_protocol.md).

For a faster local loop, run a focused test first:

```bash
flutter test test/super_overlay_command_api_test.dart
cd example && flutter test test/widget_test.dart
```

## Pull Requests

Describe the user-visible contract, include regression coverage, and update the
README, example, or CHANGELOG when behavior changes. Keep commits reviewable and
confirm that `git diff --check` is clean.

Normal bugs and feature requests can use the GitHub issue template. Report
vulnerabilities privately according to [SECURITY.md](SECURITY.md).
