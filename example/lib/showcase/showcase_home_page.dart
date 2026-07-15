import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import '../network_state/presentation/network_state_demo_page.dart';
import 'anchored_menu_panel.dart';
import 'dialog_demo_panel.dart';
import 'guided_mask_panel.dart';
import 'instant_feedback_panel.dart';
import 'lifecycle_demo_page.dart';
import 'nested_navigation_demo_page.dart';
import 'overlay_control_lab_page.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

class ShowcaseHomePage extends StatelessWidget {
  const ShowcaseHomePage({super.key, required this.integration});

  final SuperOverlayIntegration integration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SuperOverlay Showcase')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ShowcaseHeader(),
              const SizedBox(height: 24),
              const ShowcaseSectionTitle(
                title: 'Common Scenarios',
                subtitle:
                    'Start with feedback, anchored menus, dialogs, and network state',
              ),
              const SizedBox(height: 12),
              const _ResponsivePair(
                first: InstantFeedbackPanel(),
                second: AnchoredMenuPanel(),
              ),
              const SizedBox(height: 16),
              _ResponsivePair(
                first: const DialogDemoPanel(),
                second: _buildNetworkStatePanel(context),
              ),
              const SizedBox(height: 28),
              const ShowcaseSectionTitle(
                title: 'Interaction Guidance',
                subtitle:
                    'Use a highlight mask to guide users through required steps',
              ),
              const SizedBox(height: 12),
              const GuidedMaskPanel(),
              const SizedBox(height: 28),
              const ShowcaseSectionTitle(
                title: 'Advanced Capabilities',
                subtitle:
                    'Explore route lifecycles, tag strategies, and Handle control',
              ),
              const SizedBox(height: 12),
              _ResponsivePair(
                first: _buildLifecyclePanel(context),
                second: _buildControlLabPanel(context),
              ),
              const SizedBox(height: 16),
              _buildNestedNavigationPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkStatePanel(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('network-state-panel'),
      title: 'Network Request State',
      subtitle: 'Request loading, empty, error, and per-image states',
      icon: Icons.cloud_sync_outlined,
      accent: ShowcaseColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Empty and error content stays in the page; Overlay handles loading and Toast feedback.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(context, const NetworkStateDemoPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Network State Demo'),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecyclePanel(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('lifecycle-panel'),
      title: 'Lifecycle Binding',
      subtitle: 'Route binding, widget binding, and back handling',
      icon: Icons.route_outlined,
      accent: ShowcaseColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observe how Overlays react to covering routes, unmounted targets, and back policies.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(context, const LifecycleDemoPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Lifecycle Demo'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlLabPanel(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('control-lab-panel'),
      title: 'Overlay Control Lab',
      subtitle:
          'Understand strategies, Handles, and lifecycles through scenarios',
      icon: Icons.integration_instructions_outlined,
      accent: ShowcaseColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compare duplicate strategies, then refresh, close, and await an Overlay.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(context, const OverlayControlLabPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Control Lab'),
          ),
        ],
      ),
    );
  }

  Widget _buildNestedNavigationPanel(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('nested-navigation-panel'),
      title: 'Nested Navigator',
      subtitle:
          'One root SuperOverlayIntegration tracks nested routes through '
          'navigatorObserver()',
      icon: Icons.account_tree_outlined,
      accent: ShowcaseColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observe scoped dialogs suspend, resume, and close with their owner routes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                () => _pushPage(
                  context,
                  NestedNavigationDemoPage(integration: integration),
                ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Nested Navigator Demo'),
          ),
        ],
      ),
    );
  }

  void _pushPage(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 16), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
