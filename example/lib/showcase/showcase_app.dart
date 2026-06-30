import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import 'showcase_home_page.dart';
import 'showcase_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperOverlay Showcase',
      debugShowCheckedModeBanner: false,
      builder: SuperOverlayInit.init(
        toastBuilder: _toastBuilder,
        loadingBuilder: _loadingBuilder,
        notifyStyle: NotifyStyle(successBuilder: _successNotifyBuilder),
      ),
      navigatorObservers: [SuperOverlayInit.observer],
      theme: ShowcaseTheme.light(),
      home: const ShowcaseHomePage(),
    );
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

  Widget _successNotifyBuilder(String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6EE),
        border: Border.all(color: const Color(0xFF9CCC9C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Init Notify Style',
              style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12),
            ),
            Text(message, style: const TextStyle(color: Color(0xFF1F5F2A))),
          ],
        ),
      ),
    );
  }
}
