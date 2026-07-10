import 'package:flutter/material.dart';

import '../network_state/presentation/network_state_demo_page.dart';
import 'anchored_menu_panel.dart';
import 'dialog_demo_panel.dart';
import 'guided_mask_panel.dart';
import 'instant_feedback_panel.dart';
import 'lifecycle_demo_page.dart';
import 'overlay_control_lab_page.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

class ShowcaseHomePage extends StatelessWidget {
  const ShowcaseHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SuperOverlay Showcase')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ShowcaseHeader(),
              const SizedBox(height: 24),
              const ShowcaseSectionTitle(
                title: '常用场景',
                subtitle: '从业务反馈、锚点菜单、弹窗和网络状态开始',
              ),
              const SizedBox(height: 12),
              const _ResponsivePair(
                first: InstantFeedbackPanel(),
                second: AnchoredMenuPanel(),
              ),
              const SizedBox(height: 16),
              _ResponsivePair(
                first: const DialogDemoPanel(),
                second: _buildNetworkStatePanel(context),
              ),
              const SizedBox(height: 28),
              const ShowcaseSectionTitle(
                title: '交互增强',
                subtitle: '用高亮遮罩组织不可跳步的新手引导',
              ),
              const SizedBox(height: 12),
              const GuidedMaskPanel(),
              const SizedBox(height: 28),
              const ShowcaseSectionTitle(
                title: '高级能力',
                subtitle: '深入路由生命周期、标签策略和 Handle 控制',
              ),
              const SizedBox(height: 12),
              _ResponsivePair(
                first: _buildLifecyclePanel(context),
                second: _buildControlLabPanel(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkStatePanel(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('network-state-panel'),
      title: '网络请求状态',
      subtitle: '请求 loading、缺省页、错误页和局部图片状态',
      icon: Icons.cloud_sync_outlined,
      accent: ShowcaseColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '缺省与错误内容在页面内渲染，Overlay 只负责 loading 和 Toast。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(context, const NetworkStateDemoPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开网络状态案例'),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecyclePanel(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('lifecycle-panel'),
      title: '生命周期绑定',
      subtitle: '页面绑定、控件绑定和返回键处理',
      icon: Icons.route_outlined,
      accent: ShowcaseColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '观察 Overlay 如何随路由覆盖、目标控件卸载和返回键策略变化。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(context, const LifecycleDemoPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开生命周期案例'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlLabPanel(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('control-lab-panel'),
      title: 'Overlay 控制实验室',
      subtitle: '用真实业务场景理解策略、Handle 和生命周期',
      icon: Icons.integration_instructions_outlined,
      accent: ShowcaseColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '比较重复触发策略，再亲手刷新、关闭和 await 一个 Overlay。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pushPage(context, const OverlayControlLabPage()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开控制实验室'),
          ),
        ],
      ),
    );
  }

  void _pushPage(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 16), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
