import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/src/kit/debounce_utils.dart';
import 'package:super_overlay/src/kit/super_overlay_entry.dart';

void main() {
  test('debounce blocks only the same overlay type', () {
    var now = DateTime(2026);
    final debounce = DebounceUtils(clock: () => now);

    expect(
      debounce.banContinue(
        OverlayDebounceType.custom,
        debounce: true,
        duration: const Duration(milliseconds: 300),
      ),
      isFalse,
    );
    expect(
      debounce.banContinue(
        OverlayDebounceType.custom,
        debounce: true,
        duration: const Duration(milliseconds: 300),
      ),
      isTrue,
    );
    expect(
      debounce.banContinue(
        OverlayDebounceType.toast,
        debounce: true,
        duration: const Duration(milliseconds: 300),
      ),
      isFalse,
    );

    now = now.add(const Duration(milliseconds: 301));
    expect(
      debounce.banContinue(
        OverlayDebounceType.custom,
        debounce: true,
        duration: const Duration(milliseconds: 300),
      ),
      isFalse,
    );
  });

  test('mask debounce is scoped separately', () {
    final debounce = DebounceUtils(clock: () => DateTime(2026));

    expect(debounce.banMaskContinue(), isFalse);
    expect(debounce.banMaskContinue(), isTrue);
    expect(
      debounce.banContinue(
        OverlayDebounceType.custom,
        debounce: true,
        duration: const Duration(milliseconds: 300),
      ),
      isFalse,
    );
  });

  testWidgets('SuperOverlayEntry remove and rebuild are safe after disposal', (
    tester,
  ) async {
    final entry = SuperOverlayEntry(
      builder:
          (_) => const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('entry'),
          ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(initialEntries: [entry]),
      ),
    );
    expect(find.text('entry'), findsOneWidget);

    entry.remove();
    entry.remove();
    entry.markNeedsBuild();
    await tester.pump();

    expect(find.text('entry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
