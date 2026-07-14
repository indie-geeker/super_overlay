import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets(
    'nested scoped dialogs suspend resume and close with owner route',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.ensureVisible(find.text('打开嵌套 Navigator 案例'));
      await tester.tap(find.text('打开嵌套 Navigator 案例'));
      await tester.pumpAndSettle();

      expect(find.text('Nested Navigator'), findsWidgets);
      await tester.tap(find.text('显示内层首页 scoped 弹窗'));
      await tester.pumpAndSettle();
      expect(find.text('内层首页 scoped 弹窗'), findsOneWidget);

      await tester.tap(find.text('进入内层详情'));
      await tester.pumpAndSettle();
      expect(find.text('内层详情'), findsWidgets);
      expect(find.text('内层首页 scoped 弹窗'), findsNothing);

      await tester.tap(find.text('返回内层首页'));
      await tester.pumpAndSettle();
      expect(find.text('内层首页 scoped 弹窗'), findsOneWidget);

      await SuperOverlay.close(
        target: OverlayCloseTarget.dialog,
        tag: 'nested-home-dialog',
        force: true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('进入内层详情'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示详情 scoped 弹窗'));
      await tester.pumpAndSettle();
      expect(find.text('详情路由 scoped 弹窗'), findsOneWidget);

      await tester.tap(find.text('返回内层首页'));
      await tester.pumpAndSettle();
      expect(find.text('详情路由 scoped 弹窗'), findsNothing);
      expect(SuperOverlay.exists(tag: 'nested-detail-dialog'), isFalse);
    },
  );
}
