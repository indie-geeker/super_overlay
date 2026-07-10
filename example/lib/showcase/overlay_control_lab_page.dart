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
  var _strategyResult = '选择策略后，用同一个业务 tag 连续触发两次。';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay 控制实验室')),
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
      title: '重复触发应该怎样处理？',
      subtitle: '登录失败提示连续到达时，tag 策略决定保留哪些',
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
                label: Text('允许多个'),
              ),
              ButtonSegment(
                value: _DuplicateStrategy.keepExisting,
                label: Text('保留已有'),
              ),
              ButtonSegment(
                value: _DuplicateStrategy.replaceExisting,
                label: Text('替换已有'),
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
            label: const Text('模拟连续触发两次'),
          ),
          const SizedBox(height: 10),
          DemoStatusBanner(message: _strategyResult),
        ],
      ),
    );
  }

  Widget _buildHandlePanel() {
    return FeaturePanel(
      title: '已经显示的 Overlay 怎样控制？',
      subtitle: '上传进度只刷新自己的 Handle，不影响其他 Toast',
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
                child: const Text('开始上传'),
              ),
              OutlinedButton(
                onPressed: _uploadHandle == null ? null : _advanceUpload,
                child: const Text('推进进度'),
              ),
              OutlinedButton(
                onPressed:
                    _uploadHandle == null
                        ? null
                        : () => unawaited(_cancelUpload()),
                child: const Text('取消上传'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _uploadHandle == null
                ? '当前没有活动上传'
                : '当前进度：$_uploadProgress% · exists(${SuperOverlay.exists(tag: _uploadTag)})',
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitPanel() {
    return FeaturePanel(
      title: '等待生命周期',
      subtitle: 'visible 和 closed 让后续业务代码等待真实节点',
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
            label: const Text('开始 Await 演示'),
          ),
          const SizedBox(height: 10),
          if (_awaitEvents.isEmpty)
            const Text('时间线会在这里逐步出现。')
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
      title: '清理边界',
      subtitle: '默认只关闭当前页面拥有的 Overlay',
      icon: Icons.cleaning_services_outlined,
      accent: ShowcaseColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonal(
            onPressed: () => unawaited(_closeOwnedOverlays()),
            child: const Text('清理本页 Overlay'),
          ),
          const SizedBox(height: 12),
          Text(
            '危险操作：全局清理会关闭其他业务模块创建的 Overlay。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ShowcaseColors.danger),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => unawaited(_confirmGlobalCleanup()),
            child: const Text('关闭全部 Overlay'),
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
        _showStrategyDialog('登录提示 #1', OverlayStrategy.stack);
        _showStrategyDialog('登录提示 #2', OverlayStrategy.stack);
        _setStrategyResult('结果：两次提示都保留，适合独立事件。');
      case _DuplicateStrategy.keepExisting:
        _showStrategyDialog('登录提示 #1', OverlayStrategy.stack);
        _showStrategyDialog('登录提示 #2', OverlayStrategy.keepExisting);
        _setStrategyResult('结果：忽略第二次重复触发，保留已有提示。');
      case _DuplicateStrategy.replaceExisting:
        _showStrategyDialog('登录提示 #1', OverlayStrategy.replaceExisting);
        _showStrategyDialog('登录提示 #2', OverlayStrategy.replaceExisting);
        _setStrategyResult('结果：第二次触发替换第一次，只保留最新提示。');
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
                const Text('相同 tag 的下一次触发会按当前策略处理。'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => unawaited(handle.close()),
                    child: const Text('关闭这条提示'),
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
            text: '上传进度 $_uploadProgress%',
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
      ..add('1. Handle 已创建');
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
                const Text('关闭后，页面才继续执行 closed 之后的逻辑。'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => unawaited(_closeAwaitOverlay()),
                    child: const Text('关闭 Await Overlay'),
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
        setState(() => _awaitEvents.add('2. 首帧已经显示'));
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
      setState(() => _awaitEvents.add('3. Overlay 已关闭'));
    }
    await handle.close();
    if (!mounted || !identical(_awaitHandle, handle)) {
      return;
    }
    await handle.closed;
    setState(() {
      _awaitEvents.add('4. closed Future 已完成');
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
            title: const Text('关闭全部 Overlay？'),
            content: const Text('这会同时关闭其他业务模块拥有的 Overlay。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认全部关闭'),
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
