# Release Checklist

Use this checklist for every pub.dev release candidate. Do not assign a release
date or create a tag until all automated gates pass and required manual evidence
is recorded, unless the maintainer explicitly requests a release with the
remaining gaps disclosed. Record that exception without marking pending
evidence complete.

## Published Version And Current Work

**0.4.0 is the release version for 2026-10-16.** Confirm live publication through
the [pub.dev package API](https://pub.dev/api/packages/super_overlay). The
pre-publication check at 08:19 UTC on 2026-10-16 reported 0.3.1, published on
2026-09-09 at 03:02:33 UTC, with 0.4.0 still available for upload.

Package metadata, both README installation snippets, `example/pubspec.lock`,
and the issue-template version hint identify **0.4.0**. Its dated CHANGELOG
section includes breaking builder, close
target and scoped-facade changes; both README editions contain migration notes.

The maintainer explicitly requested publication on 2026-10-16 after disclosure
of the outstanding Android/iOS device evidence and final-commit remote CI.
Publication follows the automated checks for the release commit. This release
instruction is the documented exception for the pending device rows; those rows
remain unverified and must not be presented as passed.

The candidate covers bounded Toast retention, closed-handle content release,
first-frame-based Loading minimum duration, and application dismissal Action
context/key-result forwarding. Both README editions describe these contracts
and native menu Escape limitations. The shared runner enables VM-GC retention
regressions for both Flutter SDK suites.

Back and mask callbacks remain bound to their original instance; delayed Popup
target-failure callbacks also retain their original presentation. An old callback
cannot close another instance through a colliding business tag, or cancel a
deferred Loading replacement. Explicit global tag cleanup keeps its documented
meaning. Toast mask callbacks are bound to their lane presentation; automatic
expiry and route/widget cleanup target the original record, including internal
repeated identity tags. A queued Dialog or anchored Popup is cancelled before
replacement cleanup or activation if its widget owner unmounts; route-owned Dialog/Popup
commands also cancel when their route or observer disappears. Cancellation
rejects `visible`, settles `closed` normally, and preserves a previously supplied
close result.

Actual back consumption takes precedence within a shortcut dispatch. A custom
dispatcher that intercepts without invoking the bridge leaves conversion of its
final value to the application Action, including when it creates a new consuming
overlay. Without an application Action, Flutter's default key consumption applies.
Dedicated regressions cover native child/ancestor shortcuts, reentry, old masks,
target-failure callbacks, and queued cancellation. Fresh minimum/full/router
gates must cover this complete source before publication is considered.

Real-device checks in the [device matrix](tool/verification/example_device_matrix.md)
remain pending under the release instruction above. Historical CI and local
automated tests do not fill that gap. Future candidates follow the checklist
below unless a further maintainer instruction explicitly records an exception.

## Current Candidate Automated Verification

The complete local gate passed on 2026-10-16 for the current candidate:

- Flutter 3.29.0 / Dart 3.7.0 and Flutter 3.47.4 / Dart 3.13.3 both passed
  package/example analysis, 1063 package tests and 39 example tests.
- The 248 added regressions include baseline controls: on each SDK, 117 fail
  against the pre-fix source and all 248 pass after the fixes. Independent
  source review covers callback reentry, exact instance/presentation ownership,
  replacement cancellation and resource release.
- The seeded full run measured 4107 of 4374 lines covered (93.896%). Forced-GC
  retention cases ran with the VM service enabled on both SDKs.
- The go_router 18 fixture passed analysis and all six tests. The minimum-SDK
  fixture continues to use go_router 14.8.1.
- All four example Web entries compiled; the Android debug APK compiled with
  Flutter 3.29.0 and Temurin 21 in an isolated workspace. The workspace-only
  Java selection did not change repository or system Java configuration.
- Formatting and patch whitespace passed. Dartdoc reported zero warnings and
  zero errors, and the 0.4.0 publish dry run reported zero warnings.

These are local automated results. Required Android/iOS device evidence and
remote CI for the release commit were outstanding at this pre-publication
checkpoint. The live GitHub Actions run and pub.dev API record their later
outcomes; this snapshot does not claim a device result.

## Historical Verification

The complete local automated RC gate passed on 2026-07-14 with Flutter 3.41.6
and Dart 3.11.4:

- formatting, analysis, and dependency resolution completed successfully;
- 298 package tests passed with fixed seed `20260714` and fresh randomized
  ordering;
- line coverage was 90.9398% (3774 of 4150 lines), above the 90% threshold;
- dartdoc reported zero warnings and zero errors;
- publish dry-run included both README languages in a 421 KB archive and
  reported zero warnings;
- 29 example tests, the Web build, and the Android debug APK build passed.

Both jobs in [GitHub Actions run #9](https://github.com/indie-geeker/super_overlay/actions/runs/29320075868)
passed for source commit `daa9af70608e887f4ee3361eb78a1d851e917d24`,
covering Flutter stable and Flutter 3.29. That run predates the subsequent local
anchor and bilingual-documentation fixes. Any next candidate requires
remote CI for its final commit plus the Android and iOS evidence in the
[device verification matrix](tool/verification/example_device_matrix.md).

## 1. Prepare The Candidate

- Confirm the intended package version in `pubspec.yaml`.
- Confirm `CHANGELOG.md` contains one undated section for the candidate version
  and preserves all published histories.
- Confirm both README installation snippets and `example/pubspec.lock` match
  the candidate version.
- Review breaking changes, migration notes, supported topology, and platform
  tiers.
- Confirm the private vulnerability-reporting path in
  [SECURITY.md](SECURITY.md) is reachable by an external reporter.

## 2. Run Package Gates

From the repository root:

```bash
dart tool/verify.dart --suite full --publish-check
dart tool/verify.dart --suite minimum --flutter /path/to/flutter-3.29/bin/flutter
dart tool/verify.dart --suite router --flutter /path/to/flutter-3.47.4/bin/flutter
```

The shared entry performs the package and example gates in an isolated copy
containing current changes, preserving source lockfiles. Full package tests
combine coverage with seed `20260713`; coverage must stay at or above 90%.
The publish dry run uses the clean copy, so dirty-tree warnings are not mistaken
for package-content failures. Retain its logs/report with
`--output docs/local/verification/candidate`. This command never publishes.

Also run the [go_router 18 fixture](tool/compatibility/go_router_18/README.md)
with Flutter 3.47.4. Do not replace the root go_router 14.8.1 fixture, which
keeps the Flutter 3.29 gate runnable.

## 3. Run Example Gates

```bash
cd example
flutter build apk --debug
cd ..
```

Analysis, tests and all four Web entry builds are already included in the full
gate. The Android build above is a separate platform gate. Build success does
not substitute for the device and software interaction checks below.

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
- Confirm stable Flutter, Flutter 3.29, and go_router 18 compatibility jobs
  are green.
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
