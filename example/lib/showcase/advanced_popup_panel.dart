import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_overlay_surfaces.dart';
import 'showcase_theme.dart';
import 'showcase_widgets.dart';

const advancedPopupTags = <String>[
  'point-popup',
  'adjusted-popup',
  'scale-origin-popup',
  'mask-ignore-popup',
];

class AdvancedPopupPanel extends StatelessWidget {
  const AdvancedPopupPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      title: 'Popup 几何能力',
      subtitle: '定点、替换内容、缩放原点和遮罩透传',
      icon: Icons.architecture_outlined,
      accent: ShowcaseColors.violet,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () => _showPointPopup(),
            icon: const Icon(Icons.my_location_outlined),
            label: const Text('定点 Popup'),
          ),
          Builder(
            builder:
                (targetContext) => OutlinedButton.icon(
                  onPressed: () => _showAdjustedPopup(targetContext),
                  icon: const Icon(Icons.flip_to_front_outlined),
                  label: const Text('替换/调整 Popup'),
                ),
          ),
          Builder(
            builder:
                (targetContext) => OutlinedButton.icon(
                  onPressed: () => _showScaleOriginPopup(targetContext),
                  icon: const Icon(Icons.open_with_outlined),
                  label: const Text('缩放原点 Popup'),
                ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showMaskIgnorePopup(context),
            icon: const Icon(Icons.layers_clear_outlined),
            label: const Text('忽略遮罩区域'),
          ),
        ],
      ),
    );
  }

  void _showPointPopup() {
    SuperOverlay.popup.show<void>(
      builder:
          (_) => const PopupDemoSurface(
            title: '定点 Popup',
            message: '定点 Popup 内容',
            icon: Icons.my_location_outlined,
          ),
      options: const OverlayPopupOptions(
        tag: 'point-popup',
        targetPointBuilder: _pointPopupTarget,
        alignment: Alignment.topLeft,
        alignmentMode: OverlayPopupAlignmentMode.inside,
      ),
    );
  }

  void _showAdjustedPopup(BuildContext targetContext) {
    SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const PopupDemoSurface(
            title: '原始 Popup',
            message: '这个内容会被 replacement 替换',
            icon: Icons.flip_to_front_outlined,
          ),
      options: OverlayPopupOptions(
        tag: 'adjusted-popup',
        alignment: Alignment.bottomCenter,
        replacementBuilder: (info) {
          final target =
              '${info.targetSize.width.round()}x'
              '${info.targetSize.height.round()}';
          return PopupDemoSurface(
            title: '替换/调整 Popup',
            message: '替换后调整到右上方，目标尺寸 $target',
            icon: Icons.flip_to_front_outlined,
          );
        },
        adjustmentBuilder:
            (_) => const PopupAdjustment(alignment: Alignment.topRight),
      ),
    );
  }

  void _showScaleOriginPopup(BuildContext targetContext) {
    SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const PopupDemoSurface(
            title: '缩放原点 Popup',
            message: '从 Popup 右上角展开动画',
            icon: Icons.open_with_outlined,
          ),
      options: const OverlayPopupOptions(
        tag: 'scale-origin-popup',
        alignment: Alignment.bottomRight,
        scaleOriginBuilder: _scaleOriginTopRight,
      ),
    );
  }

  void _showMaskIgnorePopup(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    SuperOverlay.popup.show<void>(
      builder:
          (_) => const PopupDemoSurface(
            title: '忽略遮罩区域',
            message: '顶部 96px 不被遮罩拦截',
            icon: Icons.layers_clear_outlined,
          ),
      options: OverlayPopupOptions(
        tag: 'mask-ignore-popup',
        targetPointBuilder: _maskIgnoreTarget,
        alignment: Alignment.topCenter,
        maskIgnoreArea: Rect.fromLTWH(0, 0, screenWidth, 96),
      ),
    );
  }
}

Offset _pointPopupTarget(Offset targetOffset, Size targetSize) {
  return const Offset(260, 260);
}

Offset _scaleOriginTopRight(Size popupSize) {
  return Offset(popupSize.width, 0);
}

Offset _maskIgnoreTarget(Offset targetOffset, Size targetSize) {
  return const Offset(280, 320);
}
