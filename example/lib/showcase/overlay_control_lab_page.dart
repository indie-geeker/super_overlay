import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'advanced_popup_panel.dart';
import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

const _strategyTag = 'control-lab-auth';
const _uploadTag = 'control-lab-upload';
const _awaitTag = 'control-lab-await';

enum _DuplicateStrategy { stack, keepExisting, replaceExisting }

class OverlayControlLabPage extends StatefulWidget {
  const OverlayControlLabPage({super.key});

  @override
  State<OverlayControlLabPage> createState() => _OverlayControlLabPageState();
}

class _OverlayControlLabPageState extends State<OverlayControlLabPage> {
  final _strategyHandles = <OverlayHandle<void>>[];
  final _awaitEvents = <String>[];

  _DuplicateStrategy _strategy = _DuplicateStrategy.stack;
  OverlayHandle<void>? _uploadHandle;
  OverlayHandle<void>? _awaitHandle;
  var _uploadProgress = 0;
  var _strategyResult =
      'Choose a strategy, then trigger the same business tag twice.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay Control Lab')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CodeStrip(
                code:
                    'final handle = SuperOverlay.toast(...);\n'
                    'await handle.visible; handle.refresh(); await handle.close();',
              ),
              const SizedBox(height: 16),
              _buildStrategyPanel(),
              const SizedBox(height: 16),
              _buildHandlePanel(),
              const SizedBox(height: 16),
              _buildAwaitPanel(),
              const SizedBox(height: 16),
              const AdvancedPopupPanel(key: ValueKey('advanced-popup-panel')),
              const SizedBox(height: 16),
              _buildCleanupPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyPanel() {
    return FeaturePanel(
      title: 'How should repeated triggers behave?',
      subtitle:
          'When login errors arrive back-to-back, the tag strategy decides which remain',
      icon: Icons.layers_outlined,
      accent: ShowcaseColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_DuplicateStrategy>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _DuplicateStrategy.stack,
                label: Text('Stack'),
              ),
              ButtonSegment(
                value: _DuplicateStrategy.keepExisting,
                label: Text('Keep Existing'),
              ),
              ButtonSegment(
                value: _DuplicateStrategy.replaceExisting,
                label: Text('Replace Existing'),
              ),
            ],
            selected: {_strategy},
            onSelectionChanged: (selection) {
              setState(() => _strategy = selection.first);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => unawaited(_runStrategyScenario()),
            icon: const Icon(Icons.replay_outlined),
            label: const Text('Simulate Two Triggers'),
          ),
          const SizedBox(height: 10),
          DemoStatusBanner(message: _strategyResult),
        ],
      ),
    );
  }

  Widget _buildHandlePanel() {
    return FeaturePanel(
      title: 'How do you control a visible Overlay?',
      subtitle:
          'Upload progress refreshes only its own Handle without affecting other Toasts',
      icon: Icons.upload_outlined,
      accent: ShowcaseColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: () => unawaited(_startUpload()),
                child: const Text('Start Upload'),
              ),
              OutlinedButton(
                onPressed: _uploadHandle == null ? null : _advanceUpload,
                child: const Text('Advance Progress'),
              ),
              OutlinedButton(
                onPressed:
                    _uploadHandle == null
                        ? null
                        : () => unawaited(_cancelUpload()),
                child: const Text('Cancel Upload'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _uploadHandle == null
                ? 'No active upload'
                : 'Progress: $_uploadProgress% · exists(${SuperOverlay.exists(tag: _uploadTag)})',
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitPanel() {
    return FeaturePanel(
      title: 'Await Lifecycle',
      subtitle:
          'visible and closed let subsequent code await real lifecycle milestones',
      icon: Icons.av_timer_outlined,
      accent: ShowcaseColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed:
                _awaitHandle == null
                    ? () => unawaited(_startAwaitDemo())
                    : null,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Start Await Demo'),
          ),
          const SizedBox(height: 10),
          if (_awaitEvents.isEmpty)
            const Text('Timeline events appear here.')
          else
            for (final event in _awaitEvents)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(event),
              ),
        ],
      ),
    );
  }

  Widget _buildCleanupPanel() {
    return FeaturePanel(
      title: 'Cleanup Boundary',
      subtitle: 'By default, close only Overlays owned by this page',
      icon: Icons.cleaning_services_outlined,
      accent: ShowcaseColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonal(
            onPressed: () => unawaited(_closeOwnedOverlays()),
            child: const Text('Clean Up Page Overlays'),
          ),
          const SizedBox(height: 12),
          Text(
            'Danger: global cleanup closes Overlays created by other product modules.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ShowcaseColors.danger),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => unawaited(_confirmGlobalCleanup()),
            child: const Text('Close All Overlays'),
          ),
        ],
      ),
    );
  }

  Future<void> _runStrategyScenario() async {
    await _closeStrategyDialogs();
    if (!mounted) {
      return;
    }

    switch (_strategy) {
      case _DuplicateStrategy.stack:
        _showStrategyDialog('Login Prompt #1', OverlayStrategy.stack);
        _showStrategyDialog('Login Prompt #2', OverlayStrategy.stack);
        _setStrategyResult(
          'Result: both prompts remain for independent events.',
        );
      case _DuplicateStrategy.keepExisting:
        _showStrategyDialog('Login Prompt #1', OverlayStrategy.stack);
        _showStrategyDialog('Login Prompt #2', OverlayStrategy.keepExisting);
        _setStrategyResult(
          'Result: the duplicate is ignored and the first prompt remains.',
        );
      case _DuplicateStrategy.replaceExisting:
        _showStrategyDialog('Login Prompt #1', OverlayStrategy.replaceExisting);
        _showStrategyDialog('Login Prompt #2', OverlayStrategy.replaceExisting);
        _setStrategyResult(
          'Result: the second trigger replaces the first prompt.',
        );
    }
  }

  void _showStrategyDialog(String label, OverlayStrategy strategy) {
    late final OverlayHandle<void> handle;
    handle = SuperOverlay.dialog.show<void>(
      builder:
          (_) => OverlayCard(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The next trigger with this tag follows the selected strategy.',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => unawaited(handle.close()),
                    child: const Text('Close This Prompt'),
                  ),
                ),
              ],
            ),
          ),
      options: OverlayDialogOptions(tag: _strategyTag, strategy: strategy),
    );
    _strategyHandles.add(handle);
  }

  Future<void> _startUpload() async {
    await _uploadHandle?.close();
    if (!mounted) {
      return;
    }
    _uploadProgress = 0;
    late final OverlayHandle<void> handle;
    handle = SuperOverlay.toast(
      'upload',
      builder:
          (_) => ToastSurface(
            icon: Icons.cloud_upload_outlined,
            text: 'Upload progress $_uploadProgress%',
            accent: ShowcaseColors.primary,
          ),
      options: const OverlayToastOptions(
        tag: _uploadTag,
        strategy: OverlayStrategy.replaceExisting,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    _uploadHandle = handle;
    setState(() {});
    unawaited(
      handle.closed.whenComplete(() {
        if (mounted && identical(_uploadHandle, handle)) {
          setState(() => _uploadHandle = null);
        }
      }),
    );
  }

  void _advanceUpload() {
    final handle = _uploadHandle;
    if (handle == null) {
      return;
    }
    setState(() => _uploadProgress = (_uploadProgress + 35).clamp(0, 100));
    handle.refresh();
  }

  Future<void> _cancelUpload() async {
    final handle = _uploadHandle;
    _uploadHandle = null;
    await handle?.close();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startAwaitDemo() async {
    _awaitEvents
      ..clear()
      ..add('1. Handle created');
    late final OverlayHandle<void> handle;
    handle = SuperOverlay.dialog.show<void>(
      builder:
          (_) => OverlayCard(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Await Overlay',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The page continues past closed only after this Overlay closes.',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => unawaited(_closeAwaitOverlay()),
                    child: const Text('Close Await Overlay'),
                  ),
                ),
              ],
            ),
          ),
      options: const OverlayDialogOptions(tag: _awaitTag),
    );
    _awaitHandle = handle;
    setState(() {});

    try {
      await handle.visible;
      if (mounted && identical(_awaitHandle, handle)) {
        setState(() => _awaitEvents.add('2. First frame visible'));
      }
    } on StateError {
      // A quick page exit may close the handle before its first rendered frame.
    }
  }

  Future<void> _closeAwaitOverlay() async {
    final handle = _awaitHandle;
    if (handle == null) {
      return;
    }
    if (mounted) {
      setState(() => _awaitEvents.add('3. Overlay close requested'));
    }
    await handle.close();
    if (!mounted || !identical(_awaitHandle, handle)) {
      return;
    }
    await handle.closed;
    setState(() {
      _awaitEvents.add('4. Overlay closed; closed Future completed');
      _awaitHandle = null;
    });
  }

  Future<void> _closeStrategyDialogs() async {
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: _strategyTag,
      force: true,
    );
    _strategyHandles.clear();
  }

  Future<void> _closeOwnedOverlays() async {
    final upload = _uploadHandle;
    final awaitHandle = _awaitHandle;
    _uploadHandle = null;
    _awaitHandle = null;
    await upload?.close();
    await awaitHandle?.close();
    await _closeStrategyDialogs();
    for (final tag in advancedPopupTags) {
      await SuperOverlay.close(
        target: OverlayCloseTarget.allPopups,
        tag: tag,
        force: true,
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmGlobalCleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Close all Overlays?'),
            content: const Text(
              'This also closes Overlays owned by other product modules.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm Global Cleanup'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await SuperOverlay.close(target: OverlayCloseTarget.all, force: true);
      _uploadHandle = null;
      _awaitHandle = null;
      _strategyHandles.clear();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _setStrategyResult(String result) {
    if (mounted) {
      setState(() => _strategyResult = result);
    }
  }

  @override
  void dispose() {
    unawaited(_closeOwnedOverlays());
    super.dispose();
  }
}
