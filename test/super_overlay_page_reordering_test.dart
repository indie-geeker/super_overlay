import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

class _DialogPage extends Page<void> {
  const _DialogPage() : super(key: const ValueKey('Flutter popup'));

  @override
  Route<void> createRoute(BuildContext context) => DialogRoute<void>(
    context: context,
    settings: this,
    builder: (_) => const AlertDialog(content: Text('Flutter popup')),
  );
}

class _PagesHarness {
  final integration = SuperOverlay.integration();
  final navigator = GlobalKey<NavigatorState>();
  final order = ValueNotifier<List<String>>(['A', 'B', 'C']);
  final keys = {
    for (final name in ['A', 'B', 'C', 'D']) name: GlobalKey(),
  };

  Future<void> mount(
    WidgetTester tester, {
    required bool nested,
    bool popupPage = false,
  }) async {
    final observer =
        nested ? integration.navigatorObserver() : integration.observer;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
      order.dispose();
    });
    final pages = ValueListenableBuilder<List<String>>(
      valueListenable: order,
      builder:
          (_, names, _) => Navigator(
            key: navigator,
            observers: [observer],
            pages: [
              for (final name in names)
                MaterialPage<void>(
                  key: ValueKey(name),
                  child: Scaffold(key: keys[name], body: Text('$name page')),
                ),
              if (popupPage) const _DialogPage(),
            ],
            onDidRemovePage: (page) {
              if (!order.value.any((name) => page.key == ValueKey(name))) {
                return;
              }
              order.value = [
                for (final name in order.value)
                  if (page.key != ValueKey(name)) name,
              ];
            },
          ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) =>
                integration.builder(context, nested ? child : pages),
        home: nested ? pages : null,
      ),
    );
    await tester.pumpAndSettle();
  }

  OverlayHandle<String> show(String name, {required bool popup}) {
    final owner = SuperOverlay.of(keys[name]!.currentContext!);
    Widget content(BuildContext context, OverlayHandle<String> handle) =>
        SizedBox(
          width: 240,
          child: TextField(
            key: ValueKey('$name input'),
            decoration: InputDecoration(labelText: '$name overlay'),
          ),
        );
    return popup
        ? owner.popup.show<String>(
          targetContext: keys[name]!.currentContext!,
          builder: content,
        )
        : owner.dialog.show<String>(builder: content);
  }
}

void main() {
  for (final nested in [false, true]) {
    for (final popupPage in [false, true]) {
      for (final mutation in ['insert', 'replace', 'remove']) {
        testWidgets(
          '${nested ? 'nested' : 'root'} $mutation below unchanged top preserves overlay back gate, popup page=$popupPage',
          (tester) async {
            final harness = _PagesHarness();
            await harness.mount(tester, nested: nested, popupPage: popupPage);
            final top =
                popupPage
                    ? ModalRoute.of(tester.element(find.text('Flutter popup')))!
                    : ModalRoute.of(harness.keys['C']!.currentContext!)!;
            final handle = harness.show('C', popup: false);
            await tester.pumpAndSettle();
            await handle.visible;
            expect(top.popDisposition, RoutePopDisposition.doNotPop);

            harness.order.value = switch (mutation) {
              'insert' => ['A', 'D', 'B', 'C'],
              'replace' => ['A', 'D', 'C'],
              _ => ['A', 'C'],
            };
            await tester.pumpAndSettle();
            expect(top.isCurrent, isTrue);
            expect(handle.isVisible, isTrue);
            expect(top.popDisposition, RoutePopDisposition.doNotPop);
            await harness.navigator.currentState!.maybePop();
            await tester.pumpAndSettle();
            await handle.closed;
            expect(handle.isVisible, isFalse);
            expect(top.isCurrent, isTrue);
            expect(find.text('C page'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final popup in [false, true]) {
      testWidgets(
        '${nested ? 'nested' : 'root'} ${popup ? 'popup' : 'dialog'} follows pages reordered below a stable PopupRoute',
        (tester) async {
          final harness = _PagesHarness();
          await harness.mount(tester, nested: nested, popupPage: true);
          final route = ModalRoute.of(
            tester.element(find.text('Flutter popup')),
          );
          final c = harness.show('C', popup: popup);
          final a = harness.show('A', popup: popup);
          await tester.pumpAndSettle();
          await c.visible;
          expect(a.isVisible, isFalse);
          await tester.enterText(
            find.byKey(const ValueKey('C input')),
            'retained under popup',
          );

          harness.order.value = ['C', 'B', 'A'];
          await tester.pumpAndSettle();
          expect(
            ModalRoute.of(tester.element(find.text('Flutter popup'))),
            same(route),
          );
          expect(route!.isCurrent, isTrue);
          expect({'A': a.isVisible, 'C': c.isVisible}, {'A': true, 'C': false});
          await a.visible;
          expect(find.byKey(const ValueKey('C input')), findsNothing);
          expect(find.byKey(const ValueKey('A input')), findsOneWidget);

          harness.order.value = ['A', 'B', 'C'];
          await tester.pumpAndSettle();
          expect(c.isVisible, isTrue);
          expect(a.isVisible, isFalse);
          expect(find.text('retained under popup'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${nested ? 'nested' : 'root'} ${popup ? 'popup' : 'dialog'} follows reordered pages and retains state',
        (tester) async {
          final harness = _PagesHarness();
          await harness.mount(tester, nested: nested);
          final c = harness.show('C', popup: popup);
          await tester.pumpAndSettle();
          await c.visible;
          await tester.enterText(
            find.byKey(const ValueKey('C input')),
            'retained C',
          );

          harness.order.value = ['C', 'A', 'B'];
          await tester.pumpAndSettle();
          expect(
            ModalRoute.of(harness.keys['B']!.currentContext!)!.isCurrent,
            isTrue,
          );
          expect(c.isVisible, isFalse);
          expect(find.byKey(const ValueKey('C input')), findsNothing);
          final b = harness.show('B', popup: popup);
          await tester.pumpAndSettle();
          await b.visible;
          expect(b.isVisible, isTrue);

          // The route order changes a second time without pushing/removing pages.
          harness.order.value = ['B', 'C', 'A'];
          await tester.pumpAndSettle();
          expect(b.isVisible, isFalse);
          expect(c.isVisible, isFalse);
          final a = harness.show('A', popup: popup);
          await tester.pumpAndSettle();
          await a.visible;
          expect(a.isVisible, isTrue);

          // A Flutter PopupRoute must not suspend the active page's overlay.
          final dialogClosed = showDialog<void>(
            context: harness.keys['A']!.currentContext!,
            useRootNavigator: !nested,
            builder: (_) => const AlertDialog(content: Text('Flutter dialog')),
          );
          await tester.pumpAndSettle();
          expect(a.isVisible, isTrue);
          harness.navigator.currentState!.pop();
          await tester.pumpAndSettle();
          await dialogClosed;
          expect(a.isVisible, isTrue);

          // Removing the new top route settles its handle and resumes C.
          harness.order.value = ['B', 'C'];
          await tester.pumpAndSettle();
          await a.closed;
          expect(a.isVisible, isFalse);
          expect(c.isVisible, isTrue);
          expect(b.isVisible, isFalse);
          expect(find.text('retained C'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${nested ? 'nested' : 'root'} pageless routes stay with the page they were pushed from after reordering',
      (tester) async {
        final harness = _PagesHarness();
        await harness.mount(tester, nested: nested);
        harness.order.value = ['C', 'B', 'A'];
        await tester.pumpAndSettle();
        late BuildContext detailContext;
        harness.navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (context) {
              detailContext = context;
              return const Scaffold(body: Text('pageless detail'));
            },
          ),
        );
        await tester.pumpAndSettle();
        final detail = SuperOverlay.of(
          detailContext,
        ).dialog.show<void>(builder: (_, _) => const Text('detail overlay'));
        final a = harness.show('A', popup: false);
        await tester.pumpAndSettle();
        await detail.visible;
        expect(a.isVisible, isFalse);

        // The pageless detail remains attached to A; C now covers that group.
        harness.order.value = ['A', 'B', 'C'];
        await tester.pumpAndSettle();
        expect(detail.isVisible, isFalse);
        final c = harness.show('C', popup: false);
        await tester.pumpAndSettle();
        await c.visible;
        expect(c.isVisible, isTrue);

        harness.order.value = ['C', 'B', 'A'];
        await tester.pumpAndSettle();
        expect(detail.isVisible, isTrue);
        expect(a.isVisible, isFalse);
        expect(c.isVisible, isFalse);
        harness.navigator.currentState!.pop();
        await tester.pumpAndSettle();
        await detail.closed;
        await a.visible;
        expect(a.isVisible, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final popupPage in [false, true]) {
    for (final mutation in ['insert', 'replace', 'remove']) {
      testWidgets(
        'global dialog and popup use actual current route after $mutation below unchanged top, popup page=$popupPage',
        (tester) async {
          final harness = _PagesHarness();
          await harness.mount(tester, nested: false, popupPage: popupPage);
          harness.order.value = switch (mutation) {
            'insert' => ['A', 'D', 'B', 'C'],
            'replace' => ['A', 'D', 'C'],
            _ => ['A', 'C'],
          };
          await tester.pumpAndSettle();
          final dialog = SuperOverlay.dialog.show<void>(
            builder: (_, _) => const Text('global dialog content'),
          );
          final popup = SuperOverlay.popup.show<void>(
            builder: (_, _) => const Text('global popup content'),
            options: OverlayPopupOptions(
              targetPointBuilder: (_, _) => const Offset(240, 180),
            ),
          );
          await tester.pumpAndSettle();
          expect(dialog.isVisible, isTrue);
          expect(popup.isVisible, isTrue);
          await Future.wait([dialog.visible, popup.visible]);
          expect(find.text('global dialog content'), findsOneWidget);
          expect(find.text('global popup content'), findsOneWidget);

          // Removing inactive routes must not close the newly captured owners.
          harness.order.value = ['A', 'C'];
          await tester.pumpAndSettle();
          expect(dialog.isVisible, isTrue);
          expect(popup.isVisible, isTrue);
          harness.navigator.currentState!.pop();
          await tester.pumpAndSettle();
          await Future.wait([dialog.closed, popup.closed]);
          expect(dialog.isVisible, isFalse);
          expect(popup.isVisible, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
