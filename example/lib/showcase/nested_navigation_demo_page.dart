import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

class NestedNavigationDemoPage extends StatefulWidget {
  const NestedNavigationDemoPage({super.key, required this.integration});

  final SuperOverlayIntegration integration;

  @override
  State<NestedNavigationDemoPage> createState() =>
      _NestedNavigationDemoPageState();
}

class _NestedNavigationDemoPageState extends State<NestedNavigationDemoPage> {
  late final SuperOverlayNavigatorObserver _observer;

  @override
  void initState() {
    super.initState();
    _observer = widget.integration.navigatorObserver();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nested Navigator')),
      body: Navigator(
        observers: [_observer],
        onGenerateRoute:
            (_) => MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'nested-home'),
              builder: (_) => const _NestedHomePage(),
            ),
      ),
    );
  }

  @override
  void dispose() {
    _observer.dispose();
    super.dispose();
  }
}

class _NestedHomePage extends StatelessWidget {
  const _NestedHomePage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeaturePanel(
            title: '内层首页',
            subtitle: 'SuperOverlay.of(context) 从目标 Navigator 下方捕获 owner',
            icon: Icons.home_work_outlined,
            accent: ShowcaseColors.primary,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: () => _showScopedDialog(context),
                  child: const Text('显示内层首页 scoped 弹窗'),
                ),
                OutlinedButton(
                  onPressed:
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(name: 'nested-detail'),
                          builder: (_) => const _NestedDetailPage(),
                        ),
                      ),
                  child: const Text('进入内层详情'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showScopedDialog(BuildContext context) {
    SuperOverlay.of(context).dialog.show<void>(
      builder:
          (_) => const SmallOverlay(
            title: '内层首页 scoped 弹窗',
            message: '进入详情时挂起，返回内层首页后恢复。',
          ),
      options: const OverlayDialogOptions(
        tag: 'nested-home-dialog',
        alignment: Alignment.bottomCenter,
        barrierColor: Colors.transparent,
        dismissOnMaskTap: false,
        consumeEvents: false,
        requestFocus: false,
      ),
    );
  }
}

class _NestedDetailPage extends StatelessWidget {
  const _NestedDetailPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeaturePanel(
            title: '内层详情',
            subtitle: '详情路由弹窗会在该 owner route pop 时关闭',
            icon: Icons.article_outlined,
            accent: ShowcaseColors.info,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: () => _showScopedDialog(context),
                  child: const Text('显示详情 scoped 弹窗'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回内层首页'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showScopedDialog(BuildContext context) {
    SuperOverlay.of(context).dialog.show<void>(
      builder:
          (_) => const SmallOverlay(
            title: '详情路由 scoped 弹窗',
            message: '返回内层首页时，这条记录随详情 owner route 一起关闭。',
          ),
      options: const OverlayDialogOptions(
        tag: 'nested-detail-dialog',
        alignment: Alignment.bottomCenter,
        barrierColor: Colors.transparent,
        dismissOnMaskTap: false,
        consumeEvents: false,
        requestFocus: false,
      ),
    );
  }
}
