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
