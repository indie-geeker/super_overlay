import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_overlay/super_overlay.dart';
// Development-only resource snapshots; not a consumer API.
// ignore: implementation_imports
import 'package:super_overlay/src/helper/overlay_manager.dart';
// ignore: implementation_imports
import 'package:super_overlay/src/helper/navigator_scope_registry.dart';

void main() => runApp(
  const OverlayPerformanceApp(
    autorun: bool.fromEnvironment('OVERLAY_BENCHMARK_AUTORUN'),
  ),
);

/// A development harness; frame timings and logical resource counts are
/// different evidence. This app does not claim to measure heap retention.
class OverlayPerformanceApp extends StatefulWidget {
  const OverlayPerformanceApp({
    super.key,
    this.autorun = false,
    this.rounds = 3,
    this.movingFrames = 120,
  });

  final bool autorun;
  final int rounds;
  final int movingFrames;

  @override
  State<OverlayPerformanceApp> createState() => _OverlayPerformanceAppState();
}

class _OverlayPerformanceAppState extends State<OverlayPerformanceApp> {
  final List<Map<String, int>> _frames = [];
  GlobalKey<_SceneState> _scene = GlobalKey();
  int _generation = 0;
  bool _running = false;
  String _status = 'Ready';
  void _timings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames.add({
        'uiUs': timing.buildDuration.inMicroseconds,
        'rasterUs': timing.rasterDuration.inMicroseconds,
        'totalUs': timing.totalSpan.inMicroseconds,
      });
    }
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timings);
    if (widget.autorun) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
    }
  }

  Future<void> _measure(
    String phase,
    int round,
    Future<void> Function() action,
  ) async {
    setState(() => _status = '$phase / round ${round + 1}');
    // Flush Flutter's batched timings before and after each sample window.
    await Future<void>.delayed(const Duration(milliseconds: 750));
    _frames.clear();
    final before = _resources();
    final builds = _SceneState.contentBuilds;
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 750));
    final record = {
      'phase': phase,
      'round': round,
      'window': {
        'width': MediaQuery.sizeOf(_scene.currentContext!).width,
        'height': MediaQuery.sizeOf(_scene.currentContext!).height,
        'dpr': MediaQuery.devicePixelRatioOf(_scene.currentContext!),
      },
      'frames': List.of(_frames),
      'contentBuilds': _SceneState.contentBuilds - builds,
      'resourcesBefore': before,
      'resourcesAfter': _resources(),
      'businessTicks': _BusinessForm.ticks,
    };
    // Machine-readable output is intentional in this development entry.
    // ignore: avoid_print
    print('OVERLAY_SAMPLE ${jsonEncode(record)}');
  }

  Map<String, int> _resources() => {
    // ignore: invalid_use_of_visible_for_testing_member
    ...OverlayManager.instance.debugResourceCounts,
    // ignore: invalid_use_of_visible_for_testing_member
    'scopes': NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
    // ignore: invalid_use_of_visible_for_testing_member
    'routes': NavigatorScopeRegistry.instance.debugTrackedRouteCount,
    'businessTimers': _BusinessForm.liveTimers,
    'businessSubscriptions': _BusinessForm.liveSubscriptions,
  };

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      // Warm-up uses the same moving-popup path, outside measured windows.
      await _scene.currentState!.moving(1, 30);
      for (var round = 0; round < widget.rounds; round++) {
        await _measure(
          'idle',
          round,
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await _measure(
          'stationary8',
          round,
          () => _scene.currentState!.moving(
            8,
            widget.movingFrames,
            stationary: true,
          ),
        );
        await _measure(
          'moving1',
          round,
          () => _scene.currentState!.moving(1, widget.movingFrames),
        );
        await _measure(
          'moving8',
          round,
          () => _scene.currentState!.moving(8, widget.movingFrames),
        );
        await _measure(
          'pausedForm',
          round,
          () => _scene.currentState!.pausedForm(),
        );
        await _measure(
          'closeCycles',
          round,
          () => _scene.currentState!.closeCycles(),
        );
        await _measure('hostReplacement', round, () async {
          final old = SuperOverlay.notify.success(
            'old generation',
            options: const OverlayNotifyOptions(
              tag: 'benchmark-host',
              displayDuration: null,
            ),
          );
          await old.visible;
          for (var i = 0; i < 5; i++) {
            setState(() {
              _generation++;
              _scene = GlobalKey();
            });
            await WidgetsBinding.instance.endOfFrame;
          }
          await old.closed;
          old.refresh();
          await old.close();
        });
      }
      setState(() => _status = 'Complete');
      // ignore: avoid_print
      print('OVERLAY_BENCHMARK_DONE');
    } catch (error, stack) {
      if (mounted) setState(() => _status = 'Failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => _OwnedHost(
    key: ValueKey(_generation),
    sceneKey: _scene,
    status: _status,
    run: _running ? null : () => unawaited(_run()),
  );

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }
}

class _OwnedHost extends StatefulWidget {
  const _OwnedHost({
    super.key,
    required this.sceneKey,
    required this.status,
    required this.run,
  });
  final GlobalKey<_SceneState> sceneKey;
  final String status;
  final VoidCallback? run;
  @override
  State<_OwnedHost> createState() => _OwnedHostState();
}

class _OwnedHostState extends State<_OwnedHost> {
  late final SuperOverlayIntegration _integration = SuperOverlay.integration();
  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: _integration.builder,
    navigatorObservers: [_integration.observer],
    home: _Scene(key: widget.sceneKey, status: widget.status, run: widget.run),
  );
  @override
  void dispose() {
    _integration.dispose();
    super.dispose();
  }
}

class _Scene extends StatefulWidget {
  const _Scene({super.key, required this.status, required this.run});
  final String status;
  final VoidCallback? run;
  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  static int contentBuilds = 0;
  final List<GlobalKey> _targets = List.generate(8, (_) => GlobalKey());
  double _offset = 0;

  Future<void> moving(int count, int frames, {bool stationary = false}) async {
    final handles = [
      for (var i = 0; i < count; i++)
        SuperOverlay.of(_targets[i].currentContext!).popup.show<void>(
          targetContext: _targets[i].currentContext!,
          builder: (_, _) {
            contentBuilds++;
            return SizedBox(width: 80, height: 32, child: Text('Popup $i'));
          },
          options: OverlayPopupOptions(
            tag: 'benchmark-$i',
            backBehavior: OverlayBackBehavior.passThrough,
          ),
        ),
    ];
    await Future.wait(handles.map((h) => h.visible));
    for (var frame = 0; frame < frames; frame++) {
      setState(() => _offset = stationary ? 0 : (frame % 40) * 1.0);
      await WidgetsBinding.instance.endOfFrame;
    }
    await Future.wait(handles.map((h) => h.close()));
  }

  Future<void> pausedForm() async {
    final handle = SuperOverlay.of(
      context,
    ).dialog.show<void>(builder: (_, _) => const _BusinessForm());
    await handle.visible;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered route')),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    navigator.pop();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await handle.close();
  }

  Future<void> closeCycles() async {
    for (var i = 0; i < 10; i++) {
      final handle = SuperOverlay.dialog.show<void>(
        builder: (_, _) => const Text('Cycle'),
      );
      await handle.visible;
      await Future.wait([handle.close(), handle.close()]);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Overlay performance scenarios')),
    body: Column(
      children: [
        Text(widget.status),
        FilledButton(onPressed: widget.run, child: const Text('Run samples')),
        Expanded(
          child: Stack(
            children: [
              for (var i = 0; i < _targets.length; i++)
                Positioned(
                  left: 30 + (i % 4) * 140 + _offset,
                  top: 40 + (i ~/ 4) * 100,
                  child: SizedBox(
                    key: _targets[i],
                    width: 100,
                    height: 40,
                    child: Text('Anchor $i'),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BusinessForm extends StatefulWidget {
  const _BusinessForm();
  static int liveTimers = 0;
  static int liveSubscriptions = 0;
  static int ticks = 0;
  @override
  State<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends State<_BusinessForm> {
  late final Timer _timer;
  late final StreamSubscription<int> _subscription;
  @override
  void initState() {
    super.initState();
    _BusinessForm.liveTimers++;
    _BusinessForm.liveSubscriptions++;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _BusinessForm.ticks++;
    });
    _subscription = Stream<int>.periodic(
      const Duration(milliseconds: 50),
      (n) => n,
    ).listen((_) {});
  }

  @override
  Widget build(BuildContext context) => const AlertDialog(
    content: TextField(decoration: InputDecoration(labelText: 'Retained form')),
  );
  @override
  void dispose() {
    _timer.cancel();
    unawaited(_subscription.cancel());
    _BusinessForm.liveTimers--;
    _BusinessForm.liveSubscriptions--;
    super.dispose();
  }
}
