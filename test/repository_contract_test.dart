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

  test('README install and example lock agree with package version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(
          r'^version:\s*([^\s]+)',
          multiLine: true,
        ).firstMatch(pubspec)!.group(1)!;
    final readme = File('README.md').readAsStringSync();
    final exampleLock = File('example/pubspec.lock').readAsStringSync();

    expect(readme, contains('super_overlay: ^$version'));
    expect(
      exampleLock,
      contains(RegExp('super_overlay:[\\s\\S]*?version: "$version"')),
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
