import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:super_overlay/super_overlay.dart';

// snippet:root-integration:start
class RootOverlayApp extends StatefulWidget {
  const RootOverlayApp({super.key});

  @override
  State<RootOverlayApp> createState() => _RootOverlayAppState();
}

class _RootOverlayAppState extends State<RootOverlayApp> {
  late final SuperOverlayIntegration integration;

  @override
  void initState() {
    super.initState();
    integration = SuperOverlay.integration();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const AppHome(),
    );
  }

  @override
  void dispose() {
    integration.dispose();
    super.dispose();
  }
}
// snippet:root-integration:end

// snippet:nested-navigator:start
class NestedCheckoutFlow extends StatefulWidget {
  const NestedCheckoutFlow({super.key, required this.integration});

  final SuperOverlayIntegration integration;

  @override
  State<NestedCheckoutFlow> createState() => _NestedCheckoutFlowState();
}

class _NestedCheckoutFlowState extends State<NestedCheckoutFlow> {
  late final SuperOverlayNavigatorObserver observer;

  @override
  void initState() {
    super.initState();
    observer = widget.integration.navigatorObserver();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      observers: [observer],
      onGenerateRoute:
          (_) => MaterialPageRoute<void>(builder: (_) => const CheckoutHome()),
    );
  }

  @override
  void dispose() {
    observer.dispose();
    super.dispose();
  }
}
// snippet:nested-navigator:end

// snippet:shell-route:start
class ShellRouterOwner {
  ShellRouterOwner(this.integration);

  final SuperOverlayIntegration integration;
  late final SuperOverlayNavigatorObserver shellObserver =
      integration.navigatorObserver();
  late final GoRouter router = GoRouter(
    observers: [integration.observer],
    routes: [
      ShellRoute(
        observers: [shellObserver],
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const ShellHome()),
        ],
      ),
    ],
  );

  void dispose() {
    router.dispose();
    shellObserver.dispose();
  }
}
// snippet:shell-route:end

// snippet:stateful-shell-branches:start
class StatefulShellRouterOwner {
  StatefulShellRouterOwner(this.integration);

  final SuperOverlayIntegration integration;
  late final SuperOverlayNavigatorObserver firstBranchObserver =
      integration.navigatorObserver();
  late final SuperOverlayNavigatorObserver secondBranchObserver =
      integration.navigatorObserver();
  late final GoRouter router = GoRouter(
    observers: [integration.observer],
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                Scaffold(body: navigationShell),
        branches: [
          StatefulShellBranch(
            observers: [firstBranchObserver],
            routes: [
              GoRoute(
                path: '/first',
                builder: (context, state) => const FirstBranchHome(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [secondBranchObserver],
            routes: [
              GoRoute(
                path: '/second',
                builder: (context, state) => const SecondBranchHome(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  void dispose() {
    router.dispose();
    firstBranchObserver.dispose();
    secondBranchObserver.dispose();
  }
}
// snippet:stateful-shell-branches:end

void main() {
  const snippetIds = [
    'root-integration',
    'nested-navigator',
    'shell-route',
    'stateful-shell-branches',
  ];

  test('README exposes reciprocal English and Simplified Chinese editions', () {
    final englishFile = File('README.md');
    final chineseFile = File('README.zh-CN.md');

    expect(englishFile.existsSync(), isTrue);
    expect(
      chineseFile.existsSync(),
      isTrue,
      reason: 'README.zh-CN.md must provide the Simplified Chinese edition.',
    );

    final english = englishFile.readAsStringSync();
    final chinese = chineseFile.readAsStringSync();
    expect(english, contains('[简体中文](README.zh-CN.md)'));
    expect(chinese, contains('[English](README.md)'));
  });

  test('bilingual README snippets match compile-backed fixtures', () {
    final fixtureSource =
        File('test/documentation_contract_test.dart').readAsStringSync();

    for (final path in ['README.md', 'README.zh-CN.md']) {
      final readme = File(path).readAsStringSync();
      for (final id in snippetIds) {
        expect(
          _extractSnippet(readme, id),
          _extractSnippet(fixtureSource, id),
          reason: '$path snippet $id drifted from its compiled fixture.',
        );
      }
    }
  });

  test('bilingual README documents the moving-anchor viewport contract', () {
    final english = File('README.md').readAsStringSync();
    final chinese = File('README.zh-CN.md').readAsStringSync();

    expect(english, contains('Partial clipping at any Overlay viewport edge'));
    expect(english, contains('no positive-area intersection'));
    expect(chinese, contains('在 Overlay 视口任一边缘部分裁剪'));
    expect(chinese, contains('不再存在正面积交集'));
  });

  test('documented local links resolve and coverage matrix is linked', () {
    final files = [
      File('README.md'),
      File('README.zh-CN.md'),
      File('example/README.md'),
      File('RELEASE.md'),
      File('SECURITY.md'),
      File('CONTRIBUTING.md'),
      File('tool/verification/example_coverage_matrix.md'),
    ];

    for (final file in files) {
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing.');
      final content = file.readAsStringSync();
      for (final match in RegExp(
        r'\[[^\]]+\]\(([^)]+)\)',
      ).allMatches(content)) {
        final rawTarget = match.group(1)!;
        if (rawTarget.startsWith('#') ||
            rawTarget.startsWith('http://') ||
            rawTarget.startsWith('https://') ||
            rawTarget.startsWith('mailto:')) {
          continue;
        }
        final target = Uri.decodeComponent(
          rawTarget.split('#').first.split('?').first,
        );
        final linkedFile = File('${file.parent.path}/$target');
        expect(
          linkedFile.existsSync(),
          isTrue,
          reason: '${file.path} links to missing $rawTarget.',
        );
      }
    }

    for (final path in ['README.md', 'README.zh-CN.md']) {
      expect(
        File(path).readAsStringSync(),
        contains('tool/verification/example_coverage_matrix.md'),
      );
    }
  });
}

String _extractSnippet(String source, String id) {
  final startMarker = 'snippet:$id:start';
  final endMarker = 'snippet:$id:end';
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker);
  if (start < 0 || end < 0 || end <= start) {
    throw StateError('Missing or invalid snippet markers for $id.');
  }
  final contentStart = source.indexOf('\n', start) + 1;
  final contentEnd = source.lastIndexOf('\n', end);
  return source
      .substring(contentStart, contentEnd)
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .trim();
}

class AppHome extends StatelessWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class CheckoutHome extends StatelessWidget {
  const CheckoutHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class ShellHome extends StatelessWidget {
  const ShellHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class FirstBranchHome extends StatelessWidget {
  const FirstBranchHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SecondBranchHome extends StatelessWidget {
  const SecondBranchHome({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
