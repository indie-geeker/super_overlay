import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import '../network_state/presentation/network_state_demo_page.dart';
import 'command_contracts_demo_page.dart';
import 'instant_feedback_panel.dart';
import 'lifecycle_demo_page.dart';
import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

part 'showcase_home_actions.dart';

enum PopupPlacement { top, bottom, left, right }

const _guideTag = 'showcase-guide';

class ShowcaseHomePage extends StatefulWidget {
  const ShowcaseHomePage({super.key});

  @override
  State<ShowcaseHomePage> createState() => _ShowcaseHomePageState();
}

class _ShowcaseHomePageState extends State<ShowcaseHomePage>
    with _ShowcaseHomeActions {
  @override
  final List<GlobalKey> _guideKeys = List.generate(3, (_) => GlobalKey());
  @override
  final List<String> _events = <String>['等待触发一个 overlay'];

  @override
  bool _dialogDismissible = true;
  @override
  bool _dialogDimmed = true;
  @override
  int _popupSingle = 1;
  @override
  final Set<int> _popupMulti = <int>{0, 2};
  @override
  PopupPlacement _popupPlacement = PopupPlacement.bottom;
  @override
  int? _guideStep;
  @override
  OverlayHandle<void>? _guideHandle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SuperOverlay Showcase'),
        actions: [
          IconButton(
            tooltip: 'Notify',
            onPressed: _showNotify,
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ShowcaseHeader(),
              const SizedBox(height: 14),
              const CapabilityStats(),
              const SizedBox(height: 16),
              _buildPanelGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        final width =
            isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: width, child: _buildDialogPanel()),
            SizedBox(width: width, child: const InstantFeedbackPanel()),
            SizedBox(width: width, child: _buildPopupPanel()),
            SizedBox(width: width, child: _buildGuidePanel()),
            SizedBox(width: width, child: _buildActivityPanel()),
            SizedBox(width: width, child: _buildLifecyclePanel()),
            SizedBox(width: width, child: _buildNetworkStatePanel()),
            SizedBox(width: width, child: _buildCommandContractsPanel()),
          ],
        );
      },
    );
  }

  Widget _buildDialogPanel() {
    return FeaturePanel(
      title: 'Dialog Lab',
      subtitle: '自定义弹窗、点击外部关闭、背景高亮',
      icon: Icons.dashboard_customize_outlined,
      accent: ShowcaseColors.primary,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('点击弹窗外部允许关闭'),
            value: _dialogDismissible,
            onChanged: (value) => setState(() => _dialogDismissible = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('背景高亮遮罩'),
            value: _dialogDimmed,
            onChanged: (value) => setState(() => _dialogDimmed = value),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _showDialogDemo,
              icon: const Icon(Icons.open_in_full),
              label: const Text('打开自定义弹窗'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupPanel() {
    final selectedText = '单选 ${_popupSingle + 1} / 多选 ${_popupMulti.length} 项';
    return FeaturePanel(
      title: 'Popup Window',
      subtitle: selectedText,
      icon: Icons.filter_alt_outlined,
      accent: ShowcaseColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popup 承载真实表单内容：单选、复选框、确认动作。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text('显示位置', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<PopupPlacement>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<PopupPlacement>(
                value: PopupPlacement.top,
                label: Text('上方'),
              ),
              ButtonSegment<PopupPlacement>(
                value: PopupPlacement.bottom,
                label: Text('下方'),
              ),
              ButtonSegment<PopupPlacement>(
                value: PopupPlacement.left,
                label: Text('左侧'),
              ),
              ButtonSegment<PopupPlacement>(
                value: PopupPlacement.right,
                label: Text('右侧'),
              ),
            ],
            selected: {_popupPlacement},
            onSelectionChanged: (values) {
              setState(() => _popupPlacement = values.first);
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (targetContext) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showChoicePopup(targetContext),
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('打开选择器'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showPointPopup,
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('定点 Popup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showAdjustedPopup(targetContext),
                    icon: const Icon(Icons.flip_to_front_outlined),
                    label: const Text('替换/调整 Popup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showScaleOriginPopup(targetContext),
                    icon: const Icon(Icons.open_with_outlined),
                    label: const Text('缩放原点 Popup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showMaskIgnorePopup,
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: const Text('忽略遮罩区域'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGuidePanel() {
    return FeaturePanel(
      title: 'Guided Mask',
      subtitle: '只能点击高亮目标，点击后推进下一步',
      icon: Icons.center_focus_strong_outlined,
      accent: ShowcaseColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GuideTarget(
                key: _guideKeys[0],
                label: '高亮入口',
                icon: Icons.touch_app_outlined,
                active: _guideStep == 0,
                onPressed: () => _handleGuideTargetTap(0),
              ),
              GuideTarget(
                key: _guideKeys[1],
                label: '配置参数',
                icon: Icons.tune_outlined,
                active: _guideStep == 1,
                onPressed: () => _handleGuideTargetTap(1),
              ),
              GuideTarget(
                key: _guideKeys[2],
                label: '状态面板',
                icon: Icons.analytics_outlined,
                active: _guideStep == 2,
                onPressed: () => _handleGuideTargetTap(2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _startGuide,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('开始引导'),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecyclePanel() {
    return FeaturePanel(
      title: 'Lifecycle Binding',
      subtitle: '页面绑定、控件绑定、返回键处理',
      icon: Icons.route_outlined,
      accent: ShowcaseColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '进入独立页面观察 overlay 如何随路由覆盖、目标控件卸载、返回键配置而变化。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(const LifecycleDemoPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开生命周期案例'),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStatePanel() {
    return FeaturePanel(
      title: 'Network State Demo',
      subtitle: '请求 loading、缺省页、错误页、局部图片状态',
      icon: Icons.cloud_sync_outlined,
      accent: ShowcaseColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '示例只在页面内渲染缺省页，overlay 负责 loading 和 toast。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(const NetworkStateDemoPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开网络状态案例'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandContractsPanel() {
    return FeaturePanel(
      title: 'Command Contracts',
      subtitle: '策略、Handle、exists、refreshActive、全局清理',
      icon: Icons.integration_instructions_outlined,
      accent: ShowcaseColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '通过可交互案例验证命令 API 的生命周期和标签策略。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(const CommandContractsDemoPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开命令契约案例'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPanel() {
    return FeaturePanel(
      title: 'Live Status',
      subtitle: '最近触发的 overlay 行为',
      icon: Icons.query_stats_outlined,
      accent: ShowcaseColors.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in _events.take(4)) ActivityRow(text: event),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => unawaited(_showAwaitDemo()),
            icon: const Icon(Icons.av_timer_outlined),
            label: const Text('Await 事件'),
          ),
        ],
      ),
    );
  }
}
