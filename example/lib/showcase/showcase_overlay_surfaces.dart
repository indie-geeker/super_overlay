import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_theme.dart';

class DialogSurface extends StatelessWidget {
  const DialogSurface({
    super.key,
    required this.dismissible,
    required this.dimmed,
    required this.onResult,
  });

  final bool dismissible;
  final bool dimmed;
  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) {
    return OverlayCard(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirm this action?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Outside tap: ${dismissible ? 'dismisses' : 'ignored'}'),
          Text('Background barrier: ${dimmed ? 'shown' : 'hidden'}'),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => onResult(false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => onResult(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ToastSurface extends StatelessWidget {
  const ToastSurface({
    super.key,
    required this.icon,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcaseColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
            color: ShowcaseColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(color: ShowcaseColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChoicePopup extends StatelessWidget {
  const ChoicePopup({
    super.key,
    required this.selected,
    required this.multi,
    required this.onSelected,
    required this.onToggle,
    required this.onApply,
  });

  final int selected;
  final Set<int> multi;
  final ValueChanged<int> onSelected;
  final void Function(int value, bool enabled) onToggle;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return OverlayCard(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Filters',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text('Single Choice', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Option 1')),
              ButtonSegment<int>(value: 1, label: Text('Option 2')),
              ButtonSegment<int>(value: 2, label: Text('Option 3')),
            ],
            selected: {selected},
            onSelectionChanged: (values) => onSelected(values.first),
          ),
          const SizedBox(height: 10),
          Text(
            'Multiple Capabilities',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          for (var index = 0; index < 3; index++)
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Capability ${index + 1}'),
                value: multi.contains(index),
                onChanged: (value) => onToggle(index, value ?? false),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onApply,
              child: const Text('Apply Selection'),
            ),
          ),
        ],
      ),
    );
  }
}

class GuideTarget extends StatelessWidget {
  const GuideTarget({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor:
            active
                ? ShowcaseColors.danger.withValues(alpha: 0.18)
                : ShowcaseColors.info.withValues(alpha: 0.14),
        foregroundColor: active ? ShowcaseColors.danger : ShowcaseColors.info,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class GuideBubble extends StatelessWidget {
  const GuideBubble({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final title = 'Step ${step + 1}';
    final body = switch (step) {
      0 => 'Tap Highlight Entry. The outside mask will not dismiss the guide.',
      1 => 'Continue with Configure Options to move focus to the next target.',
      _ => 'Finish by tapping Status Panel.',
    };
    return OverlayCard(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}

class PopupDemoSurface extends StatelessWidget {
  const PopupDemoSurface({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OverlayCard(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: ShowcaseColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                SuperOverlay.close(target: OverlayCloseTarget.popup);
              },
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class SmallOverlay extends StatelessWidget {
  const SmallOverlay({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return OverlayCard(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  () => SuperOverlay.close(target: OverlayCloseTarget.dialog),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class OverlayCard extends StatelessWidget {
  const OverlayCard({super.key, required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ShowcaseColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShowcaseColors.border),
        boxShadow: const [
          BoxShadow(
            color: ShowcaseColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}
