import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/verify.dart' as verification;

void main() {
  test(
    'failed command preserves exit status and leaves later steps unrun',
    () async {
      final output = Directory.systemTemp.createTempSync(
        'verify-failure-test-',
      );
      addTearDown(() => output.deleteSync(recursive: true));
      final called = <String>[];
      final code = await verification.runSteps(
        [
          const verification.VerifyStep('first', 'ignored', [], '.'),
          const verification.VerifyStep('failure', 'ignored', [], '.'),
          const verification.VerifyStep('later', 'ignored', [], '.'),
        ],
        output,
        execute: (step, log) async {
          called.add(step.name);
          log.writeAsStringSync('diagnostic');
          return step.name == 'failure' ? 23 : 0;
        },
      );
      expect(code, 23);
      expect(called, ['first', 'failure']);
      final report =
          jsonDecode(File('${output.path}/report.json').readAsStringSync())
              as Map;
      expect(report['steps'][2]['status'], 'not-run');
      expect(report['steps'][1]['exitCode'], 23);
      expect(
        File(report['steps'][1]['log'] as String).readAsStringSync(),
        'diagnostic',
      );
    },
  );

  test(
    'copy includes current source but excludes caches, local evidence and Git',
    () {
      final directory = Directory.systemTemp.createTempSync(
        'verify-copy-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final source = Directory('${directory.path}/source')..createSync();
      for (final path in [
        'lib/new.dart',
        'docs/plans/team.md',
        'docs/local/raw.json',
        '.git/config',
        'build/generated.dart',
      ]) {
        final file = File('${source.path}/$path');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('new work');
      }
      final target = Directory('${directory.path}/target');
      verification.copySource(source, target);
      expect(
        File('${target.path}/lib/new.dart').readAsStringSync(),
        'new work',
      );
      expect(File('${target.path}/docs/plans/team.md').existsSync(), isTrue);
      expect(Directory('${target.path}/docs/local').existsSync(), isFalse);
      expect(Directory('${target.path}/.git').existsSync(), isFalse);
      expect(Directory('${target.path}/build').existsSync(), isFalse);
    },
  );
}
