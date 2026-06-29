import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperOverlay Demo',
      builder: SuperOverlayInit.init(),
      navigatorObservers: [SuperOverlayInit.observer],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SuperOverlay')),
      body: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: () {
                SuperOverlay.show(
                  builder: (_) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: const Text('Custom overlay'),
                  ),
                ).withTag('demo').fire<void>();
              },
              child: const Text('Show Overlay'),
            ),
            ElevatedButton(
              onPressed: () {
                SuperOverlay.dismiss(tag: 'demo');
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}
