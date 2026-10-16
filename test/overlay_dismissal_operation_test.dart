import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/src/helper/overlay_dismissal_operation.dart';

void main() {
  test('joined dismissal starts once and claims cleanup once', () async {
    final operation = OverlayDismissalOperation();
    final gate = Completer<void>();
    var starts = 0;
    var cleans = 0;
    void start() => operation.start(
      dismiss: () {
        starts++;
        return gate.future;
      },
      cleanup: () {
        if (operation.beginCleanup()) cleans++;
      },
    );
    start();
    start();
    gate.complete();
    await operation.future;
    expect(starts, 1);
    expect(cleans, 1);
  });

  test(
    'dismissal preserves the first failure when cleanup also fails',
    () async {
      final operation = OverlayDismissalOperation();
      final failure = StateError('dismiss failed');
      final joined = expectLater(operation.future, throwsA(same(failure)));
      operation.start(
        dismiss: () => Future.error(failure),
        cleanup: () {
          throw StateError('cleanup failed');
        },
      );
      await joined;
    },
  );

  test('teardown can settle while dismissal is still in flight', () async {
    final operation = OverlayDismissalOperation();
    final gate = Completer<void>();
    var cleans = 0;
    operation.start(
      dismiss: () => gate.future,
      cleanup: () {
        if (operation.beginCleanup()) cleans++;
      },
    );
    expect(operation.beginCleanup(), isTrue);
    operation.settleForTeardown();
    await operation.future;
    gate.completeError(StateError('late animation failure'));
    await Future<void>.delayed(Duration.zero);
    expect(cleans, 0);
    expect(operation.beginCleanup(), isFalse);
  });
}
