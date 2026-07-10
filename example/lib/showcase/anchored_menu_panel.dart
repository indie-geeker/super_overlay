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
  String _sort = '最新发布';
  String _attachmentAction = '尚未选择';
  OverlayHandle<void>? _sortHandle;
  OverlayHandle<void>? _attachmentHandle;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('anchored-menu-panel'),
      title: '锚点菜单',
      subtitle: '下拉选择和上拉操作始终绑定具体触发控件',
      icon: Icons.vertical_align_center_outlined,
      accent: ShowcaseColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('排序方式', style: Theme.of(context).textTheme.labelLarge),
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
          Text('当前排序：$_sort'),
          const SizedBox(height: 18),
          Text('附件来源', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _constrainTrigger(
            Builder(
              builder:
                  (targetContext) => _AnchorField(
                    key: const ValueKey('attachment-menu-trigger'),
                    label: '添加附件',
                    icon: Icons.arrow_drop_up,
                    onTap: () => _showAttachmentMenu(targetContext),
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Text('最近操作：$_attachmentAction'),
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
                ('最新发布', Icons.schedule_outlined),
                ('价格从低到高', Icons.south_east_outlined),
                ('评分最高', Icons.star_outline),
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
                ('拍照', Icons.photo_camera_outlined),
                ('从相册选择', Icons.photo_library_outlined),
                ('选择文件', Icons.attach_file_outlined),
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
