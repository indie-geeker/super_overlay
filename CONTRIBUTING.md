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
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
dart doc --dry-run
flutter pub publish --dry-run
cd example
flutter analyze
flutter test
flutter build web
```

Package coverage must stay at or above 90%. CI calculates the threshold from
`coverage/lcov.info`.

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
