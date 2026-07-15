import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

class AnchoredMenuPanel extends StatefulWidget {
  const AnchoredMenuPanel({super.key});

  @override
  State<AnchoredMenuPanel> createState() => _AnchoredMenuPanelState();
}

class _AnchoredMenuPanelState extends State<AnchoredMenuPanel> {
  String _sort = 'Newest';
  String _attachmentAction = 'No action selected';
  OverlayHandle<void>? _sortHandle;
  OverlayHandle<void>? _attachmentHandle;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('anchored-menu-panel'),
      title: 'Anchored Menus',
      subtitle: 'Dropdown and upward menus stay attached to their trigger',
      icon: Icons.vertical_align_center_outlined,
      accent: ShowcaseColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sort By', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _constrainTrigger(
            Builder(
              builder:
                  (targetContext) => _AnchorField(
                    key: const ValueKey('sort-menu-trigger'),
                    label: _sort,
                    icon: Icons.arrow_drop_down,
                    onTap: () => _showSortMenu(targetContext),
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Current sort: $_sort'),
          const SizedBox(height: 18),
          Text(
            'Attachment Source',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          const TextField(
            key: ValueKey('attachment-message-field'),
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'Enter a message before choosing an attachment source',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          _constrainTrigger(
            Builder(
              builder:
                  (targetContext) => _AnchorField(
                    key: const ValueKey('attachment-menu-trigger'),
                    label: 'Add Attachment',
                    icon: Icons.arrow_drop_up,
                    onTap: () => _showAttachmentMenu(targetContext),
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Focus the field first to verify upward placement while the keyboard is open.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ShowcaseColors.muted),
          ),
          const SizedBox(height: 8),
          Text('Last action: $_attachmentAction'),
        ],
      ),
    );
  }

  Widget _constrainTrigger(Widget child) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  void _showSortMenu(BuildContext targetContext) {
    late final OverlayHandle<void> handle;
    handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const SizedBox.shrink(),
      options: OverlayPopupOptions(
        tag: 'showcase-sort-menu',
        strategy: OverlayStrategy.replaceExisting,
        alignment: Alignment.bottomCenter,
        replacementBuilder:
            (info) => _AnchoredMenuSurface(
              key: const ValueKey('sort-menu-popup'),
              width: info.targetSize.width,
              items: const [
                ('Newest', Icons.schedule_outlined),
                ('Price: Low to High', Icons.south_east_outlined),
                ('Top Rated', Icons.star_outline),
              ],
              selected: _sort,
              onSelected: (value) {
                if (mounted) {
                  setState(() => _sort = value);
                }
                unawaited(handle.close());
              },
            ),
      ),
    );
    _sortHandle = handle;
    unawaited(
      handle.closed.whenComplete(() {
        if (identical(_sortHandle, handle)) {
          _sortHandle = null;
        }
      }),
    );
  }

  void _showAttachmentMenu(BuildContext targetContext) {
    late final OverlayHandle<void> handle;
    handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const SizedBox.shrink(),
      options: OverlayPopupOptions(
        tag: 'showcase-attachment-menu',
        strategy: OverlayStrategy.replaceExisting,
        alignment: Alignment.topCenter,
        replacementBuilder:
            (info) => _AnchoredMenuSurface(
              key: const ValueKey('attachment-menu-popup'),
              width: info.targetSize.width,
              items: const [
                ('Camera', Icons.photo_camera_outlined),
                ('Photo Library', Icons.photo_library_outlined),
                ('Choose File', Icons.attach_file_outlined),
              ],
              onSelected: (value) {
                if (mounted) {
                  setState(() => _attachmentAction = value);
                }
                unawaited(handle.close());
              },
            ),
      ),
    );
    _attachmentHandle = handle;
    unawaited(
      handle.closed.whenComplete(() {
        if (identical(_attachmentHandle, handle)) {
          _attachmentHandle = null;
        }
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_sortHandle?.close());
    unawaited(_attachmentHandle?.close());
    _sortHandle = null;
    _attachmentHandle = null;
    super.dispose();
  }
}

class _AnchorField extends StatelessWidget {
  const _AnchorField({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ShowcaseColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ShowcaseColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Icon(icon, color: ShowcaseColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnchoredMenuSurface extends StatelessWidget {
  const _AnchoredMenuSurface({
    super.key,
    required this.width,
    required this.items,
    required this.onSelected,
    this.selected,
  });

  final double width;
  final List<(String, IconData)> items;
  final ValueChanged<String> onSelected;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return OverlayCard(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelected(item.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(item.$2, size: 20, color: ShowcaseColors.info),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.$1)),
                    if (selected == item.$1)
                      const Icon(
                        Icons.check,
                        size: 18,
                        color: ShowcaseColors.primary,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
