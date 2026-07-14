# Release Checklist

Use this checklist for every pub.dev release candidate. Do not assign a release
date or create a tag until all automated gates pass and required manual evidence
is recorded.

## Current Candidate Status

Version `0.3.0` is the current unpublished release candidate. It has not been
tagged or published and is not release-complete.

The complete local automated RC gate passed on 2026-07-14 with Flutter 3.41.6
and Dart 3.11.4:

- formatting, analysis, and dependency resolution completed successfully;
- 293 package tests passed with fixed seed `20260713` and fresh seed
  `3347434202`;
- line coverage was 90.9157% (3773 of 4150 lines), above the 90% threshold;
- dartdoc reported zero warnings and zero errors;
- publish dry-run reported zero warnings;
- 29 example tests, the Web build, and the Android debug APK build passed.

Both jobs in [GitHub Actions run #8](https://github.com/indie-geeker/super_overlay/actions/runs/29319573548)
passed for source commit `48447e884c6b27c98675013e400d389d35ea052e`,
covering Flutter stable and Flutter 3.29. The remaining release blocker is the
required Android and iOS evidence that a maintainer must record in the
[device verification matrix](tool/verification/example_device_matrix.md).

## 1. Prepare The Candidate

- Confirm the intended package version in `pubspec.yaml`.
- Confirm `CHANGELOG.md` contains one undated section for the candidate version
  and preserves all published histories.
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
flutter build apk --debug
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
