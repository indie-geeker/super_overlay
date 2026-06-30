import 'package:flutter/material.dart';

import 'showcase_theme.dart';

class ShowcaseHeader extends StatelessWidget {
  const ShowcaseHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ShowcaseColors.surface,
        border: Border.all(color: ShowcaseColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PackageBadge(text: 'Flutter package'),
              PackageBadge(text: 'OverlayEntry'),
              PackageBadge(text: 'MIT'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.layers_outlined,
                size: 36,
                color: ShowcaseColors.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'super_overlay',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Self-managed dialogs, toasts, popups, highlighted guides, '
                      'route-aware lifecycle demos, and request feedback.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: ShowcaseColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const CodeStrip(
            code:
                'MaterialApp(builder: SuperOverlayInit.init(), '
                'navigatorObservers: [SuperOverlayInit.observer])',
          ),
        ],
      ),
    );
  }
}

class CapabilityStats extends StatelessWidget {
  const CapabilityStats({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        StatPill(label: 'Overlay modes', value: '6'),
        StatPill(label: 'Route aware', value: 'Yes'),
        StatPill(label: 'Back policy', value: '3'),
        StatPill(label: 'Live log', value: 'On'),
      ],
    );
  }
}

class FeaturePanel extends StatelessWidget {
  const FeaturePanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(icon, color: accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ShowcaseColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class PackageBadge extends StatelessWidget {
  const PackageBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcaseColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShowcaseColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ShowcaseColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 144),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ShowcaseColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShowcaseColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: ShowcaseColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ShowcaseColors.muted),
          ),
        ],
      ),
    );
  }
}

class CodeStrip extends StatelessWidget {
  const CodeStrip({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ShowcaseColors.codeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShowcaseColors.border),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: ShowcaseColors.text,
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }
}

class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: ShowcaseColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: ShowcaseColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
