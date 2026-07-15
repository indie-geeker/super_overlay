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
      title: 'Popup Geometry',
      subtitle:
          'Point targets, replacement content, scale origins, and mask pass-through',
      icon: Icons.architecture_outlined,
      accent: ShowcaseColors.violet,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () => _showPointPopup(),
            icon: const Icon(Icons.my_location_outlined),
            label: const Text('Point Popup'),
          ),
          Builder(
            builder:
                (targetContext) => OutlinedButton.icon(
                  onPressed: () => _showAdjustedPopup(targetContext),
                  icon: const Icon(Icons.flip_to_front_outlined),
                  label: const Text('Replacement / Adjustment Popup'),
                ),
          ),
          Builder(
            builder:
                (targetContext) => OutlinedButton.icon(
                  onPressed: () => _showScaleOriginPopup(targetContext),
                  icon: const Icon(Icons.open_with_outlined),
                  label: const Text('Scale Origin Popup'),
                ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showMaskIgnorePopup(context),
            icon: const Icon(Icons.layers_clear_outlined),
            label: const Text('Ignore Mask Area'),
          ),
        ],
      ),
    );
  }

  void _showPointPopup() {
    SuperOverlay.popup.show<void>(
      builder:
          (_) => const PopupDemoSurface(
            title: 'Point Popup',
            message: 'Point Popup Content',
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
            title: 'Original Popup',
            message: 'Replacement content will replace this surface',
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
            title: 'Replacement / Adjustment Popup',
            message:
                'Moves to the upper-right after replacement. Target size: $target',
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
            title: 'Scale Origin Popup',
            message: "Expands from the popup's upper-right corner",
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
            title: 'Ignore Mask Area',
            message: 'Top 96px remains interactive through the mask',
            icon: Icons.layers_clear_outlined,
          ),
      options: OverlayPopupOptions(
        tag: 'mask-ignore-popup',
        targetPointBuilder: _maskIgnoreTarget,
        alignment: Alignment.topCenter,
        backBehavior: OverlayBackBehavior.passThrough,
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
