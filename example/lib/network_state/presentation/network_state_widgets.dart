import 'dart:async';

import 'package:flutter/material.dart';

import '../../showcase/showcase_theme.dart';
import '../domain/catalog_item.dart';

class NetworkDemoSection extends StatelessWidget {
  const NetworkDemoSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ShowcaseColors.muted),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class NetworkStateView extends StatelessWidget {
  const NetworkStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: ShowcaseColors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: ShowcaseColors.muted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

enum ImageLoadState { loading, ready, failed }

class AsyncImageCard extends StatefulWidget {
  const AsyncImageCard({super.key, required this.item});

  final CatalogItem item;

  @override
  State<AsyncImageCard> createState() => _AsyncImageCardState();
}

class _AsyncImageCardState extends State<AsyncImageCard> {
  Timer? _timer;
  ImageLoadState _state = ImageLoadState.loading;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant AsyncImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _startLoad();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcaseColors.surfaceHigh,
        border: Border.all(color: ShowcaseColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              height: 104,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ShowcaseColors.codeSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: _buildImageState()),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _buildTextContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          widget.item.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: ShowcaseColors.muted),
        ),
        if (_state == ImageLoadState.failed) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _startLoad,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reload Image'),
          ),
        ],
      ],
    );
  }

  Widget _buildImageState() {
    return switch (_state) {
      ImageLoadState.loading => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: 8),
          Text('Image Loading', style: TextStyle(fontSize: 12)),
        ],
      ),
      ImageLoadState.ready => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, color: ShowcaseColors.primary),
          const SizedBox(height: 6),
          Text(widget.item.imageLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          const Text('Image Loaded', style: TextStyle(fontSize: 12)),
        ],
      ),
      ImageLoadState.failed => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: ShowcaseColors.danger),
          SizedBox(height: 6),
          Text('Image Failed', style: TextStyle(fontSize: 12)),
        ],
      ),
    };
  }

  void _startLoad() {
    _timer?.cancel();
    if (mounted) {
      setState(() => _state = ImageLoadState.loading);
    } else {
      _state = ImageLoadState.loading;
    }
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _state =
            widget.item.imageShouldFail
                ? ImageLoadState.failed
                : ImageLoadState.ready;
      });
    });
  }
}
