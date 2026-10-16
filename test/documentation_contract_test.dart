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
  late final integration = SuperOverlay.integration();

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

// snippet:quick-commands:start
Future<bool?> confirmAndSync(
  BuildContext context,
  Future<void> Function() syncProfile,
) async {
  final confirmed =
      await SuperOverlay.of(context).dialog
          .show<bool>(
            builder:
                (_, dialog) => AlertDialog(
                  title: const Text('Sync profile?'),
                  actions: [
                    TextButton(
                      onPressed: () => dialog.close(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => dialog.close(true),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
          )
          .closed;
  if (confirmed == true) {
    await SuperOverlay.loading.run(syncProfile, message: 'Syncing profile...');
    SuperOverlay.toast('Saved');
  }
  return confirmed;
}
// snippet:quick-commands:end

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

// snippet:explicit-local-values:start
OverlayHandle<void> showLocalizedConfirmation(
  BuildContext owner,
  String confirmationText,
) {
  final locale = Localizations.localeOf(owner);
  return SuperOverlay.of(owner).dialog.show<void>(
    builder:
        (overlayContext, _) => Localizations.override(
          context: overlayContext,
          locale: locale,
          child: AlertDialog(content: Text(confirmationText)),
        ),
  );
}
// snippet:explicit-local-values:end

void main() {
  const snippetIds = [
    'root-integration',
    'quick-commands',
    'nested-navigator',
    'shell-route',
    'stateful-shell-branches',
    'explicit-local-values',
  ];

  testWidgets('quick-start confirmation runs and cleans up the task', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    late BuildContext owner;
    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: Builder(
          builder: (context) {
            owner = context;
            return const Scaffold();
          },
        ),
      ),
    );
    var calls = 0;
    final result = confirmAndSync(owner, () async {
      calls++;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(calls, 1);
    expect(find.text('Saved'), findsOneWidget);
    expect(
      SuperOverlay.exists(surfaces: const {OverlaySurface.loading}),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('explicit values and local locale reach root overlay content', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    late BuildContext owner;
    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: Builder(
          builder:
              (context) => Localizations.override(
                context: context,
                locale: const Locale('en', 'GB'),
                child: Builder(
                  builder: (context) {
                    owner = context;
                    return const Scaffold();
                  },
                ),
              ),
        ),
      ),
    );
    final handle = showLocalizedConfirmation(owner, 'Captured value');
    await tester.pumpAndSettle();
    expect(
      Localizations.localeOf(tester.element(find.text('Captured value'))),
      const Locale('en', 'GB'),
    );
    final closing = handle.close();
    await tester.pumpAndSettle();
    await closing;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

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
