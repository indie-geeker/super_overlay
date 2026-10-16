import 'package:flutter/material.dart';

class ToastWidget extends StatelessWidget {
  const ToastWidget({super.key, required this.message});

  final String message;

  // Screen-edge spacing, excluded from spacing between stacked bubbles.
  static const outerMargin = EdgeInsets.symmetric(horizontal: 30, vertical: 50);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: outerMargin,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white)),
    );
  }
}
