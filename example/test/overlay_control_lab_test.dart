import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

Future<void> _openControlLab(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  final entry = find.text('打开控制实验室');
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('control lab explains strategies through one repeated action', (
    tester,
  ) async {
    await _openControlLab(tester);

    expect(find.text('Overlay 控制实验室'), findsWidgets);
    expect(find.text('重复触发应该怎样处理？'), findsOneWidget);
    expect(find.text('已经显示的 Overlay 怎样控制？'), findsOneWidget);
    expect(find.text('等待生命周期'), findsOneWidget);
    expect(find.text('Show all notification types'), findsNothing);

    await tester.tap(find.text('模拟连续触发两次'));
    await tester.pumpAndSettle();
    expect(find.text('登录提示 #1'), findsOneWidget);
    expect(find.text('登录提示 #2'), findsOneWidget);
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: 'control-lab-auth',
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保留已有'));
    await tester.tap(find.text('模拟连续触发两次'));
    await tester.pumpAndSettle();
    expect(find.text('登录提示 #1'), findsOneWidget);
    expect(find.text('登录提示 #2'), findsNothing);
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: 'control-lab-auth',
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('替换已有'));
    await tester.tap(find.text('模拟连续触发两次'));
    await tester.pumpAndSettle();
    expect(find.text('登录提示 #1'), findsNothing);
    expect(find.text('登录提示 #2'), findsOneWidget);

    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: 'control-lab-auth',
      force: true,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('upload handle refresh is scoped and preserves external toast', (
    tester,
  ) async {
    await _openControlLab(tester);

    final external = SuperOverlay.toast(
      '外部业务 Toast',
      options: const OverlayToastOptions(
        tag: 'external-owner',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();

    final start = find.text('开始上传');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    expect(find.text('上传进度 0%'), findsOneWidget);
    expect(find.text('外部业务 Toast'), findsOneWidget);

    await tester.tap(find.text('推进进度'));
    await tester.pump();
    expect(find.text('上传进度 35%'), findsOneWidget);
    expect(find.text('外部业务 Toast'), findsOneWidget);

    await tester.tap(find.text('取消上传'));
    await tester.pumpAndSettle();
    expect(find.text('上传进度 35%'), findsNothing);
    expect(find.text('外部业务 Toast'), findsOneWidget);

    await external.close();
    await tester.pumpAndSettle();
  });

  testWidgets('await timeline exposes visible and closed milestones', (
    tester,
  ) async {
    await _openControlLab(tester);

    final start = find.text('开始 Await 演示');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.text('1. Handle 已创建'), findsOneWidget);
    expect(find.text('2. 首帧已经显示'), findsOneWidget);

    await tester.tap(find.text('关闭 Await Overlay'));
    await tester.pumpAndSettle();
    expect(find.text('3. 已请求关闭 Overlay'), findsOneWidget);
    expect(find.text('4. Overlay 已关闭，closed Future 已完成'), findsOneWidget);
  });

  testWidgets('leaving control lab only closes overlays owned by that page', (
    tester,
  ) async {
    await _openControlLab(tester);

    final external = SuperOverlay.toast(
      '页面外部 Overlay',
      options: const OverlayToastOptions(
        tag: 'external-owner',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();

    final start = find.text('开始上传');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    expect(find.text('上传进度 0%'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('上传进度 0%'), findsNothing);
    expect(find.text('页面外部 Overlay'), findsOneWidget);
    expect(external.isVisible, isTrue);

    await external.close();
    await tester.pumpAndSettle();
  });
}
