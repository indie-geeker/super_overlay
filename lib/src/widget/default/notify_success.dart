import 'package:flutter/material.dart';

class NotifySuccess extends StatelessWidget {
  const NotifySuccess({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _NotifyBox(message: message, color: Colors.green);
  }
}

class _NotifyBox extends StatelessWidget {
  const _NotifyBox({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white)),
    );
  }
}
