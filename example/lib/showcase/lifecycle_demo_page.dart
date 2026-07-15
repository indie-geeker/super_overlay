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
              title: 'Route Binding',
              subtitle: 'Hides under a covering route and returns afterward',
              icon: Icons.layers_outlined,
              accent: ShowcaseColors.primary,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _showRouteBoundOverlay,
                    icon: const Icon(Icons.link_outlined),
                    label: const Text('Show Route-bound Dialog'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pushCoveringRoute,
                    icon: const Icon(Icons.vertical_align_top),
                    label: const Text('Push Covering Route'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeaturePanel(
              title: 'Widget Binding',
              subtitle: 'The overlay closes when its target widget unmounts',
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
                          label: const Text('Show Widget-bound Dialog'),
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
                    label: Text(
                      _showWidgetTarget
                          ? 'Remove Target Widget'
                          : 'Restore Target Widget',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeaturePanel(
              title: 'Back Handling',
              subtitle:
                  'dismiss closes, block intercepts, and passThrough defers to the page',
              icon: Icons.keyboard_return_outlined,
              accent: ShowcaseColors.danger,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed:
                        () => _showBackOverlay(OverlayBackBehavior.dismiss),
                    child: const Text('Back dismiss'),
                  ),
                  OutlinedButton(
                    onPressed:
                        () => _showBackOverlay(OverlayBackBehavior.block),
                    child: const Text('Back block'),
                  ),
                  OutlinedButton(
                    onPressed:
                        () => _showBackOverlay(OverlayBackBehavior.passThrough),
                    child: const Text('Back passThrough'),
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
            title: 'Route-bound Dialog',
            message:
                'It hides under a covering route and returns with this page.',
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
              appBar: AppBar(title: const Text('Covering Route')),
              body: const Center(
                child: Text(
                  'The route-bound dialog returns after you go back.',
                ),
              ),
            ),
      ),
    );
  }

  void _showWidgetBoundOverlay(BuildContext targetContext) {
    SuperOverlay.dialog.show<void>(
      builder:
          (_) => const SmallOverlay(
            title: 'Widget-bound Dialog',
            message: 'This dialog follows the target widget lifecycle.',
          ),
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
              OverlayBackBehavior.dismiss =>
                'The back action closes the overlay first.',
              OverlayBackBehavior.block =>
                'The overlay intercepts the back action.',
              OverlayBackBehavior.passThrough =>
                'The page continues handling the back action.',
            },
          ),
      options: OverlayDialogOptions(
        tag: 'back-${behavior.name}',
        backBehavior: behavior,
      ),
    );
  }
}
