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
      title: 'Super Overlay Advanced Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      navigatorKey: SuperOverlay.navigatorKey,
      home: const MyHomePage(title: 'Super Overlay Advanced Features'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _spamCount = 0;
  int _targetClicks = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // --- Debounce ---
            const Text('1. Debounce (Anti-spam)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() => _spamCount++);
                SuperOverlay.show(
                  content: Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Text('Dialog opened from click #$_spamCount\n(Notice you only see one dialog even if you spam click!)'),
                  ),
                ).withDebounce(true).fire();
              },
              child: Text('Spam Click Me (Clicked $_spamCount times)'),
            ),
            const Divider(height: 40),

            // --- Tags ---
            const Text('2. Tags (Precise Dismissal)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      SuperOverlay.show(
                        content: Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.amber,
                          child: const Text('I am tagged as "myDialog".\nI cannot be closed by tapping the mask!'),
                        ),
                      )
                      .withTag('myDialog')
                      .withMask(dismissible: false) // force programmatic dismiss
                      .fire();
                    },
                    child: const Text('Show Tagged Dialog'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    onPressed: () {
                      SuperOverlay.dismiss(tag: 'myDialog');
                    },
                    child: const Text('Close Tagged Dialog'),
                  ),
                ),
              ],
            ),
            const Divider(height: 40),

            // --- Highlight Mask ---
            const Text('3. Highlight Mask (Hole-punching)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Builder(
              builder: (highlightContext) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() => _targetClicks++);
                    if (_targetClicks == 1) {
                      // Show tutorial mask on first click
                      SuperOverlay.show(
                        content: const Padding(
                          padding: EdgeInsets.only(top: 100),
                          child: Text('Click the highlighted button again!', style: TextStyle(color: Colors.white, fontSize: 24)),
                        )
                      )
                      .withAlignment(Alignment.topCenter)
                      .withHighlight(
                        highlightContext, 
                        padding: const EdgeInsets.all(8),
                        borderRadius: BorderRadius.circular(8),
                      )
                      .fire();
                    } else {
                      // The user clicked through the hole!
                      SuperOverlay.showToast(msg: 'You clicked through the mask!').fire();
                      // We must manually dismiss the mask if we want it to go away after success
                      SuperOverlay.dismiss(); 
                      setState(() => _targetClicks = 0);
                    }
                  },
                  child: Text('Target Button (Clicks: $_targetClicks)'),
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}
