import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase/showcase_theme.dart';

void main() => runApp(const MinimalOverlayApp());

class MinimalOverlayApp extends StatefulWidget {
  const MinimalOverlayApp({super.key, this.runTask});

  final Future<void> Function()? runTask;

  @override
  State<MinimalOverlayApp> createState() => _MinimalOverlayAppState();
}

class _MinimalOverlayAppState extends State<MinimalOverlayApp> {
  late final SuperOverlayIntegration _integration = SuperOverlay.integration();

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ShowcaseTheme.light(),
    builder: _integration.builder,
    navigatorObservers: [_integration.observer],
    home: _TaskPage(runTask: widget.runTask ?? _demoTask),
  );

  static Future<void> _demoTask() =>
      Future<void>.delayed(const Duration(milliseconds: 600));

  @override
  void dispose() {
    _integration.dispose();
    super.dispose();
  }
}

class _TaskPage extends StatefulWidget {
  const _TaskPage({required this.runTask});

  final Future<void> Function() runTask;

  @override
  State<_TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<_TaskPage> {
  bool _busy = false;
  String _status = 'Ready';

  Future<void> _confirmAndRun() async {
    setState(() => _busy = true);
    try {
      final confirmed =
          await SuperOverlay.of(context).dialog
              .show<bool>(
                builder:
                    (_, dialog) => AlertDialog(
                      title: const Text('Run task?'),
                      content: const Text(
                        'A loading overlay closes even if the task fails.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => unawaited(dialog.close(false)),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => unawaited(dialog.close(true)),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                options: const OverlayDialogOptions(
                  semanticsLabel: 'Run task confirmation',
                ),
              )
              .closed;
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => _status = 'Cancelled');
        return;
      }

      await SuperOverlay.loading.run(
        widget.runTask,
        options: const OverlayLoadingOptions(semanticsLabel: 'Running task'),
      );
      if (mounted) setState(() => _status = 'Completed');
    } catch (_) {
      if (mounted) setState(() => _status = 'Task failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SuperOverlay minimal example')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_status),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_confirmAndRun()),
            child: const Text('Confirm and run'),
          ),
        ],
      ),
    ),
  );
}
