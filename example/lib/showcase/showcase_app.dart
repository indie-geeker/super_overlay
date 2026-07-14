import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_home_page.dart';
import 'showcase_theme.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SuperOverlayIntegration _integration;

  @override
  void initState() {
    super.initState();
    _integration = SuperOverlay.integration(
      toastBuilder: _toastBuilder,
      loadingBuilder: _loadingBuilder,
      notifyStyle: NotifyStyle(
        successBuilder:
            (message) =>
                _notifyBuilder(OverlayNotificationType.success, message),
        failureBuilder:
            (message) =>
                _notifyBuilder(OverlayNotificationType.failure, message),
        warningBuilder:
            (message) =>
                _notifyBuilder(OverlayNotificationType.warning, message),
        errorBuilder:
            (message) => _notifyBuilder(OverlayNotificationType.error, message),
        alertBuilder:
            (message) => _notifyBuilder(OverlayNotificationType.alert, message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperOverlay Showcase',
      debugShowCheckedModeBanner: false,
      builder: _integration.builder,
      navigatorObservers: [_integration.observer],
      theme: ShowcaseTheme.light(),
      home: ShowcaseHomePage(integration: _integration),
    );
  }

  @override
  void dispose() {
    _integration.dispose();
    super.dispose();
  }

  Widget _toastBuilder(String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Init Toast Style',
              style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12),
            ),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _loadingBuilder(String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Init Loading Style',
                  style: TextStyle(color: Color(0xFF2563EB), fontSize: 12),
                ),
                Text(message.isEmpty ? 'Loading...' : message),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifyBuilder(OverlayNotificationType type, String message) {
    final colors = switch (type) {
      OverlayNotificationType.success => (
        const Color(0xFFEFF6EE),
        const Color(0xFF2E7D32),
      ),
      OverlayNotificationType.failure => (
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
      ),
      OverlayNotificationType.warning => (
        const Color(0xFFFFF7ED),
        const Color(0xFFB45309),
      ),
      OverlayNotificationType.error => (
        const Color(0xFFFFF1F2),
        const Color(0xFFBE123C),
      ),
      OverlayNotificationType.alert => (
        const Color(0xFFF5F3FF),
        const Color(0xFF7C3AED),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        key: ValueKey('init-notify-${type.name}'),
        decoration: BoxDecoration(
          color: colors.$1,
          border: Border.all(color: colors.$2.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(message, style: TextStyle(color: colors.$2)),
        ),
      ),
    );
  }
}
