import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('example exposes reference parity demo cases', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SuperOverlay Showcase'), findsOneWidget);

    for (final label in [
      '定点 Popup',
      '替换/调整 Popup',
      '缩放原点 Popup',
      '忽略遮罩区域',
      '默认 Toast',
      '默认 Loading',
      '默认 Notify',
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

    await tester.ensureVisible(find.text('默认 Toast'));
    await tester.tap(find.text('默认 Toast'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Init Toast Style'), findsOneWidget);
    expect(find.text('Init 默认 Toast'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts, force: true);
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
    expect(find.text('Toast Deck'), findsOneWidget);
    expect(find.text('Popup Window'), findsOneWidget);
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

    await tester.ensureVisible(find.text('单个 Toast'));
    await tester.tap(find.text('单个 Toast'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('图标 + 文案'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('多个 Toast'));
    await tester.tap(find.text('多个 Toast'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('同步完成'), findsOneWidget);
    expect(find.text('权限通过'), findsOneWidget);
    expect(find.text('任务加速'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('权限通过')).dy,
      greaterThan(tester.getTopLeft(find.text('同步完成')).dy),
    );
    expect(
      tester.getTopLeft(find.text('任务加速')).dy,
      greaterThan(tester.getTopLeft(find.text('权限通过')).dy),
    );

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('打开选择器'));
    expect(find.text('显示位置'), findsOneWidget);
    expect(find.text('上方'), findsOneWidget);
    expect(find.text('下方'), findsOneWidget);
    expect(find.text('左侧'), findsOneWidget);
    expect(find.text('右侧'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上方'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开选择器'));
    await tester.pumpAndSettle();
    expect(find.text('选择过滤条件'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('选择过滤条件')).dy,
      lessThan(tester.getTopLeft(find.text('打开选择器')).dy),
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
