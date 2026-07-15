import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

enum ToastDemoPolicy { replaceLatest, queue, stack }

const _feedbackToastTag = 'showcase-feedback-toast';
const _feedbackNotifyTag = 'showcase-feedback-notify';
const _refreshActiveToastTag = 'showcase-refresh-active-toast';
const _handleOwnedToastTag = 'showcase-handle-owned-toast';

class InstantFeedbackPanel extends StatefulWidget {
  const InstantFeedbackPanel({super.key});

  @override
  State<InstantFeedbackPanel> createState() => _InstantFeedbackPanelState();
}

class _InstantFeedbackPanelState extends State<InstantFeedbackPanel> {
  ToastDemoPolicy _policy = ToastDemoPolicy.replaceLatest;
  OverlayNotificationType _notificationType = OverlayNotificationType.success;
  OverlayHandle<void>? _notificationHandle;
  OverlayHandle<void>? _handleOwnedToast;
  var _refreshActiveRevision = 0;
  var _handleRevision = 0;
  String _status = '选择一种策略，然后运行对应的反馈场景。';

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('instant-feedback-panel'),
      title: '即时反馈',
      subtitle: '保存、上传和系统事件中的 Toast 与 Notify',
      icon: Icons.notifications_active_outlined,
      accent: ShowcaseColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Toast 展示策略', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ToastDemoPolicy>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ToastDemoPolicy.replaceLatest,
                label: Text('替换最新'),
              ),
              ButtonSegment(value: ToastDemoPolicy.queue, label: Text('依次排队')),
              ButtonSegment(value: ToastDemoPolicy.stack, label: Text('同时显示')),
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
            label: const Text('运行 Toast 演示'),
          ),
          const SizedBox(height: 12),
          DemoStatusBanner(message: _status),
          const SizedBox(height: 16),
          Text('刷新契约', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => unawaited(_createRefreshDemo()),
                child: const Text('创建两类刷新 Toast'),
              ),
              OutlinedButton(
                onPressed:
                    _refreshActiveRevision == 0 ? null : _runRefreshActive,
                child: const Text('运行 refreshActive'),
              ),
              OutlinedButton(
                onPressed:
                    _handleOwnedToast == null ? null : _refreshHandleContent,
                child: const Text('调用 handle.refresh()'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text('顶部通知', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final selector = DropdownButtonFormField<OverlayNotificationType>(
                key: const ValueKey('feedback-notification-selector'),
                // `initialValue` is unavailable on the minimum Flutter 3.29.
                // ignore: deprecated_member_use
                value: _notificationType,
                decoration: const InputDecoration(
                  labelText: '通知类型',
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
                label: const Text('显示通知'),
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
            message: '保存结果 $index',
            icon: Icons.save_outlined,
            accent: ShowcaseColors.primary,
            policy: OverlayToastDisplayPolicy.replaceLatest,
          );
        }
        _setStatus('连续保存三次，只保留最后一次反馈。');
      case ToastDemoPolicy.queue:
        for (var index = 1; index <= 3; index++) {
          _showToast(
            message: '文件 $index 已上传',
            icon: Icons.cloud_upload_outlined,
            accent: ShowcaseColors.warning,
            policy: OverlayToastDisplayPolicy.queue,
            duration: const Duration(milliseconds: 900),
          );
        }
        _setStatus('三个上传结果会按照完成顺序依次显示。');
      case ToastDemoPolicy.stack:
        const items = [
          ('后台同步完成', Icons.sync_outlined, ShowcaseColors.info),
          ('权限校验通过', Icons.verified_user_outlined, ShowcaseColors.primary),
          ('缓存预热完成', Icons.bolt_outlined, ShowcaseColors.danger),
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
        _setStatus('三个独立后台任务会同时显示，并自动错开位置。');
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
    _setStatus('已显示${_notificationLabel(_notificationType)}通知。');
  }

  Future<void> _createRefreshDemo() async {
    await SuperOverlay.close(target: OverlayCloseTarget.allToasts, force: true);
    if (!mounted) {
      return;
    }

    _refreshActiveRevision = 1;
    _handleRevision = 1;
    _showRefreshActiveToast();

    late final OverlayHandle<void> handle;
    handle = SuperOverlay.toast(
      'handle-owned',
      builder:
          (_) => ToastSurface(
            icon: Icons.refresh_outlined,
            text: 'Handle 内容 $_handleRevision',
            accent: ShowcaseColors.info,
          ),
      options: const OverlayToastOptions(
        tag: _handleOwnedToastTag,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    _handleOwnedToast = handle;
    setState(() {
      _status = 'refreshActive 负责策略 lane；handle.refresh() 只重建自己的内容。';
    });
    unawaited(
      handle.closed.whenComplete(() {
        if (mounted && identical(_handleOwnedToast, handle)) {
          setState(() => _handleOwnedToast = null);
        }
      }),
    );
  }

  void _runRefreshActive() {
    setState(() => _refreshActiveRevision++);
    _showRefreshActiveToast();
  }

  void _showRefreshActiveToast() {
    final revision = _refreshActiveRevision;
    SuperOverlay.toast(
      'refresh-active',
      builder:
          (_) => ToastSurface(
            icon: Icons.policy_outlined,
            text: 'refreshActive 内容 $revision',
            accent: ShowcaseColors.warning,
          ),
      options: const OverlayToastOptions(
        tag: _refreshActiveToastTag,
        displayPolicy: OverlayToastDisplayPolicy.refreshActive,
        displayDuration: Duration(minutes: 1),
      ),
    );
  }

  void _refreshHandleContent() {
    final handle = _handleOwnedToast;
    if (handle == null) {
      return;
    }
    setState(() => _handleRevision++);
    handle.refresh();
  }

  void _setStatus(String status) {
    if (mounted) {
      setState(() => _status = status);
    }
  }

  @override
  void dispose() {
    final notificationHandle = _notificationHandle;
    final handleOwnedToast = _handleOwnedToast;
    _notificationHandle = null;
    _handleOwnedToast = null;
    unawaited(notificationHandle?.close());
    unawaited(handleOwnedToast?.close());
    unawaited(
      SuperOverlay.close(
        target: OverlayCloseTarget.allToasts,
        tag: _feedbackToastTag,
        force: true,
      ),
    );
    unawaited(
      SuperOverlay.close(
        target: OverlayCloseTarget.allToasts,
        tag: _refreshActiveToastTag,
        force: true,
      ),
    );
    super.dispose();
  }
}

String _notificationLabel(OverlayNotificationType type) {
  return switch (type) {
    OverlayNotificationType.success => '成功',
    OverlayNotificationType.failure => '失败',
    OverlayNotificationType.warning => '警告',
    OverlayNotificationType.error => '错误',
    OverlayNotificationType.alert => '提醒',
  };
}

String _notificationMessage(OverlayNotificationType type) {
  return switch (type) {
    OverlayNotificationType.success => '成功通知：操作已完成',
    OverlayNotificationType.failure => '失败通知：结果未通过',
    OverlayNotificationType.warning => '警告通知：请检查输入',
    OverlayNotificationType.error => '错误通知：操作失败',
    OverlayNotificationType.alert => '提醒通知：有新的待办事项',
  };
}
