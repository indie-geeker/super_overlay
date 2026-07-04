part of 'showcase_home_page.dart';

mixin _ShowcaseHomeActions on State<ShowcaseHomePage> {
  List<GlobalKey> get _guideKeys;
  List<String> get _events;
  bool get _dialogDismissible;
  bool get _dialogDimmed;
  int get _popupSingle;
  set _popupSingle(int value);
  Set<int> get _popupMulti;
  PopupPlacement get _popupPlacement;
  int? get _guideStep;
  set _guideStep(int? value);
  OverlayHandle<void>? get _guideHandle;
  set _guideHandle(OverlayHandle<void>? value);

  void _pushPage(Widget page) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showDialogDemo() {
    final maskColor = _dialogDimmed ? ShowcaseColors.scrim : Colors.transparent;
    _log('Dialog: dismissible=$_dialogDismissible, dimmed=$_dialogDimmed');
    SuperOverlay.dialog.show<void>(
      builder:
          (_) => DialogSurface(
            dismissible: _dialogDismissible,
            dimmed: _dialogDimmed,
          ),
      options: OverlayDialogOptions(
        tag: 'dialog-lab',
        barrierColor: maskColor,
        dismissOnMaskTap: _dialogDismissible,
      ),
    );
  }

  void _showSingleToast() {
    _log('Toast: 单个自定义内容');
    SuperOverlay.toast(
      'single',
      builder:
          (_) => const ToastSurface(
            icon: Icons.verified_outlined,
            text: '图标 + 文案',
            accent: ShowcaseColors.primary,
          ),
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
        displayDuration: Duration(seconds: 2),
      ),
    );
  }

  void _showQueuedToasts() {
    _log('Toast: 队列依次展示');
    for (var index = 0; index < 3; index++) {
      SuperOverlay.toast(
        'queue-$index',
        builder:
            (_) => ToastSurface(
              icon: Icons.timelapse_outlined,
              text: '队列 Toast ${index + 1}',
              accent: ShowcaseColors.warning,
            ),
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.queue,
          displayDuration: Duration(milliseconds: 900),
        ),
      );
    }
  }

  void _showMultiToasts() {
    _log('Toast: 多个同时展示');
    const items = [
      (Icons.cloud_done_outlined, '同步完成', ShowcaseColors.info),
      (Icons.lock_open_outlined, '权限通过', ShowcaseColors.primary),
      (Icons.bolt_outlined, '任务加速', ShowcaseColors.danger),
    ];
    for (final item in items) {
      SuperOverlay.toast(
        item.$2,
        builder:
            (_) => ToastSurface(icon: item.$1, text: item.$2, accent: item.$3),
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          alignment: Alignment.topRight,
          displayDuration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDefaultToast() {
    _log('Default: Toast 使用初始化样式');
    SuperOverlay.toast(
      'Init 默认 Toast',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
        displayDuration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showDefaultLoading() async {
    _log('Default: Loading 使用初始化样式');
    final loading = SuperOverlay.loading.show(message: 'Init 默认 Loading');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    await loading.close();
    if (!mounted) {
      return;
    }
    _log('Default: Loading 已关闭');
  }

  void _showDefaultNotify() {
    _log('Default: Notify 使用初始化样式');
    SuperOverlay.notify.success(
      'Init 默认 Notify',
      options: const OverlayNotifyOptions(
        displayDuration: Duration(seconds: 2),
      ),
    );
  }

  void _showChoicePopup(BuildContext targetContext) {
    var selected = _popupSingle;
    final multi = Set<int>.from(_popupMulti);
    _log('Popup: 打开选择器');
    late final OverlayHandle<void> handle;
    handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => StatefulBuilder(
            builder: (context, setPopupState) {
              return ChoicePopup(
                selected: selected,
                multi: multi,
                onSelected: (value) {
                  setPopupState(() => selected = value);
                },
                onToggle: (value, enabled) {
                  setPopupState(() {
                    if (enabled) {
                      multi.add(value);
                    } else {
                      multi.remove(value);
                    }
                  });
                },
                onApply: () => _applyChoicePopup(selected, multi, handle),
              );
            },
          ),
      options: OverlayPopupOptions(
        tag: 'choice-popup',
        alignment: _popupAlignment,
        targetRectBuilder: (targetRect) => targetRect.inflate(4),
      ),
    );
  }

  void _showPointPopup() {
    _log('Popup: 定点显示');
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
    _log('Popup: 替换内容并调整位置');
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
            message: '替换/调整 Popup 内容，目标 $target',
            icon: Icons.flip_to_front_outlined,
          );
        },
        adjustmentBuilder:
            (_) => const PopupAdjustment(alignment: Alignment.topRight),
      ),
    );
  }

  void _showScaleOriginPopup(BuildContext targetContext) {
    _log('Popup: 自定义缩放原点');
    SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const PopupDemoSurface(
            title: '缩放原点 Popup',
            message: '缩放原点 Popup 内容',
            icon: Icons.open_with_outlined,
          ),
      options: const OverlayPopupOptions(
        tag: 'scale-origin-popup',
        alignment: Alignment.bottomRight,
        scaleOriginBuilder: _scaleOriginTopRight,
      ),
    );
  }

  void _showMaskIgnorePopup() {
    _log('Popup: 遮罩忽略顶部区域');
    SuperOverlay.popup.show<void>(
      builder:
          (_) => const PopupDemoSurface(
            title: '忽略遮罩区域',
            message: '忽略遮罩 Popup 内容',
            icon: Icons.layers_clear_outlined,
          ),
      options: const OverlayPopupOptions(
        tag: 'mask-ignore-popup',
        targetPointBuilder: _maskIgnoreTarget,
        alignment: Alignment.topCenter,
        maskIgnoreArea: Rect.fromLTRB(0, 0, 1000, 96),
      ),
    );
  }

  void _applyChoicePopup(
    int selected,
    Set<int> multi,
    OverlayHandle<void> handle,
  ) {
    setState(() {
      _popupSingle = selected;
      _popupMulti
        ..clear()
        ..addAll(multi);
    });
    _log('Popup: 已应用筛选条件');
    unawaited(handle.close());
  }

  Alignment get _popupAlignment {
    return switch (_popupPlacement) {
      PopupPlacement.top => Alignment.topCenter,
      PopupPlacement.bottom => Alignment.bottomCenter,
      PopupPlacement.left => Alignment.centerLeft,
      PopupPlacement.right => Alignment.centerRight,
    };
  }

  void _showNotify() {
    _log('Notify: 顶部通知');
    SuperOverlay.notify.success(
      'Notify message',
      options: const OverlayNotifyOptions(
        displayDuration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showAwaitDemo() async {
    _log('Await: 等待 visible');
    final handle = SuperOverlay.dialog.show<void>(
      builder:
          (_) => const SmallOverlay(
            title: 'Await Completion',
            message: '等待 visible future 完成后记录事件。',
          ),
      options: const OverlayDialogOptions(tag: 'await-demo'),
    );
    await handle.visible;
    if (!mounted) {
      return;
    }
    _log('Await: visible 完成');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await handle.close();
    if (!mounted) {
      return;
    }
    _log('Await: dismiss 完成');
  }

  Future<void> _startGuide() async {
    await _showGuideStep(0);
  }

  Future<void> _handleGuideTargetTap(int step) async {
    if (_guideStep != step) {
      _log('Guide: 点击了非当前目标');
      return;
    }

    if (step == _guideKeys.length - 1) {
      await _guideHandle?.close();
      _guideHandle = null;
      if (!mounted) {
        return;
      }
      setState(() => _guideStep = null);
      _log('Guide: 完成');
      _showSingleToast();
      return;
    }

    await _showGuideStep(step + 1);
  }

  Future<void> _showGuideStep(int step) async {
    await _guideHandle?.close();
    _guideHandle = null;
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
      _log('Guide: 第 ${step + 1} 步');
      final handle = SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => GuideBubble(step: step),
        options: OverlayPopupOptions(
          tag: _guideTag,
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
          if (_guideHandle == handle) {
            _guideHandle = null;
          }
        }),
      );
    });
  }

  void _log(String text) {
    if (!mounted) {
      return;
    }
    setState(() {
      _events.insert(0, text);
      if (_events.length > 6) {
        _events.removeLast();
      }
    });
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
