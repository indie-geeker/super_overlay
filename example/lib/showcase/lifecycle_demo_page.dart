import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

class LifecycleDemoPage extends StatefulWidget {
  const LifecycleDemoPage({super.key});

  @override
  State<LifecycleDemoPage> createState() => _LifecycleDemoPageState();
}

class _LifecycleDemoPageState extends State<LifecycleDemoPage> {
  bool _showWidgetTarget = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lifecycle Binding')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FeaturePanel(
              title: '页面绑定',
              subtitle: '新路由覆盖时隐藏，返回后恢复',
              icon: Icons.layers_outlined,
              accent: ShowcaseColors.primary,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _showRouteBoundOverlay,
                    icon: const Icon(Icons.link_outlined),
                    label: const Text('显示页面绑定弹窗'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pushCoveringRoute,
                    icon: const Icon(Icons.vertical_align_top),
                    label: const Text('覆盖新路由'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeaturePanel(
              title: '控件绑定',
              subtitle: '目标控件卸载后 overlay 自动移除',
              icon: Icons.widgets_outlined,
              accent: ShowcaseColors.info,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_showWidgetTarget)
                    Builder(
                      builder: (targetContext) {
                        return FilledButton.icon(
                          onPressed:
                              () => _showWidgetBoundOverlay(targetContext),
                          icon: const Icon(Icons.ads_click_outlined),
                          label: const Text('显示控件绑定弹窗'),
                        );
                      },
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _showWidgetTarget = !_showWidgetTarget);
                    },
                    icon: Icon(
                      _showWidgetTarget
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    label: Text(_showWidgetTarget ? '卸载目标控件' : '恢复目标控件'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeaturePanel(
              title: '返回键处理',
              subtitle: 'normal 关闭、block 阻止、ignore 交给页面',
              icon: Icons.keyboard_return_outlined,
              accent: ShowcaseColors.danger,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed:
                        () => _showBackOverlay(OverlayBackBehavior.dismiss),
                    child: const Text('Back normal'),
                  ),
                  OutlinedButton(
                    onPressed:
                        () => _showBackOverlay(OverlayBackBehavior.block),
                    child: const Text('Back block'),
                  ),
                  OutlinedButton(
                    onPressed:
                        () => _showBackOverlay(OverlayBackBehavior.passThrough),
                    child: const Text('Back ignore'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteBoundOverlay() {
    SuperOverlay.dialog.show<void>(
      builder:
          (_) => const SmallOverlay(
            title: '页面绑定弹窗',
            message: '覆盖新路由时隐藏，返回这个页面时恢复。',
          ),
      options: const OverlayDialogOptions(
        tag: 'route-bound',
        bindToRoute: true,
        alignment: Alignment.bottomCenter,
        barrierColor: Colors.transparent,
        dismissOnMaskTap: false,
        consumeEvents: false,
      ),
    );
  }

  void _pushCoveringRoute() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => Scaffold(
              appBar: AppBar(title: const Text('覆盖路由')),
              body: const Center(child: Text('返回后页面绑定弹窗会重新出现')),
            ),
      ),
    );
  }

  void _showWidgetBoundOverlay(BuildContext targetContext) {
    SuperOverlay.dialog.show<void>(
      builder:
          (_) =>
              const SmallOverlay(title: '控件绑定弹窗', message: '这个弹窗跟随目标控件生命周期。'),
      options: OverlayDialogOptions(
        tag: 'widget-bound',
        bindToWidget: targetContext,
        alignment: Alignment.bottomCenter,
        barrierColor: Colors.transparent,
        dismissOnMaskTap: false,
        consumeEvents: false,
      ),
    );
  }

  void _showBackOverlay(OverlayBackBehavior behavior) {
    SuperOverlay.dialog.show<void>(
      builder:
          (_) => SmallOverlay(
            title: 'OverlayBackBehavior.${behavior.name}',
            message: switch (behavior) {
              OverlayBackBehavior.dismiss => '按返回键会先关闭 overlay。',
              OverlayBackBehavior.block => '按返回键会被 overlay 拦截。',
              OverlayBackBehavior.passThrough => '按返回键交给页面继续处理。',
            },
          ),
      options: OverlayDialogOptions(
        tag: 'back-${behavior.name}',
        backBehavior: behavior,
      ),
    );
  }
}
