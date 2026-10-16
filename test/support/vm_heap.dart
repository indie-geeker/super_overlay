import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

class _RealHttp extends HttpOverrides {}

/// Forces collection and returns live instance counts, without timing guesses.
Future<Map<String, int>> collectHeapCounts() async {
  final base = (await developer.Service.getInfo()).serverUri;
  if (base == null) {
    throw StateError(
      'Run retention tests with flutter test --enable-vmservice.',
    );
  }
  // Flutter 3.29 predates getIsolateId.
  // ignore: deprecated_member_use
  final isolate = developer.Service.getIsolateID(Isolate.current)!;
  return HttpOverrides.runWithHttpOverrides(() async {
    final client =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 5)
          ..findProxy = (_) => 'DIRECT';
    try {
      final response =
          await (await client.getUrl(
            base
                .resolve('getAllocationProfile')
                .replace(queryParameters: {'isolateId': isolate, 'gc': 'true'}),
          )).close();
      final data = jsonDecode(await utf8.decodeStream(response)) as Map;
      expect(data['error'], isNull);
      final counts = <String, int>{};
      for (final row in data['result']['members'] as List) {
        final name = row['class']['name'] as String;
        counts[name] = (counts[name] ?? 0) + (row['instancesCurrent'] as int);
      }
      return counts;
    } finally {
      client.close(force: true);
    }
  }, _RealHttp());
}
