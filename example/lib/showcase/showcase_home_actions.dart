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

  void _pushPage(Widget page) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showDialogDemo() {
    final maskColor = _dialogDimmed ? ShowcaseColors.scrim : Colors.transparent;
    _log('Dialog: dismissible=$_dialogDismissible, dimmed=$_dialogDimmed');
    SuperOverlay.show(
          builder: (_) => DialogSurface(
            dismissible: _dialogDismissible,
            dimmed: _dialogDimmed,
          ),
        )
        .withTag('dialog-lab')
        .withMask(color: maskColor, dismissible: _dialogDismissible)
        .onMask(() => _log('Dialog mask tapped'))
        .fire<void>();
  }

  void _showSingleToast() {
    _log('Toast: 单个自定义内容');
    SuperOverlay.showToast(
          'single',
          builder: (_) => const ToastSurface(
            icon: Icons.verified_outlined,
            text: '图标 + 文案',
            accent: ShowcaseColors.primary,
          ),
        )
        .withDisplayType(ToastDisplayType.last)
        .withDisplayTime(const Duration(seconds: 2))
        .fire<void>();
  }

  void _showQueuedToasts() {
    _log('Toast: 队列依次展示');
    for (var index = 0; index < 3; index++) {
      SuperOverlay.showToast(
            'queue-$index',
            builder: (_) => ToastSurface(
              icon: Icons.timelapse_outlined,
              text: '队列 Toast ${index + 1}',
              accent: ShowcaseColors.warning,
            ),
          )
          .withDisplayType(ToastDisplayType.normal)
          .withDisplayTime(const Duration(milliseconds: 900))
          .fire<void>();
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
      SuperOverlay.showToast(
            item.$2,
            builder: (_) =>
                ToastSurface(icon: item.$1, text: item.$2, accent: item.$3),
          )
          .withDisplayType(ToastDisplayType.multi)
          .withAlignment(Alignment.topRight)
          .withDisplayTime(const Duration(seconds: 2))
          .fire<void>();
    }
  }

  void _showDefaultToast() {
    _log('Default: Toast 使用初始化样式');
    SuperOverlay.showToast('Init 默认 Toast')
        .withDisplayType(ToastDisplayType.last)
        .withDisplayTime(const Duration(seconds: 2))
        .fire<void>();
  }

  Future<void> _showDefaultLoading() async {
    _log('Default: Loading 使用初始化样式');
    SuperOverlay.showLoading(msg: 'Init 默认 Loading').fire<void>();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    await SuperOverlay.dismiss(status: DismissStatus.loading);
    if (!mounted) {
      return;
    }
    _log('Default: Loading 已关闭');
  }

  void _showDefaultNotify() {
    _log('Default: Notify 使用初始化样式');
    SuperOverlay.showNotify(
      msg: 'Init 默认 Notify',
      type: NotifyType.success,
    ).withDisplayTime(const Duration(seconds: 2)).fire<void>();
  }

  void _showChoicePopup(BuildContext targetContext) {
    var selected = _popupSingle;
    final multi = Set<int>.from(_popupMulti);
    _log('Popup: 打开选择器');
    SuperOverlay.showPopup(
          targetContext: targetContext,
          builder: (_) => StatefulBuilder(
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
                onApply: () => _applyChoicePopup(selected, multi),
              );
            },
          ),
        )
        .withTag('choice-popup')
        .withAlignment(_popupAlignment)
        .withTargetRect((targetRect) => targetRect.inflate(4))
        .withMask(color: Colors.transparent, dismissible: true)
        .fire<void>();
  }

  void _showPointPopup() {
    _log('Popup: 定点显示');
    SuperOverlay.showPopup(
          builder: (_) => const PopupDemoSurface(
            title: '定点 Popup',
            message: '定点 Popup 内容',
            icon: Icons.my_location_outlined,
          ),
        )
        .withTag('point-popup')
        .withTargetPoint((_, _) => const Offset(260, 260))
        .withAlignment(Alignment.topLeft)
        .withAlignmentMode(PopupAlignmentMode.inside)
        .withMask(color: Colors.transparent, dismissible: true)
        .fire<void>();
  }

  void _showAdjustedPopup(BuildContext targetContext) {
    _log('Popup: 替换内容并调整位置');
    SuperOverlay.showPopup(
          targetContext: targetContext,
          builder: (_) => const PopupDemoSurface(
            title: '原始 Popup',
            message: '这个内容会被 replacement 替换',
            icon: Icons.flip_to_front_outlined,
          ),
        )
        .withTag('adjusted-popup')
        .withAlignment(Alignment.bottomCenter)
        .withReplacement((info) {
          final target =
              '${info.targetSize.width.round()}x'
              '${info.targetSize.height.round()}';
          return PopupDemoSurface(
            title: '替换/调整 Popup',
            message: '替换/调整 Popup 内容，目标 $target',
            icon: Icons.flip_to_front_outlined,
          );
        })
        .withAdjustment((_) {
          return const PopupAdjustment(alignment: Alignment.topRight);
        })
        .withMask(color: Colors.transparent, dismissible: true)
        .fire<void>();
  }

  void _showScaleOriginPopup(BuildContext targetContext) {
    _log('Popup: 自定义缩放原点');
    SuperOverlay.showPopup(
          targetContext: targetContext,
          builder: (_) => const PopupDemoSurface(
            title: '缩放原点 Popup',
            message: '缩放原点 Popup 内容',
            icon: Icons.open_with_outlined,
          ),
        )
        .withTag('scale-origin-popup')
        .withAlignment(Alignment.bottomRight)
        .withScaleOrigin((popupSize) => Offset(popupSize.width, 0))
        .withMask(color: Colors.transparent, dismissible: true)
        .fire<void>();
  }

  void _showMaskIgnorePopup() {
    _log('Popup: 遮罩忽略顶部区域');
    SuperOverlay.showPopup(
          builder: (_) => const PopupDemoSurface(
            title: '忽略遮罩区域',
            message: '忽略遮罩 Popup 内容',
            icon: Icons.layers_clear_outlined,
          ),
        )
        .withTag('mask-ignore-popup')
        .withTargetPoint((_, _) => const Offset(280, 320))
        .withAlignment(Alignment.topCenter)
        .withMask(color: ShowcaseColors.scrim, dismissible: true)
        .withMaskIgnoreArea(const Rect.fromLTRB(0, 0, 1000, 96))
        .fire<void>();
  }

  void _applyChoicePopup(int selected, Set<int> multi) {
    setState(() {
      _popupSingle = selected;
      _popupMulti
        ..clear()
        ..addAll(multi);
    });
    _log('Popup: 已应用筛选条件');
    SuperOverlay.dismiss(status: DismissStatus.attach, tag: 'choice-popup');
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
    SuperOverlay.showNotify(
      msg: 'Notify message',
      type: NotifyType.success,
    ).withDisplayTime(const Duration(seconds: 2)).fire<void>();
  }

  Future<void> _showAwaitDemo() async {
    _log('Await: 等待 appear');
    await SuperOverlay.show(
      builder: (_) => const SmallOverlay(
        title: 'Await Completion',
        message: '等待打开动画完成后记录事件。',
      ),
    ).withTag('await-demo').withAwait(AwaitCompletion.appear).fire<void>();
    if (!mounted) {
      return;
    }
    _log('Await: appear 完成');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await SuperOverlay.dismiss(tag: 'await-demo', force: true);
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
      await SuperOverlay.dismiss(
        status: DismissStatus.attach,
        tag: _guideTag,
        force: true,
      );
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
    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: _guideTag,
      force: true,
    );
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
      unawaited(
        SuperOverlay.showPopup(
              targetContext: targetContext,
              builder: (_) => GuideBubble(step: step),
            )
            .withTag(_guideTag)
            .withAlignment(
              step == 2 ? Alignment.topCenter : Alignment.bottomCenter,
            )
            .withMask(dismissible: false)
            .withHighlight(
              maskColor: ShowcaseColors.scrim,
              padding: const EdgeInsets.all(8),
              borderRadius: BorderRadius.circular(8),
            )
            .fire<void>(),
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
