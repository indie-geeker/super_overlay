import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('example application source contains no Han characters', () {
    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final han = RegExp(r'[\u3400-\u9fff]');
    final violations = <String>[];

    for (final file in sourceFiles) {
      if (han.hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty, reason: 'Untranslated source: $violations');
  });
}
