part of 'showcase_home_page.dart';

mixin _ShowcaseHomeActions on State<ShowcaseHomePage> {
  List<GlobalKey> get _guideKeys;
  List<String> get _events;
  bool get _dialogDismissible;
  bool get _dialogDimmed;
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
