import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

const _guideTag = 'showcase-guide';

class GuidedMaskPanel extends StatefulWidget {
  const GuidedMaskPanel({super.key});

  @override
  State<GuidedMaskPanel> createState() => _GuidedMaskPanelState();
}

class _GuidedMaskPanelState extends State<GuidedMaskPanel> {
  final _guideKeys = List<GlobalKey>.generate(3, (_) => GlobalKey());
  OverlayHandle<void>? _guideHandle;
  int? _guideStep;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      key: const ValueKey('guided-mask-panel'),
      title: '高亮引导',
      subtitle: '只允许点击当前高亮目标，完成后自动推进下一步',
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
            onPressed: () => unawaited(_showGuideStep(0)),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('开始引导'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGuideTargetTap(int step) async {
    if (_guideStep != step) {
      return;
    }

    if (step == _guideKeys.length - 1) {
      final handle = _guideHandle;
      _guideHandle = null;
      await handle?.close();
      if (!mounted) {
        return;
      }
      setState(() => _guideStep = null);
      SuperOverlay.toast(
        'guide-complete',
        builder:
            (_) => const ToastSurface(
              icon: Icons.verified_outlined,
              text: '引导已完成',
              accent: ShowcaseColors.primary,
            ),
        options: const OverlayToastOptions(
          tag: 'showcase-guide-complete',
          strategy: OverlayStrategy.replaceExisting,
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _showGuideStep(step + 1);
  }

  Future<void> _showGuideStep(int step) async {
    final previous = _guideHandle;
    _guideHandle = null;
    await previous?.close();
    if (!mounted) {
      return;
    }
    setState(() => _guideStep = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _guideStep != step) {
        return;
      }
      final targetContext = _guideKeys[step].currentContext;
      if (targetContext == null) {
        return;
      }
      final handle = SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => GuideBubble(step: step),
        options: OverlayPopupOptions(
          tag: _guideTag,
          strategy: OverlayStrategy.replaceExisting,
          alignment: step == 2 ? Alignment.topCenter : Alignment.bottomCenter,
          dismissOnMaskTap: false,
          highlightTarget: true,
          highlightMaskColor: ShowcaseColors.scrim,
          highlightPadding: const EdgeInsets.all(8),
          highlightBorderRadius: BorderRadius.circular(8),
        ),
      );
      _guideHandle = handle;
      unawaited(
        handle.closed.whenComplete(() {
          if (mounted && identical(_guideHandle, handle)) {
            setState(() {
              _guideHandle = null;
              _guideStep = null;
            });
          }
        }),
      );
    });
  }

  @override
  void dispose() {
    final handle = _guideHandle;
    _guideHandle = null;
    unawaited(handle?.close());
    super.dispose();
  }
}
