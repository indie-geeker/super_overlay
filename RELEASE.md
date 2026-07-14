# Release Checklist

Use this checklist for every pub.dev release candidate. Do not assign a release
date or create a tag until all automated gates pass and required manual evidence
is recorded.

## Current Candidate Status

The commercial-readiness branch passed its local automated source gate on
2026-07-13 with Flutter 3.41.6:

- 246 package tests passed with fixed and fresh randomized ordering;
- line coverage was 91.138% (3507 of 3848 lines);
- 26 example tests, the Web build, and the Android debug APK build passed;
- publish dry-run reported zero warnings in the Git worktree and in a copied
  archive without `.git`.

This is source-code-ready evidence, not release approval. The release remains
blocked by the manual [device verification matrix](tool/verification/example_device_matrix.md),
remote CI for the exact candidate commit (including Flutter 3.29), and final
version/changelog approval. The official Dart package resolver currently
selects published `0.2.0`; because this branch adds public integration and
nested-navigation APIs, the next candidate is expected to be `0.3.0`. Do not
change the package version until the remaining evidence is complete.

## 1. Prepare The Candidate

- Confirm the intended package version in `pubspec.yaml`.
- Move user-visible entries from `Unreleased` into that version only when the
  release is approved.
- Confirm README installation syntax and `example/pubspec.lock` match the
  candidate version.
- Review breaking changes, migration notes, supported topology, and platform
  tiers.
- Confirm the private vulnerability-reporting path in
  [SECURITY.md](SECURITY.md) is reachable by an external reporter.

## 2. Run Package Gates

From the repository root:

```bash
git diff --check
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter pub deps --style=compact
flutter test test/repository_contract_test.dart
flutter test test/super_overlay_back_dispatch_test.dart
flutter test test/super_overlay_host_ownership_test.dart
flutter test test/super_overlay_shell_route_test.dart
flutter test --test-randomize-ordering-seed=20260713
flutter test --test-randomize-ordering-seed=random
flutter test --coverage
dart doc --dry-run
flutter pub publish --dry-run
```

Coverage must meet the threshold enforced by CI. The publish dry run must be
repeated from a clean checkout or clean archive so dirty-tree warnings are not
mistaken for package-content failures.

## 3. Run Example Gates

```bash
cd example
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build web
cd ..
```

Confirm every row in the
[example coverage matrix](tool/verification/example_coverage_matrix.md) still
points to a reachable scenario and passing test.

## 4. Record Device And Platform Evidence

- Complete the required Android and iOS rows in the
  [device verification matrix](tool/verification/example_device_matrix.md).
- Record device model, OS, orientation, keyboard state, and screenshot or
  recording path.
- Record `flutter build` and a short manual result before advertising macOS,
  Windows, or Linux for this release.
- Keep desktop claims at best-effort single-window unless multi-window support
  is explicitly implemented and tested in a future release.

## 5. Confirm Remote CI

- Push the candidate branch and wait for every required GitHub Actions job.
- Confirm stable Flutter and Flutter 3.29 compatibility jobs are green.
- Confirm the workflow uses minimal read-only permissions, every job has a
  timeout, and third-party Actions remain pinned to reviewed commit SHAs.
- Confirm docs, coverage, publish dry run, example tests, and Web build ran in
  remote CI rather than relying only on local output.
- Review Dependabot pull requests that update pinned GitHub Actions before
  merging them; a version comment is not a substitute for reviewing the new
  commit SHA.
- Review dependency and security alerts before approval.

## 6. Tag And Publish

- Merge the reviewed candidate without bypassing required checks.
- Create the signed or annotated version tag from the verified commit.
- Publish with `flutter pub publish` only after reviewing the final archive.
- Verify the pub.dev package page, API docs, repository links, license, and
  changelog after publication.
- Create the GitHub release from the same tag and include migration/support
  notes.

## 7. Post-Release

- Run a clean consumer smoke test against the published version.
- Verify the example still builds when resolving the released package.
- Monitor incoming issues and security reports against the best-effort targets
  documented in [SECURITY.md](SECURITY.md).
- Keep the previous release artifact and rollback notes until the new version
  is proven stable.
