import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

class DialogDemoPanel extends StatefulWidget {
  const DialogDemoPanel({super.key});

  @override
  State<DialogDemoPanel> createState() => _DialogDemoPanelState();
}

class _DialogDemoPanelState extends State<DialogDemoPanel> {
  OverlayHandle<void>? _handle;
  bool _dismissible = true;
  bool _dimmed = true;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('dialog-demo-panel'),
      title: '自定义弹窗',
      subtitle: '对话框的外部关闭、遮罩和内容完全由业务决定',
      icon: Icons.dashboard_customize_outlined,
      accent: ShowcaseColors.primary,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('点击弹窗外部允许关闭'),
            value: _dismissible,
            onChanged: (value) => setState(() => _dismissible = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示背景遮罩'),
            value: _dimmed,
            onChanged: (value) => setState(() => _dimmed = value),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _showDialog,
              icon: const Icon(Icons.open_in_full),
              label: const Text('打开自定义弹窗'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDialog() {
    final maskColor = _dimmed ? ShowcaseColors.scrim : Colors.transparent;
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => DialogSurface(dismissible: _dismissible, dimmed: _dimmed),
      options: OverlayDialogOptions(
        tag: 'dialog-lab',
        strategy: OverlayStrategy.replaceExisting,
        barrierColor: maskColor,
        dismissOnMaskTap: _dismissible,
      ),
    );
    _handle = handle;
    unawaited(
      handle.closed.whenComplete(() {
        if (identical(_handle, handle)) {
          _handle = null;
        }
      }),
    );
  }

  @override
  void dispose() {
    final handle = _handle;
    _handle = null;
    unawaited(handle?.close());
    super.dispose();
  }
}
