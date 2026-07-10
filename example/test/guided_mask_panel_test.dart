import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/showcase/guided_mask_panel.dart';

void main() {
  testWidgets('disposing the guide panel closes its completion toast', (
    tester,
  ) async {
    await tester.pumpWidget(const _GuideOwnershipHarness());

    await tester.tap(find.text('开始引导'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('高亮入口'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('配置参数'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('状态面板'));
    await tester.pumpAndSettle();

    expect(find.text('引导已完成'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-guide-panel')));
    await tester.pumpAndSettle();

    expect(find.text('引导已完成'), findsNothing);
  });
}

class _GuideOwnershipHarness extends StatefulWidget {
  const _GuideOwnershipHarness();

  @override
  State<_GuideOwnershipHarness> createState() => _GuideOwnershipHarnessState();
}

class _GuideOwnershipHarnessState extends State<_GuideOwnershipHarness> {
  var _showGuide = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: SuperOverlay.init(),
      navigatorObservers: [SuperOverlay.observer],
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextButton(
                  key: const ValueKey('remove-guide-panel'),
                  onPressed: () => setState(() => _showGuide = false),
                  child: const Text('移除引导面板'),
                ),
                if (_showGuide) const GuidedMaskPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
