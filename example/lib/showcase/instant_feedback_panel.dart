import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

enum ToastDemoPolicy { replaceLatest, queue, stack }

const _feedbackToastTag = 'showcase-feedback-toast';
const _feedbackNotifyTag = 'showcase-feedback-notify';

class InstantFeedbackPanel extends StatefulWidget {
  const InstantFeedbackPanel({super.key});

  @override
  State<InstantFeedbackPanel> createState() => _InstantFeedbackPanelState();
}

class _InstantFeedbackPanelState extends State<InstantFeedbackPanel> {
  ToastDemoPolicy _policy = ToastDemoPolicy.replaceLatest;
  OverlayNotificationType _notificationType = OverlayNotificationType.success;
  OverlayHandle<void>? _notificationHandle;
  String _status = 'Choose a policy, then run its feedback scenario.';

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('instant-feedback-panel'),
      title: 'Instant Feedback',
      subtitle:
          'Toast and Notify feedback for saves, uploads, and system events',
      icon: Icons.notifications_active_outlined,
      accent: ShowcaseColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toast Display Policy',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<ToastDemoPolicy>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ToastDemoPolicy.replaceLatest,
                label: Text('Replace Latest'),
              ),
              ButtonSegment(value: ToastDemoPolicy.queue, label: Text('Queue')),
              ButtonSegment(value: ToastDemoPolicy.stack, label: Text('Stack')),
            ],
            selected: {_policy},
            onSelectionChanged: (values) {
              setState(() => _policy = values.first);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => unawaited(_runToastDemo()),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Run Toast Demo'),
          ),
          const SizedBox(height: 12),
          DemoStatusBanner(message: _status),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Top Notification',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final selector = DropdownButtonFormField<OverlayNotificationType>(
                key: const ValueKey('feedback-notification-selector'),
                // `initialValue` is unavailable on the minimum Flutter 3.29.
                // ignore: deprecated_member_use
                value: _notificationType,
                decoration: const InputDecoration(
                  labelText: 'Notification Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final type in OverlayNotificationType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_notificationLabel(type)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _notificationType = value);
                  }
                },
              );
              final action = FilledButton.icon(
                onPressed: _showNotification,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Show Notification'),
              );
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [selector, const SizedBox(height: 10), action],
                );
              }
              return Row(
                children: [
                  Expanded(child: selector),
                  const SizedBox(width: 10),
                  action,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runToastDemo() async {
    await SuperOverlay.close(
      target: OverlayCloseTarget.allToasts,
      tag: _feedbackToastTag,
      force: true,
    );
    if (!mounted) {
      return;
    }

    switch (_policy) {
      case ToastDemoPolicy.replaceLatest:
        for (var index = 1; index <= 3; index++) {
          _showToast(
            message: 'Save result $index',
            icon: Icons.save_outlined,
            accent: ShowcaseColors.primary,
            policy: OverlayToastDisplayPolicy.replaceLatest,
          );
        }
        _setStatus(
          'Only the latest of three consecutive save results remains.',
        );
      case ToastDemoPolicy.queue:
        for (var index = 1; index <= 3; index++) {
          _showToast(
            message: 'File $index uploaded',
            icon: Icons.cloud_upload_outlined,
            accent: ShowcaseColors.warning,
            policy: OverlayToastDisplayPolicy.queue,
            duration: const Duration(milliseconds: 900),
          );
        }
        _setStatus('Three upload results appear in completion order.');
      case ToastDemoPolicy.stack:
        const items = [
          (
            'Background sync complete',
            Icons.sync_outlined,
            ShowcaseColors.info,
          ),
          (
            'Permission check passed',
            Icons.verified_user_outlined,
            ShowcaseColors.primary,
          ),
          (
            'Cache warm-up complete',
            Icons.bolt_outlined,
            ShowcaseColors.danger,
          ),
        ];
        for (final item in items) {
          _showToast(
            message: item.$1,
            icon: item.$2,
            accent: item.$3,
            policy: OverlayToastDisplayPolicy.stack,
            alignment: Alignment.topRight,
          );
        }
        _setStatus(
          'Three independent background tasks appear together with offset positions.',
        );
    }
  }

  void _showToast({
    required String message,
    required IconData icon,
    required Color accent,
    required OverlayToastDisplayPolicy policy,
    Alignment alignment = Alignment.bottomCenter,
    Duration duration = const Duration(seconds: 2),
  }) {
    SuperOverlay.toast(
      message,
      builder: (_) => ToastSurface(icon: icon, text: message, accent: accent),
      options: OverlayToastOptions(
        tag: _feedbackToastTag,
        displayPolicy: policy,
        alignment: alignment,
        displayDuration: duration,
      ),
    );
  }

  void _showNotification() {
    const options = OverlayNotifyOptions(
      tag: _feedbackNotifyTag,
      strategy: OverlayStrategy.replaceExisting,
      displayDuration: Duration(seconds: 3),
    );
    final message = _notificationMessage(_notificationType);
    _notificationHandle = switch (_notificationType) {
      OverlayNotificationType.success => SuperOverlay.notify.success(
        message,
        options: options,
      ),
      OverlayNotificationType.failure => SuperOverlay.notify.failure(
        message,
        options: options,
      ),
      OverlayNotificationType.warning => SuperOverlay.notify.warning(
        message,
        options: options,
      ),
      OverlayNotificationType.error => SuperOverlay.notify.error(
        message,
        options: options,
      ),
      OverlayNotificationType.alert => SuperOverlay.notify.alert(
        message,
        options: options,
      ),
    };
    _setStatus('${_notificationLabel(_notificationType)} notification shown.');
  }

  void _setStatus(String status) {
    if (mounted) {
      setState(() => _status = status);
    }
  }

  @override
  void dispose() {
    final notificationHandle = _notificationHandle;
    _notificationHandle = null;
    unawaited(notificationHandle?.close());
    unawaited(
      SuperOverlay.close(
        target: OverlayCloseTarget.allToasts,
        tag: _feedbackToastTag,
        force: true,
      ),
    );
    super.dispose();
  }
}

String _notificationLabel(OverlayNotificationType type) {
  return switch (type) {
    OverlayNotificationType.success => 'Success',
    OverlayNotificationType.failure => 'Failure',
    OverlayNotificationType.warning => 'Warning',
    OverlayNotificationType.error => 'Error',
    OverlayNotificationType.alert => 'Alert',
  };
}

String _notificationMessage(OverlayNotificationType type) {
  return switch (type) {
    OverlayNotificationType.success =>
      'Success notification: operation complete',
    OverlayNotificationType.failure => 'Failure notification: result rejected',
    OverlayNotificationType.warning => 'Warning notification: check your input',
    OverlayNotificationType.error => 'Error notification: operation failed',
    OverlayNotificationType.alert => 'Alert notification: new task available',
  };
}
