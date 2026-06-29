import 'package:flutter/material.dart';

class SuperOverlayConfig {
  Color defaultMaskColor = Colors.black54;
  Duration defaultAnimationDuration = const Duration(milliseconds: 300);
  Duration defaultToastDuration = const Duration(seconds: 2);
  
  bool enableDebounce = true;
  Duration debounceDuration = const Duration(milliseconds: 300);
  
  WidgetBuilder defaultLoadingBuilder = (context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).dialogBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const CircularProgressIndicator(),
    );
  };
  
  Widget Function(BuildContext, String) defaultToastBuilder = (context, msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        msg,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  };
}
