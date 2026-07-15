import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('confirmation dialog reports bool through handle.closed', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('打开确认弹窗'));
    await tester.tap(find.text('打开确认弹窗'));
    await tester.pumpAndSettle();

    expect(find.text('确认本次操作？'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('handle.closed 返回结果：true'), findsOneWidget);
    expect(find.text('确认本次操作？'), findsNothing);

    await tester.tap(find.text('打开确认弹窗'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('handle.closed 返回结果：false'), findsOneWidget);
    expect(find.text('确认本次操作？'), findsNothing);
  });

  testWidgets(
    'confirmation dialog exposes modal semantics and keyboard close',
    (tester) async {
      await _withSemantics(tester, () async {
        await tester.pumpWidget(const MyApp());

        await tester.ensureVisible(find.text('打开确认弹窗'));
        await tester.tap(find.text('打开确认弹窗'));
        await tester.pumpAndSettle();

        final routeNode = _semanticsNodeWithLabel(tester, '确认操作对话框');
        expect(routeNode, isNotNull);
        expect(
          _hasSemanticsFlag(routeNode!, SemanticsFlag.scopesRoute),
          isTrue,
        );
        final barrierNode = _semanticsNodeWithLabel(tester, '关闭确认操作对话框');
        expect(barrierNode, isNotNull);
        expect(
          barrierNode!.getSemanticsData().hasAction(SemanticsAction.dismiss),
          isTrue,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final cancelNode = _semanticsNodeWithLabel(tester, '取消');
        expect(cancelNode, isNotNull);
        expect(_hasSemanticsFlag(cancelNode!, SemanticsFlag.isFocused), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('确认本次操作？'), findsNothing);
      });
    },
  );

  testWidgets('non-dismissible dialog exposes a descriptive barrier', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      await tester.pumpWidget(const MyApp());

      await tester.ensureVisible(find.text('点击弹窗外部允许关闭'));
      await tester.tap(find.text('点击弹窗外部允许关闭'));
      await tester.pump();
      await tester.tap(find.text('打开确认弹窗'));
      await tester.pumpAndSettle();

      final barrierNode = _semanticsNodeWithLabel(tester, '确认操作对话框背景');
      expect(barrierNode, isNotNull);
      expect(
        barrierNode!.getSemanticsData().hasAction(SemanticsAction.dismiss),
        isFalse,
      );
      expect(_semanticsNodeWithLabel(tester, '关闭确认操作对话框'), isNull);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });
  });
}

Future<void> _withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final semantics = tester.ensureSemantics();
  var disposed = false;

  void disposeSemantics() {
    if (disposed) {
      return;
    }
    disposed = true;
    semantics.dispose();
  }

  addTearDown(disposeSemantics);
  try {
    await body();
  } finally {
    // WidgetTester verifies handles before package:test runs addTearDown.
    disposeSemantics();
  }
}

SemanticsNode? _semanticsNodeWithLabel(WidgetTester tester, String label) {
  // Flutter 3.29 does not yet expose rootPipelineOwner on the test binding.
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root == null) {
    return null;
  }
  SemanticsNode? match;

  bool visit(SemanticsNode node) {
    if (node.getSemanticsData().label == label) {
      match = node;
      return false;
    }
    node.visitChildren(visit);
    return match == null;
  }

  visit(root);
  return match;
}

bool _hasSemanticsFlag(SemanticsNode node, SemanticsFlag flag) {
  // Flutter 3.29 exposes only the bit-mask compatibility lookup.
  // ignore: deprecated_member_use
  return node.getSemanticsData().hasFlag(flag);
}
