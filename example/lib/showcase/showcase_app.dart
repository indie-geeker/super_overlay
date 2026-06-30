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
      builder: SuperOverlayInit.init(),
      navigatorObservers: [SuperOverlayInit.observer],
      theme: ShowcaseTheme.light(),
      home: const ShowcaseHomePage(),
    );
  }
}
