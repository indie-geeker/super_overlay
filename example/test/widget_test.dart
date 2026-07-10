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

    for (final label in [
      '定点 Popup',
      '替换/调整 Popup',
      '缩放原点 Popup',
      '忽略遮罩区域',
      '替换最新',
      '依次排队',
      '同时显示',
      '显示通知',
      'Await 事件',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.ensureVisible(find.text('定点 Popup'));
    await tester.tap(find.text('定点 Popup'));
    await tester.pumpAndSettle();
    expect(find.text('定点 Popup 内容'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allPopups, force: true);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('运行 Toast 演示'));
    await tester.tap(find.text('运行 Toast 演示'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('保存结果 3'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts, force: true);
    await tester.pumpAndSettle();
  });

  testWidgets('mask ignore popup passes only taps inside the top strip', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('忽略遮罩区域'));
    await tester.tap(find.text('忽略遮罩区域'));
    await tester.pumpAndSettle();
    expect(find.text('忽略遮罩 Popup 内容'), findsOneWidget);

    await tester.tap(find.byTooltip('Notify'));
    await tester.pump();
    expect(find.text('Notify message'), findsOneWidget);
    expect(find.text('忽略遮罩 Popup 内容'), findsOneWidget);

    await tester.tapAt(const Offset(10, 150));
    await tester.pumpAndSettle();
    expect(find.text('忽略遮罩 Popup 内容'), findsNothing);

    await SuperOverlay.close(
      target: OverlayCloseTarget.allNotifications,
      force: true,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('example demonstrates the SuperOverlay feature set', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SuperOverlay Showcase'), findsOneWidget);
    expect(find.text('super_overlay'), findsOneWidget);
    expect(find.text('Overlay features in one place'), findsNothing);
    expect(find.text('Dialog Lab'), findsOneWidget);
    expect(find.text('即时反馈'), findsOneWidget);
    expect(find.text('锚点菜单'), findsOneWidget);
    expect(find.text('Guided Mask'), findsOneWidget);
    expect(find.text('Lifecycle Binding'), findsOneWidget);
    expect(find.text('Network State Demo'), findsOneWidget);

    await tester.ensureVisible(find.text('打开自定义弹窗'));
    await tester.tap(find.text('打开自定义弹窗'));
    await tester.pumpAndSettle();
    expect(find.text('自定义弹窗'), findsOneWidget);

    await tester.tap(find.text('关闭弹窗'));
    await tester.pumpAndSettle();
    expect(find.text('自定义弹窗'), findsNothing);

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

  testWidgets('command contracts page demonstrates public lifecycle APIs', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('打开命令契约案例'));
    await tester.tap(find.text('打开命令契约案例'));
    await tester.pumpAndSettle();

    expect(find.text('Command Contracts'), findsWidgets);
    expect(find.text('Tagged strategies'), findsOneWidget);
    expect(find.text('Handle + exists'), findsOneWidget);
    expect(find.text('Refresh active toast'), findsOneWidget);
    expect(find.text('Notifications + cleanup'), findsOneWidget);

    await tester.tap(find.text('Stack tagged dialogs'));
    await tester.pumpAndSettle();
    expect(find.text('Stacked dialog A'), findsOneWidget);
    expect(find.text('Stacked dialog B'), findsOneWidget);
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep existing dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Kept original dialog'), findsOneWidget);
    expect(find.text('Ignored duplicate dialog'), findsNothing);
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace tagged dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Replacement loser'), findsNothing);
    expect(find.text('Replacement winner'), findsOneWidget);
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Show owned handle'));
    await tester.tap(find.text('Show owned handle'));
    await tester.pumpAndSettle();
    expect(find.text('Owned handle revision 0'), findsOneWidget);
    expect(find.text('exists(contracts-owned): true'), findsOneWidget);

    await tester.tap(find.text('Refresh owned handle'));
    await tester.pump();
    expect(find.text('Owned handle revision 1'), findsOneWidget);

    await tester.tap(find.text('Close owned handle'));
    await tester.pumpAndSettle();
    expect(find.text('Owned handle revision 1'), findsNothing);
    expect(find.text('exists(contracts-owned): false'), findsOneWidget);

    await tester.ensureVisible(find.text('Start refresh toast'));
    await tester.tap(find.text('Start refresh toast'));
    await tester.pump();
    expect(find.text('Refresh active toast #1'), findsOneWidget);

    await tester.tap(find.text('Update refresh toast'));
    await tester.pump();
    expect(find.text('Refresh active toast #1'), findsNothing);
    expect(find.text('Refresh active toast #2'), findsOneWidget);

    await tester.ensureVisible(find.text('Show all notification types'));
    await tester.tap(find.text('Show all notification types'));
    await tester.pump();
    for (final message in [
      'Success notification',
      'Failure notification',
      'Warning notification',
      'Error notification',
      'Alert notification',
    ]) {
      expect(find.text(message), findsOneWidget);
    }

    await tester.tap(find.text('Cleanup all overlays'));
    await tester.pumpAndSettle();
    expect(find.text('Refresh active toast #2'), findsNothing);
    expect(find.text('Success notification'), findsNothing);
    expect(find.text('All overlays closed'), findsOneWidget);
  });

  testWidgets('leaving command contracts preserves overlays owned elsewhere', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('打开命令契约案例'));
    await tester.tap(find.text('打开命令契约案例'));
    await tester.pumpAndSettle();

    final external = SuperOverlay.toast(
      'Externally owned toast',
      options: const OverlayToastOptions(
        tag: 'external-owner',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();
    expect(find.text('Externally owned toast'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Externally owned toast'), findsOneWidget);
    expect(external.isVisible, isTrue);

    final close = external.close();
    await tester.pumpAndSettle();
    await close;
  });
}
