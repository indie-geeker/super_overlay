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
  OverlayHandle<bool>? _handle;
  bool _dismissible = true;
  bool _dimmed = true;
  String _resultStatus = 'Waiting for a confirmation result.';

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('dialog-demo-panel'),
      title: 'Custom Dialog',
      subtitle:
          'The product controls outside dismissal, the barrier, and the content',
      icon: Icons.dashboard_customize_outlined,
      accent: ShowcaseColors.primary,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tap outside to dismiss'),
            value: _dismissible,
            onChanged: (value) => setState(() => _dismissible = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show background barrier'),
            value: _dimmed,
            onChanged: (value) => setState(() => _dimmed = value),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _showDialog,
              icon: const Icon(Icons.open_in_full),
              label: const Text('Open Confirmation Dialog'),
            ),
          ),
          const SizedBox(height: 12),
          DemoStatusBanner(message: _resultStatus),
        ],
      ),
    );
  }

  void _showDialog() {
    final maskColor = _dimmed ? ShowcaseColors.scrim : Colors.transparent;
    late final OverlayHandle<bool> handle;
    handle = SuperOverlay.dialog.show<bool>(
      builder:
          (_) => DialogSurface(
            dismissible: _dismissible,
            dimmed: _dimmed,
            onResult: (result) => unawaited(handle.close(result)),
          ),
      options: OverlayDialogOptions(
        tag: 'dialog-lab',
        strategy: OverlayStrategy.replaceExisting,
        barrierColor: maskColor,
        dismissOnMaskTap: _dismissible,
        semanticsLabel: 'Confirmation dialog',
        barrierSemanticsLabel:
            _dismissible
                ? 'Dismiss confirmation dialog'
                : 'Confirmation dialog background',
      ),
    );
    _handle = handle;
    unawaited(() async {
      final result = await handle.closed;
      if (mounted && identical(_handle, handle)) {
        setState(() {
          _handle = null;
          _resultStatus = 'handle.closed result: $result';
        });
      }
    }());
  }

  @override
  void dispose() {
    final handle = _handle;
    _handle = null;
    unawaited(handle?.close());
    super.dispose();
  }
}
