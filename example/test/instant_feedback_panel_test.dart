import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('instant feedback separates policy state from its run action', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('即时反馈'), findsOneWidget);
    expect(find.text('替换最新'), findsOneWidget);
    expect(find.text('依次排队'), findsOneWidget);
    expect(find.text('同时显示'), findsOneWidget);
    expect(find.text('运行 Toast 演示'), findsOneWidget);

    await tester.ensureVisible(find.text('运行 Toast 演示'));
    await tester.tap(find.text('运行 Toast 演示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('保存结果 3'), findsOneWidget);
    expect(find.text('保存结果 1'), findsNothing);

    await _closeFeedback(tester);
  });

  testWidgets('instant feedback queues upload results in order', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('依次排队'));
    await tester.tap(find.text('依次排队'));
    await tester.tap(find.text('运行 Toast 演示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('文件 1 已上传'), findsOneWidget);
    expect(find.text('文件 2 已上传'), findsNothing);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();

    expect(find.text('文件 1 已上传'), findsNothing);
    expect(find.text('文件 2 已上传'), findsOneWidget);

    await _closeFeedback(tester);
  });

  testWidgets('instant feedback stacks parallel task results', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('同时显示'));
    await tester.tap(find.text('同时显示'));
    await tester.tap(find.text('运行 Toast 演示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (final message in ['后台同步完成', '权限校验通过', '缓存预热完成']) {
      expect(find.text(message), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('权限校验通过')).dy,
      greaterThan(tester.getTopLeft(find.text('后台同步完成')).dy),
    );

    await _closeFeedback(tester);
  });

  testWidgets('instant feedback replaces the selected notification type', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('显示通知'));
    await tester.tap(find.text('显示通知'));
    await tester.pump();
    expect(find.text('成功通知：操作已完成'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('feedback-notification-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('错误').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示通知'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('成功通知：操作已完成'), findsNothing);
    expect(find.text('错误通知：操作失败'), findsOneWidget);

    await _closeFeedback(tester);
  });

  testWidgets(
    'refreshActive updates its lane while handle.refresh owns separate content',
    (tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.ensureVisible(find.text('创建两类刷新 Toast'));
      await tester.tap(find.text('创建两类刷新 Toast'));
      await tester.pumpAndSettle();
      expect(find.text('refreshActive 内容 1'), findsOneWidget);
      expect(find.text('Handle 内容 1'), findsOneWidget);

      await tester.tap(find.text('运行 refreshActive'));
      await tester.pumpAndSettle();
      expect(find.text('refreshActive 内容 1'), findsNothing);
      expect(find.text('refreshActive 内容 2'), findsOneWidget);
      expect(find.text('Handle 内容 1'), findsOneWidget);

      await tester.tap(find.text('调用 handle.refresh()'));
      await tester.pumpAndSettle();
      expect(find.text('refreshActive 内容 2'), findsOneWidget);
      expect(find.text('Handle 内容 1'), findsNothing);
      expect(find.text('Handle 内容 2'), findsOneWidget);

      await _closeFeedback(tester);
    },
  );
}

Future<void> _closeFeedback(WidgetTester tester) async {
  await SuperOverlay.close(target: OverlayCloseTarget.allToasts, force: true);
  await SuperOverlay.close(
    target: OverlayCloseTarget.allNotifications,
    force: true,
  );
  await tester.pumpAndSettle();
}
