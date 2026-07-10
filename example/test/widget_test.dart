import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('custom notify keeps a visual gap below the safe area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(const MyApp());
    final handles = [
      SuperOverlay.notify.success('success'),
      SuperOverlay.notify.failure('failure'),
      SuperOverlay.notify.warning('warning'),
      SuperOverlay.notify.error('error'),
      SuperOverlay.notify.alert('alert'),
    ];
    await tester.pump();

    for (final type in OverlayNotificationType.values) {
      final surface = find.byKey(ValueKey('init-notify-${type.name}'));
      expect(surface, findsOneWidget);
      expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(56));
    }

    await SuperOverlay.close(
      target: OverlayCloseTarget.allNotifications,
      force: true,
    );
    await Future.wait(handles.map((handle) => handle.closed));
  });

  testWidgets('example exposes reference parity demo cases', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SuperOverlay Showcase'), findsOneWidget);

    for (final label in ['替换最新', '依次排队', '同时显示', '显示通知', '打开控制实验室']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.ensureVisible(find.text('运行 Toast 演示'));
    await tester.tap(find.text('运行 Toast 演示'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('保存结果 3'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts, force: true);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('打开控制实验室'));
    await tester.tap(find.text('打开控制实验室'));
    await tester.pumpAndSettle();

    for (final label in ['定点 Popup', '替换/调整 Popup', '缩放原点 Popup', '忽略遮罩区域']) {
      await tester.ensureVisible(find.text(label));
      expect(find.text(label), findsOneWidget);
    }

    await tester.ensureVisible(find.text('定点 Popup'));
    await tester.tap(find.text('定点 Popup'));
    await tester.pumpAndSettle();
    expect(find.text('定点 Popup 内容'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allPopups, force: true);
    await tester.pumpAndSettle();
  });

  testWidgets('mask ignore popup passes only taps inside the top strip', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('打开控制实验室'));
    await tester.tap(find.text('打开控制实验室'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('忽略遮罩区域'));
    await tester.tap(find.text('忽略遮罩区域'));
    await tester.pumpAndSettle();
    expect(find.text('顶部 96px 不被遮罩拦截'), findsOneWidget);

    await tester.tapAt(const Offset(28, 28));
    await tester.pumpAndSettle();
    expect(find.text('SuperOverlay Showcase'), findsOneWidget);

    await tester.ensureVisible(find.text('打开控制实验室'));
    await tester.tap(find.text('打开控制实验室'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('忽略遮罩区域'));
    await tester.tap(find.text('忽略遮罩区域'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 150));
    await tester.pumpAndSettle();
    expect(find.text('顶部 96px 不被遮罩拦截'), findsNothing);
  });

  testWidgets('example demonstrates the SuperOverlay feature set', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SuperOverlay Showcase'), findsOneWidget);
    expect(find.text('super_overlay'), findsOneWidget);
    expect(find.text('Overlay features in one place'), findsNothing);
    expect(find.text('自定义弹窗'), findsOneWidget);
    expect(find.text('即时反馈'), findsOneWidget);
    expect(find.text('锚点菜单'), findsOneWidget);
    expect(find.text('高亮引导'), findsOneWidget);
    expect(find.text('生命周期绑定'), findsOneWidget);
    expect(find.text('网络请求状态'), findsOneWidget);

    await tester.ensureVisible(find.text('打开自定义弹窗'));
    await tester.tap(find.text('打开自定义弹窗'));
    await tester.pumpAndSettle();
    expect(find.text('自定义弹窗'), findsNWidgets(2));

    await tester.tap(find.text('关闭弹窗'));
    await tester.pumpAndSettle();
    expect(find.text('自定义弹窗'), findsOneWidget);

    await tester.ensureVisible(find.text('运行 Toast 演示'));
    await tester.tap(find.text('运行 Toast 演示'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('保存结果 3'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('同时显示'));
    await tester.tap(find.text('同时显示'));
    await tester.tap(find.text('运行 Toast 演示'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('后台同步完成'), findsOneWidget);
    expect(find.text('权限校验通过'), findsOneWidget);
    expect(find.text('缓存预热完成'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('权限校验通过')).dy,
      greaterThan(tester.getTopLeft(find.text('后台同步完成')).dy),
    );
    expect(
      tester.getTopLeft(find.text('缓存预热完成')).dy,
      greaterThan(tester.getTopLeft(find.text('权限校验通过')).dy),
    );

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    await tester.pumpAndSettle();

    final sortTrigger = find.byKey(const ValueKey('sort-menu-trigger'));
    await tester.ensureVisible(sortTrigger);
    await tester.tap(sortTrigger);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sort-menu-popup')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('sort-menu-popup'))).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(sortTrigger).dy),
    );

    await SuperOverlay.close(target: OverlayCloseTarget.allPopups);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('高亮入口'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始引导'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 步'), findsOneWidget);

    await tester.tap(find.text('高亮入口'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 步'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allPopups, force: true);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('打开生命周期案例'));
    await tester.tap(find.text('打开生命周期案例'));
    await tester.pumpAndSettle();
    expect(find.text('Lifecycle Binding'), findsWidgets);

    await tester.tap(find.text('显示页面绑定弹窗'));
    await tester.pumpAndSettle();
    expect(find.text('页面绑定弹窗'), findsOneWidget);

    await tester.tap(find.text('覆盖新路由'));
    await tester.pumpAndSettle();
    expect(find.text('覆盖路由'), findsOneWidget);
    expect(find.text('页面绑定弹窗'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('页面绑定弹窗'), findsOneWidget);

    await SuperOverlay.close(
      target: OverlayCloseTarget.dialog,
      tag: 'route-bound',
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('显示控件绑定弹窗'));
    await tester.pumpAndSettle();
    expect(find.text('控件绑定弹窗'), findsOneWidget);

    await tester.tap(find.text('卸载目标控件'));
    await tester.pump();
    await tester.pump();
    expect(find.text('控件绑定弹窗'), findsNothing);
    expect(find.text('恢复目标控件'), findsOneWidget);
  });

  testWidgets(
    'network state demo shows request loading, empty page, error page, and image states',
    (tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.ensureVisible(find.text('打开网络状态案例'));
      await tester.tap(find.text('打开网络状态案例'));
      await tester.pumpAndSettle();

      expect(find.text('Network State Demo'), findsWidgets);
      expect(find.text('加载数据'), findsOneWidget);

      await tester.tap(find.text('加载数据'));
      await tester.pump();
      expect(find.text('加载商品列表...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('加载完成'), findsOneWidget);
      expect(find.text('山地徒步背包'), findsOneWidget);
      expect(find.text('图片加载中'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('图片加载完成'), findsWidgets);
      expect(find.text('图片加载失败'), findsOneWidget);

      await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
      await tester.pumpAndSettle();

      await tester.tap(find.text('空数据'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('加载数据'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('暂无数据'), findsOneWidget);
      expect(find.text('当前筛选条件没有返回内容'), findsOneWidget);

      await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
      await tester.pumpAndSettle();

      await tester.tap(find.text('失败'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('加载数据'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('远程服务暂时不可用，请稍后重试。'), findsOneWidget);
      expect(find.text('重新加载'), findsOneWidget);

      await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
      await tester.pumpAndSettle();
    },
  );
}
