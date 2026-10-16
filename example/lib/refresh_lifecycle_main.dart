import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase/showcase_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('OVERLAY_QA_SEMANTICS')) {
    WidgetsBinding.instance.ensureSemantics();
  }
  runApp(const RefreshLifecycleApp());
}

/// Global style refresh and content-owned resources use one stable host.
class RefreshLifecycleApp extends StatefulWidget {
  const RefreshLifecycleApp({super.key});
  @override
  State<RefreshLifecycleApp> createState() => _RefreshLifecycleAppState();
}

class _RefreshLifecycleAppState extends State<RefreshLifecycleApp> {
  final _progress = ValueNotifier(0);
  late final SuperOverlayIntegration _integration = SuperOverlay.integration(
    notifyStyle: NotifyStyle(
      successBuilder:
          (message) => Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.green.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$message: ${_progress.value}%'),
            ),
          ),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ShowcaseTheme.light(),
    builder: _integration.builder,
    navigatorObservers: [_integration.observer],
    home: _RefreshPage(progress: _progress),
  );
  @override
  void dispose() {
    _integration.dispose();
    _progress.dispose();
    super.dispose();
  }
}

class _RefreshPage extends StatefulWidget {
  const _RefreshPage({required this.progress});
  final ValueNotifier<int> progress;
  @override
  State<_RefreshPage> createState() => _RefreshPageState();
}

class _RefreshPageState extends State<_RefreshPage> {
  OverlayHandle<void>? _notice;
  OverlayHandle<void>? _form;
  Timer? _timer;
  String _status = 'Ready';

  void _start({bool explicit = false}) {
    _timer?.cancel();
    widget.progress.value = 0;
    final handle = SuperOverlay.notify.success(
      'Global progress',
      builder:
          explicit
              ? (_) => const Material(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Explicit content overrides global style'),
                ),
              )
              : null,
      options: const OverlayNotifyOptions(
        tag: 'learning-progress',
        displayDuration: null,
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    _notice = handle;
    setState(() => _status = 'Running');
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      widget.progress.value += 10;
      handle.refresh();
      if (widget.progress.value >= 100) {
        timer.cancel();
        if (mounted) setState(() => _status = 'Complete');
      }
    });
    unawaited(
      handle.closed.then((_) {
        if (!mounted || !identical(_notice, handle)) return;
        _timer?.cancel();
        _notice = null;
        setState(() => _status = 'Stopped');
      }),
    );
  }

  void _showForm() {
    final owner = Navigator.of(context);
    final handle = SuperOverlay.of(context).dialog.show<void>(
      builder:
          (_, dialog) => RetainedBusinessForm(
            close: () => unawaited(dialog.close()),
            cover:
                () => unawaited(
                  owner.push(
                    MaterialPageRoute<void>(
                      builder:
                          (context) => Scaffold(
                            appBar: AppBar(title: const Text('Covered page')),
                            body: Center(
                              child: FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Return to form'),
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
          ),
      options: const OverlayDialogOptions(semanticsLabel: 'Retained form'),
    );
    _form = handle;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Refresh and resource lifecycle')),
    body: Center(
      child: SizedBox(
        width: 640,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'The selected global factory runs again on handle.refresh().',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _start(),
              child: const Text('Start global progress'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _start(explicit: true),
              child: const Text('Use explicit builder'),
            ),
            TextButton(
              onPressed: () {
                _timer?.cancel();
                unawaited(_notice?.close());
              },
              child: const Text('Stop notification'),
            ),
            const Divider(height: 32),
            const Text(
              'Suspension preserves the form. Its business timer and stream continue; disposal releases both.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _showForm,
              child: const Text('Open retained form'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_notice?.close());
    unawaited(_form?.close());
    super.dispose();
  }
}

class RetainedBusinessForm extends StatefulWidget {
  const RetainedBusinessForm({
    super.key,
    required this.close,
    required this.cover,
  });
  final VoidCallback close;
  final VoidCallback cover;
  @override
  State<RetainedBusinessForm> createState() => _RetainedBusinessFormState();
}

class _RetainedBusinessFormState extends State<RetainedBusinessForm> {
  late final Timer _timer;
  late final StreamSubscription<int> _stream;
  int _ticks = 0;
  int _events = 0;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() => _ticks++),
    );
    _stream = Stream<int>.periodic(
      const Duration(milliseconds: 250),
      (n) => n,
    ).listen((_) => setState(() => _events++));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Retained business form'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TextField(
          decoration: InputDecoration(labelText: 'Retained input'),
        ),
        Text('Timer $_ticks / Stream $_events'),
      ],
    ),
    actions: [
      TextButton(onPressed: widget.cover, child: const Text('Cover page')),
      FilledButton(onPressed: widget.close, child: const Text('Close form')),
    ],
  );
  @override
  void dispose() {
    _timer.cancel();
    unawaited(_stream.cancel());
    super.dispose();
  }
}
