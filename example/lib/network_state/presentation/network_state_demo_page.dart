import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

import '../data/fake_catalog_remote_data_source.dart';
import '../domain/catalog_item.dart';
import '../domain/load_catalog_items.dart';
import 'network_state_widgets.dart';

class NetworkStateDemoPage extends StatefulWidget {
  const NetworkStateDemoPage({super.key});

  @override
  State<NetworkStateDemoPage> createState() => _NetworkStateDemoPageState();
}

class _NetworkStateDemoPageState extends State<NetworkStateDemoPage> {
  late final LoadCatalogItems _loadCatalogItems;

  CatalogRequestMode _mode = CatalogRequestMode.success;
  List<CatalogItem> _items = const [];
  String? _errorMessage;
  bool _loaded = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogItems = const LoadCatalogItems(
      CatalogRepositoryImpl(FakeCatalogRemoteDataSource()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network State Demo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            NetworkDemoSection(
              title: 'Global Request Feedback',
              subtitle:
                  'Use an overlay loading state during the request, then report the result with a Toast.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<CatalogRequestMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<CatalogRequestMode>(
                        value: CatalogRequestMode.success,
                        label: Text('Success'),
                      ),
                      ButtonSegment<CatalogRequestMode>(
                        value: CatalogRequestMode.empty,
                        label: Text('Empty'),
                      ),
                      ButtonSegment<CatalogRequestMode>(
                        value: CatalogRequestMode.failure,
                        label: Text('Failure'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged:
                        _requesting
                            ? null
                            : (values) => setState(() => _mode = values.first),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _requesting ? null : _loadItems,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Load Data'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NetworkDemoSection(
              title: 'Page-owned States',
              subtitle:
                  'Empty and error states stay in the page instead of entering the overlay API.',
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_loaded) {
      return const NetworkStateView(
        icon: Icons.inbox_outlined,
        title: 'Waiting to Load',
        description: 'Choose a request result, then load the data.',
      );
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return NetworkStateView(
        icon: Icons.wifi_off_outlined,
        title: 'Load Failed',
        description: errorMessage,
        actionLabel: 'Reload',
        onAction: _requesting ? null : _loadItems,
      );
    }

    if (_items.isEmpty) {
      return NetworkStateView(
        icon: Icons.search_off_outlined,
        title: 'No Data',
        description: 'No items match the current filter.',
        actionLabel: 'Reload',
        onAction: _requesting ? null : _loadItems,
      );
    }

    return Column(
      children: [
        for (final item in _items) ...[
          AsyncImageCard(item: item),
          if (item != _items.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _loadItems() async {
    if (_requesting) {
      return;
    }

    setState(() {
      _requesting = true;
      _errorMessage = null;
    });

    final loading = SuperOverlay.loading.show(
      message: 'Loading catalog...',
      options: const OverlayLoadingOptions(
        minimumVisibleDuration: Duration(milliseconds: 500),
        backBehavior: OverlayBackBehavior.block,
      ),
    );

    var feedback = '';
    try {
      final items = await _loadCatalogItems(_mode);
      if (!mounted) {
        return;
      }
      setState(() {
        _loaded = true;
        _items = items;
      });
      feedback = items.isEmpty ? 'No data returned' : 'Load complete';
    } on CatalogLoadFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loaded = true;
        _items = const [];
        _errorMessage = error.message;
      });
      feedback = 'Load failed. Try again.';
    } finally {
      await loading.close();
      if (mounted) {
        setState(() => _requesting = false);
      }
    }

    if (!mounted || feedback.isEmpty) {
      return;
    }

    SuperOverlay.toast(
      feedback,
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
      ),
    );
  }
}
