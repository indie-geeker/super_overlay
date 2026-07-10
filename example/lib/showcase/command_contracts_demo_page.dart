import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

const _strategyTag = 'contracts-strategy';
const _ownedTag = 'contracts-owned';

class CommandContractsDemoPage extends StatefulWidget {
  const CommandContractsDemoPage({super.key});

  @override
  State<CommandContractsDemoPage> createState() =>
      _CommandContractsDemoPageState();
}

class _CommandContractsDemoPageState extends State<CommandContractsDemoPage> {
  OverlayHandle<void>? _ownedHandle;
  var _ownedRevision = 0;
  var _ownedExists = false;
  var _refreshToastRevision = 0;
  var _status = 'Choose a contract action.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Command Contracts')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CodeStrip(
              code:
                  'final handle = SuperOverlay.dialog.show<void>(...);\n'
                  'await handle.visible; await handle.close();',
            ),
            const SizedBox(height: 16),
            FeaturePanel(
              title: 'Tagged strategies',
              subtitle: 'stack, keepExisting, replaceExisting',
              icon: Icons.layers_outlined,
              accent: ShowcaseColors.info,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () => unawaited(_showStackStrategy()),
                    child: const Text('Stack tagged dialogs'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(_showKeepStrategy()),
                    child: const Text('Keep existing dialog'),
                  ),
                  FilledButton(
                    onPressed: () => unawaited(_showReplaceStrategy()),
                    child: const Text('Replace tagged dialog'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeaturePanel(
              title: 'Handle + exists',
              subtitle: 'visible, refresh, close, and tagged lookup',
              icon: Icons.control_point_duplicate_outlined,
              accent: ShowcaseColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('exists($_ownedTag): $_ownedExists'),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => unawaited(_showOwnedHandle()),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Show owned handle'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeaturePanel(
              title: 'Refresh active toast',
              subtitle:
                  'Update one active toast instead of stacking a duplicate',
              icon: Icons.refresh_outlined,
              accent: ShowcaseColors.warning,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: _startRefreshToast,
                    child: const Text('Start refresh toast'),
                  ),
                  FilledButton(
                    onPressed: _updateRefreshToast,
                    child: const Text('Update refresh toast'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FeaturePanel(
              title: 'Notifications + cleanup',
              subtitle:
                  'All notification styles and one global teardown command',
              icon: Icons.notifications_active_outlined,
              accent: ShowcaseColors.danger,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: _showAllNotifications,
                    child: const Text('Show all notification types'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(_cleanupAll()),
                    child: const Text('Cleanup all overlays'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _status,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: ShowcaseColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStackStrategy() async {
    await _closeStrategyDialogs();
    _showStrategyDialog('Stacked dialog A', OverlayStrategy.stack);
    _showStrategyDialog('Stacked dialog B', OverlayStrategy.stack);
    _setStatus('Stack keeps both matching tagged dialogs.');
  }

  Future<void> _showKeepStrategy() async {
    await _closeStrategyDialogs();
    _showStrategyDialog('Kept original dialog', OverlayStrategy.stack);
    _showStrategyDialog(
      'Ignored duplicate dialog',
      OverlayStrategy.keepExisting,
    );
    _setStatus('keepExisting preserves the original tagged dialog.');
  }

  Future<void> _showReplaceStrategy() async {
    await _closeStrategyDialogs();
    _showStrategyDialog('Replacement loser', OverlayStrategy.replaceExisting);
    _showStrategyDialog('Replacement winner', OverlayStrategy.replaceExisting);
    _setStatus('replaceExisting serialized the latest tagged dialog.');
  }

  void _showStrategyDialog(String label, OverlayStrategy strategy) {
    SuperOverlay.dialog.show<void>(
      builder:
          (_) => OverlayCard(
            width: 300,
            child: Text(label, textAlign: TextAlign.center),
          ),
      options: OverlayDialogOptions(tag: _strategyTag, strategy: strategy),
    );
  }

  Future<void> _closeStrategyDialogs() {
    return SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: _strategyTag,
      force: true,
    );
  }

  Future<void> _showOwnedHandle() async {
    await _ownedHandle?.close();
    _ownedRevision = 0;
    late final OverlayHandle<void> handle;
    handle = SuperOverlay.dialog.show<void>(
      builder:
          (_) => OverlayCard(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Owned handle revision $_ownedRevision'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: _refreshOwnedHandle,
                      child: const Text('Refresh owned handle'),
                    ),
                    FilledButton(
                      onPressed: () => unawaited(_closeOwnedHandle()),
                      child: const Text('Close owned handle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      options: const OverlayDialogOptions(tag: _ownedTag),
    );
    _ownedHandle = handle;
    _setOwnedState(exists: SuperOverlay.exists(tag: _ownedTag));

    unawaited(
      handle.visible.then<void>(
        (_) => _setStatus('Owned handle reached its rendered frame.'),
        onError: (Object error, StackTrace _) {
          _setStatus('Owned handle was not shown: $error');
        },
      ),
    );
    unawaited(
      handle.closed.then<void>((_) {
        if (identical(_ownedHandle, handle)) {
          _ownedHandle = null;
          _setOwnedState(exists: SuperOverlay.exists(tag: _ownedTag));
        }
      }),
    );
  }

  void _refreshOwnedHandle() {
    _ownedRevision += 1;
    _ownedHandle?.refresh();
    _setStatus('Owned handle refresh requested.');
  }

  Future<void> _closeOwnedHandle() async {
    await _ownedHandle?.close();
    _ownedHandle = null;
    _setOwnedState(exists: SuperOverlay.exists(tag: _ownedTag));
    _setStatus('Owned handle closed.');
  }

  void _startRefreshToast() {
    _refreshToastRevision = 1;
    _showRefreshToast();
    _setStatus('Started one refreshActive toast.');
  }

  void _updateRefreshToast() {
    _refreshToastRevision =
        _refreshToastRevision == 0 ? 1 : _refreshToastRevision + 1;
    _showRefreshToast();
    _setStatus('Updated the active toast in place.');
  }

  void _showRefreshToast() {
    final message = 'Refresh active toast #$_refreshToastRevision';
    SuperOverlay.toast(
      message,
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.refreshActive,
        displayDuration: Duration(minutes: 1),
      ),
    );
  }

  void _showAllNotifications() {
    const options = OverlayNotifyOptions(displayDuration: null);
    SuperOverlay.notify.success('Success notification', options: options);
    SuperOverlay.notify.failure('Failure notification', options: options);
    SuperOverlay.notify.warning('Warning notification', options: options);
    SuperOverlay.notify.error('Error notification', options: options);
    SuperOverlay.notify.alert('Alert notification', options: options);
    _setStatus('All five notification variants are active.');
  }

  Future<void> _cleanupAll() async {
    await SuperOverlay.close(target: OverlayCloseTarget.all, force: true);
    _ownedHandle = null;
    _refreshToastRevision = 0;
    _setOwnedState(exists: false);
    _setStatus('All overlays closed');
  }

  void _setOwnedState({required bool exists}) {
    if (!mounted) {
      return;
    }
    setState(() => _ownedExists = exists);
  }

  void _setStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() => _status = status);
  }

  @override
  void dispose() {
    unawaited(SuperOverlay.close(target: OverlayCloseTarget.all, force: true));
    super.dispose();
  }
}
