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
            title: 'Nested Home',
            subtitle:
                'SuperOverlay.of(context) captures the owner below the target Navigator',
            icon: Icons.home_work_outlined,
            accent: ShowcaseColors.primary,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: () => _showScopedDialog(context),
                  child: const Text('Show Nested Home Scoped Dialog'),
                ),
                OutlinedButton(
                  onPressed:
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(name: 'nested-detail'),
                          builder: (_) => const _NestedDetailPage(),
                        ),
                      ),
                  child: const Text('Open Nested Detail'),
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
            title: 'Nested Home Scoped Dialog',
            message:
                'It suspends on the detail route and returns with Nested Home.',
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
            title: 'Nested Detail',
            subtitle: 'The detail dialog closes when its owner route is popped',
            icon: Icons.article_outlined,
            accent: ShowcaseColors.info,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: () => _showScopedDialog(context),
                  child: const Text('Show Detail Scoped Dialog'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Nested Home'),
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
            title: 'Detail Route Scoped Dialog',
            message:
                'This record closes with the detail owner route when returning home.',
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
