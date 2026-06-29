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
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SuperOverlay Demo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _showCustom,
                icon: const Icon(Icons.layers),
                label: const Text('Custom'),
              ),
              FilledButton.icon(
                onPressed: _showLoading,
                icon: const Icon(Icons.hourglass_top),
                label: const Text('Loading'),
              ),
              FilledButton.icon(
                onPressed: _showToast,
                icon: const Icon(Icons.sms),
                label: const Text('Toast'),
              ),
              Builder(
                builder: (targetContext) {
                  return FilledButton.icon(
                    onPressed: () => _showPopup(targetContext),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Popup'),
                  );
                },
              ),
              Builder(
                builder: (targetContext) {
                  return FilledButton.icon(
                    onPressed: () => _showHighlight(targetContext),
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Highlight'),
                  );
                },
              ),
              FilledButton.icon(
                onPressed: _showNotify,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Notify'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const RouteBindingPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.route),
                label: const Text('Route Binding'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const BackPage()),
                  );
                },
                icon: const Icon(Icons.keyboard_return),
                label: const Text('Back Handling'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustom() {
    SuperOverlay.show(
      builder: (_) => _OverlayPanel(
        title: 'Custom overlay',
        child: FilledButton(
          onPressed: () => SuperOverlay.dismiss(tag: 'custom-demo'),
          child: const Text('Close custom'),
        ),
      ),
    ).withTag('custom-demo').withMask(dismissible: true).fire<void>();
  }

  void _showLoading() {
    SuperOverlay.showLoading(
      msg: 'Loading data',
    ).withDisplayTime(const Duration(milliseconds: 700)).fire<void>();
  }

  void _showToast() {
    SuperOverlay.showToast(
      'Saved from toast',
    ).withDisplayTime(const Duration(seconds: 2)).fire<void>();
  }

  void _showPopup(BuildContext targetContext) {
    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const _PopupSurface(text: 'Popup menu'),
    ).withMask(dismissible: true).fire<void>();
  }

  void _showHighlight(BuildContext targetContext) {
    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const _PopupSurface(text: 'Highlighted target'),
    ).withHighlight().withMask(dismissible: true).fire<void>();
  }

  void _showNotify() {
    SuperOverlay.showNotify(
      msg: 'Notify message',
      type: NotifyType.success,
    ).withDisplayTime(const Duration(seconds: 2)).fire<void>();
  }
}

class RouteBindingPage extends StatelessWidget {
  const RouteBindingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route binding page')),
      body: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                SuperOverlay.show(
                  builder: (_) => const _OverlayPanel(
                    title: 'Bound to this page',
                    child: Text('Push another route to hide this overlay.'),
                  ),
                ).withTag('route-demo').bindPage().fire<void>();
              },
              icon: const Icon(Icons.link),
              label: const Text('Show bound overlay'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Covering route')),
                      body: const Center(child: Text('Covering route')),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.vertical_align_top),
              label: const Text('Cover route'),
            ),
          ],
        ),
      ),
    );
  }
}

class BackPage extends StatelessWidget {
  const BackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Back handling page')),
      body: Center(
        child: FilledButton.icon(
          onPressed: () {
            SuperOverlay.show(
              builder: (_) => const _OverlayPanel(
                title: 'Back is blocked',
                child: Text('Dismiss this overlay before leaving the page.'),
              ),
            ).withBack(type: BackType.block).fire<void>();
          },
          icon: const Icon(Icons.block),
          label: const Text('Show back-blocking overlay'),
        ),
      ),
    );
  }
}

class _OverlayPanel extends StatelessWidget {
  const _OverlayPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PopupSurface extends StatelessWidget {
  const _PopupSurface({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(text, style: TextStyle(color: colors.onInverseSurface)),
      ),
    );
  }
}
