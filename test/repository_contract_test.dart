import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runtime dependencies stay Flutter-only and go_router stays dev-only',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final runtimeDependencies = _dependencyNames(pubspec, 'dependencies');
      final devDependencies = _dependencyNames(pubspec, 'dev_dependencies');

      expect(runtimeDependencies, {'flutter'});
      expect(devDependencies, contains('go_router'));
      expect(runtimeDependencies, isNot(contains('go_router')));
    },
  );

  test('0.3.0 candidate metadata agrees across package surfaces', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(
          r'^version:\s*([^\s]+)',
          multiLine: true,
        ).firstMatch(pubspec)!.group(1)!;
    final readme = File('README.md').readAsStringSync();
    final exampleLock = File('example/pubspec.lock').readAsStringSync();

    expect(version, '0.3.0');
    expect(readme, contains('super_overlay: ^0.3.0'));
    expect(
      exampleLock,
      contains(RegExp('super_overlay:[\\s\\S]*?version: "0.3.0"')),
    );
  });

  test('changelog has one unpublished 0.3.0 section before 0.2.0', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final headings =
        RegExp(
          r'^##\s+(.+)$',
          multiLine: true,
        ).allMatches(changelog).map((match) => match.group(1)!).toList();

    expect(headings.where((heading) => heading == '0.3.0'), hasLength(1));
    expect(headings, isNot(contains('Unreleased')));
    expect(headings, contains('0.2.0'));
    expect(headings.indexOf('0.3.0'), lessThan(headings.indexOf('0.2.0')));
  });

  test('device evidence separates mobile blockers from claim-only rows', () {
    final matrix =
        File('tool/verification/example_device_matrix.md').readAsStringSync();
    const requiredHeading = '## Required Mobile Release Blockers';
    const claimOnlyHeading = '## Claim-Only And Optional Evidence';
    final requiredStart = matrix.indexOf(requiredHeading);
    final claimOnlyStart = matrix.indexOf(claimOnlyHeading);

    expect(requiredStart, greaterThanOrEqualTo(0));
    expect(claimOnlyStart, greaterThan(requiredStart));

    final required = matrix.substring(requiredStart, claimOnlyStart);
    final claimOnly = matrix.substring(claimOnlyStart);
    expect(required, contains(RegExp(r'iPhone|iOS')));
    expect(required, contains('Android'));
    expect(required, isNot(contains('Desktop')));
    expect(claimOnly, contains('Desktop'));
    expect(claimOnly, contains('Stateful shell'));

    final manualResults = RegExp(r'\[[ xX]\]').allMatches(matrix).toList();
    expect(manualResults, isNotEmpty);
    expect(
      manualResults.map((match) => match.group(0)).toSet(),
      {'[ ]'},
      reason:
          'Manual evidence must stay pending until a maintainer records it.',
    );
  });

  test('README assigns an explicit support tier to every platform', () {
    final readme = File('README.md').readAsStringSync();
    for (final platform in [
      'Android',
      'iOS',
      'Web',
      'macOS',
      'Windows',
      'Linux',
    ]) {
      expect(
        readme,
        contains(
          RegExp('\\|\\s*$platform\\s*\\|\\s*(Supported|Best effort)\\s*\\|'),
        ),
        reason: '$platform needs an explicit support tier.',
      );
    }
  });

  test('focus docs keep Escape local to the focused overlay', () {
    final options = File('lib/src/api/overlay_options.dart').readAsStringSync();

    for (final className in [
      'OverlayDialogOptions',
      'OverlayPopupOptions',
      'OverlayLoadingOptions',
    ]) {
      final start = options.indexOf('class $className');
      final nextClass = options.indexOf('\nclass ', start + 1);
      final section = options.substring(
        start,
        nextClass < 0 ? options.length : nextClass,
      );

      expect(
        section,
        contains('initial focus capture'),
        reason: '$className must document requestFocus.',
      );
      expect(
        section,
        contains('focus is inside the overlay'),
        reason: '$className must scope Escape handling to overlay focus.',
      );
      expect(
        section,
        contains('Escape remains with the page'),
        reason: '$className must document requestFocus: false.',
      );
    }

    final readme = File('README.md').readAsStringSync();
    expect(readme, contains('Escape is focus-local'));
    expect(readme, contains('Escape remains with the page'));
  });

  test('issue intake requires commercial-quality reproduction fields', () {
    final issueForm =
        File('.github/ISSUE_TEMPLATE/issue.yml').readAsStringSync();
    for (final id in [
      'version',
      'flutter',
      'reproduction',
      'expected',
      'actual',
    ]) {
      expect(issueForm, contains('id: $id'));
    }
    expect(
      RegExp(
        r'validations:\s*\n\s+required: true',
      ).allMatches(issueForm).length,
      greaterThanOrEqualTo(5),
    );
    expect(
      File('.github/ISSUE_TEMPLATE/config.yml').readAsStringSync(),
      contains('blank_issues_enabled: false'),
    );
  });
}

Set<String> _dependencyNames(String pubspec, String section) {
  final lines = pubspec.split('\n');
  final start = lines.indexWhere((line) => line == '$section:');
  if (start < 0) {
    throw StateError('Missing $section in pubspec.yaml.');
  }

  final names = <String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.isNotEmpty && !line.startsWith(' ')) {
      break;
    }
    final match = RegExp(r'^  ([a-zA-Z0-9_]+):').firstMatch(line);
    if (match != null) {
      names.add(match.group(1)!);
    }
  }
  return names;
}
