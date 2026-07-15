import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('custom notify keeps a visual gap below the safe area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(const MyApp());
    final handles = [
      SuperOverlay.notify.success('success'),
      SuperOverlay.notify.failure('failure'),
      SuperOverlay.notify.warning('warning'),
      SuperOverlay.notify.error('error'),
      SuperOverlay.notify.alert('alert'),
    ];
    await tester.pump();

    for (final type in OverlayNotificationType.values) {
      final surface = find.byKey(ValueKey('init-notify-${type.name}'));
      expect(surface, findsOneWidget);
      expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(56));
    }

    await SuperOverlay.close(
      target: OverlayCloseTarget.allNotifications,
      force: true,
    );
    await Future.wait(handles.map((handle) => handle.closed));
  });

  testWidgets('example exposes reference parity demo cases', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SuperOverlay Showcase'), findsOneWidget);

    for (final label in [
      'Replace Latest',
      'Queue',
      'Stack',
      'Show Notification',
      'Open Control Lab',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.ensureVisible(find.text('Run Toast Demo'));
    await tester.tap(find.text('Run Toast Demo'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Save result 3'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts, force: true);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Open Control Lab'));
    await tester.tap(find.text('Open Control Lab'));
    await tester.pumpAndSettle();

    for (final label in [
      'Point Popup',
      'Replacement / Adjustment Popup',
      'Scale Origin Popup',
      'Ignore Mask Area',
    ]) {
      await tester.ensureVisible(find.text(label));
      expect(find.text(label), findsOneWidget);
    }

    await tester.ensureVisible(find.text('Point Popup'));
    await tester.tap(find.text('Point Popup'));
    await tester.pumpAndSettle();
    expect(find.text('Point Popup Content'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allPopups, force: true);
    await tester.pumpAndSettle();
  });

  testWidgets('mask ignore popup passes only taps inside the top strip', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('Open Control Lab'));
    await tester.tap(find.text('Open Control Lab'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ignore Mask Area'));
    await tester.tap(find.text('Ignore Mask Area'));
    await tester.pumpAndSettle();
    expect(
      find.text('Top 96px remains interactive through the mask'),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(28, 28));
    await tester.pumpAndSettle();
    expect(find.text('SuperOverlay Showcase'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Control Lab'));
    await tester.tap(find.text('Open Control Lab'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ignore Mask Area'));
    await tester.tap(find.text('Ignore Mask Area'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 150));
    await tester.pumpAndSettle();
    expect(
      find.text('Top 96px remains interactive through the mask'),
      findsNothing,
    );
  });

  testWidgets('example demonstrates the SuperOverlay feature set', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SuperOverlay Showcase'), findsOneWidget);
    expect(find.text('super_overlay'), findsOneWidget);
    expect(find.text('Overlay features in one place'), findsNothing);
    expect(find.text('Custom Dialog'), findsOneWidget);
    expect(find.text('Instant Feedback'), findsOneWidget);
    expect(find.text('Anchored Menus'), findsOneWidget);
    expect(find.text('Guided Highlight'), findsOneWidget);
    expect(find.text('Lifecycle Binding'), findsOneWidget);
    expect(find.text('Network Request State'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Confirmation Dialog'));
    await tester.tap(find.text('Open Confirmation Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm this action?'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm this action?'), findsNothing);
    expect(find.text('handle.closed result: true'), findsOneWidget);

    await tester.ensureVisible(find.text('Run Toast Demo'));
    await tester.tap(find.text('Run Toast Demo'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Save result 3'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Stack'));
    await tester.tap(find.text('Stack'));
    await tester.tap(find.text('Run Toast Demo'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Background sync complete'), findsOneWidget);
    expect(find.text('Permission check passed'), findsOneWidget);
    expect(find.text('Cache warm-up complete'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Permission check passed')).dy,
      greaterThan(tester.getTopLeft(find.text('Background sync complete')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Cache warm-up complete')).dy,
      greaterThan(tester.getTopLeft(find.text('Permission check passed')).dy),
    );

    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    await tester.pumpAndSettle();

    final sortTrigger = find.byKey(const ValueKey('sort-menu-trigger'));
    await tester.ensureVisible(sortTrigger);
    await tester.tap(sortTrigger);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sort-menu-popup')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('sort-menu-popup'))).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(sortTrigger).dy),
    );

    await SuperOverlay.close(target: OverlayCloseTarget.allPopups);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Highlight Entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Guide'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1'), findsOneWidget);

    await tester.tap(find.text('Highlight Entry'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allPopups, force: true);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Open Lifecycle Demo'));
    await tester.tap(find.text('Open Lifecycle Demo'));
    await tester.pumpAndSettle();
    expect(find.text('Lifecycle Binding'), findsWidgets);

    await tester.tap(find.text('Show Route-bound Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Route-bound Dialog'), findsOneWidget);

    await tester.tap(find.text('Push Covering Route'));
    await tester.pumpAndSettle();
    expect(find.text('Covering Route'), findsOneWidget);
    expect(find.text('Route-bound Dialog'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Route-bound Dialog'), findsOneWidget);

    await SuperOverlay.close(
      target: OverlayCloseTarget.dialog,
      tag: 'route-bound',
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show Widget-bound Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Widget-bound Dialog'), findsOneWidget);

    await tester.tap(find.text('Remove Target Widget'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Widget-bound Dialog'), findsNothing);
    expect(find.text('Restore Target Widget'), findsOneWidget);
  });

  testWidgets(
    'network state demo shows request loading, empty page, error page, and image states',
    (tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.ensureVisible(find.text('Open Network State Demo'));
      await tester.tap(find.text('Open Network State Demo'));
      await tester.pumpAndSettle();

      expect(find.text('Network State Demo'), findsWidgets);
      expect(find.text('Load Data'), findsOneWidget);

      await tester.tap(find.text('Load Data'));
      await tester.pump();
      expect(find.text('Loading catalog...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('Load complete'), findsOneWidget);
      expect(find.text('Mountain Hiking Backpack'), findsOneWidget);
      expect(find.text('Image Loading'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Image Loaded'), findsWidgets);
      expect(find.text('Image Failed'), findsOneWidget);

      await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empty'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load Data'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('No items match the current filter.'), findsOneWidget);

      await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Failure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load Data'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('Load Failed'), findsOneWidget);
      expect(
        find.text(
          'The remote service is temporarily unavailable. Try again later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reload'), findsOneWidget);

      await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
      await tester.pumpAndSettle();
    },
  );
}
