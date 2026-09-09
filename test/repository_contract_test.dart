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

  test('package metadata agrees across package surfaces', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(
          r'^version:\s*([^\s]+)',
          multiLine: true,
        ).firstMatch(pubspec)!.group(1)!;
    final exampleLock = File('example/pubspec.lock').readAsStringSync();

    expect(version, '0.3.1');
    for (final path in ['README.md', 'README.zh-CN.md']) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing.');
      expect(file.readAsStringSync(), contains('super_overlay: ^0.3.1'));
    }
    final superOverlayLock = _packageStanza(exampleLock, 'super_overlay');
    expect(
      superOverlayLock,
      contains(RegExp(r'^    version: "0\.3\.1"$', multiLine: true)),
    );
  });

  test('lock stanza stops before the next package', () {
    const lock = '''
packages:
  super_overlay:
    dependency: "direct main"
    version: "9.9.9"
  another_package:
    dependency: transitive
    version: "0.3.0"
''';

    expect(_packageStanza(lock, 'super_overlay'), isNot(contains('0.3.0')));
  });

  test('changelog separates pending changes from tagged version history', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final headings =
        RegExp(
          r'^##\s+(.+)$',
          multiLine: true,
        ).allMatches(changelog).map((match) => match.group(1)!).toList();

    expect(headings.where((heading) => heading == '0.3.0'), hasLength(1));
    expect(headings.first, '0.3.1');
    expect(headings.where((heading) => heading == '0.3.1'), hasLength(1));
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
    final requiredRows = _manualDataRows(required);
    final claimOnlyRows = _manualDataRows(claimOnly);
    expect(requiredRows, isNotEmpty);
    expect(requiredRows, anyElement(contains(RegExp(r'iPhone|iOS'))));
    expect(requiredRows, anyElement(contains('Android')));
    expect(requiredRows, isNot(anyElement(contains('Desktop'))));
    expect(claimOnlyRows, isNotEmpty);
    expect(claimOnlyRows, anyElement(contains('Desktop')));
    expect(claimOnlyRows, anyElement(contains('Stateful shell')));

    expect(
      _manualEvidenceErrors([...requiredRows, ...claimOnlyRows]),
      isEmpty,
      reason: 'Completed manual rows require device, OS, and linked evidence.',
    );
  });

  test('completed manual rows accept recorded device evidence', () {
    expect(
      _manualEvidenceErrors(const [
        '| [x] | iPhone portrait | Show notification | No overlap | Device: iPhone 16; OS: iOS 18; Evidence: [recording](evidence/iphone.mp4) |',
        '| [X] | Desktop | Keyboard | Focus restored | Platform: macOS; OS: 15.0; Evidence: [screenshot](evidence/mac.png) |',
      ]),
      isEmpty,
    );
  });

  test('completed manual rows reject placeholder or incomplete evidence', () {
    for (final evidence in [
      'Device/OS and screenshot',
      'Device: iPhone 16; OS: iOS 18',
      'Device: TBD; OS: iOS 18; Evidence: [recording](evidence/iphone.mp4)',
      'Device: iPhone 16; OS: iOS 18; Evidence: [recording]()',
    ]) {
      expect(
        _manualEvidenceErrors([
          '| [x] | iPhone | Scenario | Expected | $evidence |',
        ]),
        isNotEmpty,
      );
    }
    expect(
      _manualEvidenceErrors(const [
        '| [ ] | iPhone | Scenario | Expected | Pending |',
      ]),
      isEmpty,
    );
  });

  test('manual data rows ignore prose checkboxes', () {
    const section = '''
Keep documentation tasks [ ] separate from device results.

| Done | Device | Result |
| --- | --- | --- |
| [ ] | iPhone | Pending |
''';

    expect(_manualDataRows(section), ['| [ ] | iPhone | Pending |']);
  });

  test('bilingual README assigns a support tier to every platform', () {
    for (final path in ['README.md', 'README.zh-CN.md']) {
      final readme = File(path).readAsStringSync();
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
            RegExp(
              '\\|\\s*$platform\\s*\\|\\s*(Supported|Best effort|支持|尽力支持)\\s*\\|',
            ),
          ),
          reason: '$path must assign an explicit support tier to $platform.',
        );
      }
    }
  });

  test(
    'example avoids DropdownButtonFormField parameters unavailable in Flutter 3.29',
    () {
      final incompatibleParameter = RegExp(
        r'DropdownButtonFormField(?:<[^>]+>)?\s*\([^;]*\binitialValue\s*:',
        dotAll: true,
      );
      final exampleSources = Directory('example/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in exampleSources) {
        expect(
          file.readAsStringSync(),
          isNot(contains(incompatibleParameter)),
          reason:
              '${file.path} must remain compatible with the minimum Flutter version.',
        );
      }
    },
  );

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

  test('release intake and coverage matrix track the 0.3.1 README', () {
    final issueForm =
        File('.github/ISSUE_TEMPLATE/issue.yml').readAsStringSync();
    final coverageMatrix =
        File('tool/verification/example_coverage_matrix.md').readAsStringSync();

    expect(issueForm, contains('placeholder: "0.3.1"'));
    expect(coverageMatrix, isNot(contains('[Quick Start]')));
    expect(coverageMatrix, isNot(contains('[Conflict Policy]')));
    expect(coverageMatrix, contains('[Install](../../README.md#install)'));
    expect(
      coverageMatrix,
      contains(
        '[Command And Handle Basics](../../README.md#command-and-handle-basics)',
      ),
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

String _packageStanza(String lock, String package) {
  final lines = lock.split('\n');
  final start = lines.indexOf('  $package:');
  if (start < 0) {
    throw StateError('Missing $package in package lock.');
  }

  final nextPackage = lines.indexWhere(
    (line) => RegExp(r'^  [a-zA-Z0-9_]+:$').hasMatch(line),
    start + 1,
  );
  return lines
      .sublist(start, nextPackage < 0 ? lines.length : nextPackage)
      .join('\n');
}

List<String> _manualDataRows(String section) {
  final dataRow = RegExp(r'^\|\s*\[[ xX]\]\s*\|');
  return section
      .split('\n')
      .map((line) => line.trim())
      .where(dataRow.hasMatch)
      .toList();
}

List<String> _manualEvidenceErrors(Iterable<String> rows) {
  final errors = <String>[];
  for (final row in rows) {
    if (RegExp(r'^\|\s*\[ \]\s*\|').hasMatch(row)) {
      continue;
    }
    final cells = row.split('|');
    final evidence = cells[cells.length - 2].trim();
    bool recordedField(String field) {
      final value =
          RegExp(
            '(?:$field):\\s*([^;]+)',
            caseSensitive: false,
          ).firstMatch(evidence)?.group(1)?.trim();
      return value != null &&
          value.isNotEmpty &&
          !RegExp(
            r'^(TBD|pending|unknown|placeholder|n/a)$',
            caseSensitive: false,
          ).hasMatch(value);
    }

    if (!recordedField('Device|Platform') ||
        !recordedField('OS') ||
        !RegExp(
          r'Evidence:\s*\[[^\]]+\]\([^\s)]+\)',
          caseSensitive: false,
        ).hasMatch(evidence)) {
      errors.add(row);
    }
  }
  return errors;
}
