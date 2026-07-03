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
              title: '全局请求反馈',
              subtitle: '请求中使用 overlay loading，结果用 toast 反馈。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<CatalogRequestMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<CatalogRequestMode>(
                        value: CatalogRequestMode.success,
                        label: Text('成功'),
                      ),
                      ButtonSegment<CatalogRequestMode>(
                        value: CatalogRequestMode.empty,
                        label: Text('空数据'),
                      ),
                      ButtonSegment<CatalogRequestMode>(
                        value: CatalogRequestMode.failure,
                        label: Text('失败'),
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
                    label: const Text('加载数据'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NetworkDemoSection(
              title: '页面内状态',
              subtitle: '缺省页和错误页留在业务页面内渲染，不进入 overlay API。',
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
        title: '等待加载',
        description: '选择一种请求结果后点击加载数据。',
      );
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return NetworkStateView(
        icon: Icons.wifi_off_outlined,
        title: '加载失败',
        description: errorMessage,
        actionLabel: '重新加载',
        onAction: _requesting ? null : _loadItems,
      );
    }

    if (_items.isEmpty) {
      return NetworkStateView(
        icon: Icons.search_off_outlined,
        title: '暂无数据',
        description: '当前筛选条件没有返回内容',
        actionLabel: '重新加载',
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

    unawaited(
      SuperOverlay.showLoading(msg: '加载商品列表...')
          .withLeastLoadingTime(const Duration(milliseconds: 500))
          .withBack(type: BackType.block)
          .fire<void>(),
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
      feedback = items.isEmpty ? '没有返回数据' : '加载完成';
    } on CatalogLoadFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loaded = true;
        _items = const [];
        _errorMessage = error.message;
      });
      feedback = '加载失败，请重试';
    } finally {
      await SuperOverlay.dismiss(status: DismissStatus.loading);
      if (mounted) {
        setState(() => _requesting = false);
      }
    }

    if (!mounted || feedback.isEmpty) {
      return;
    }

    unawaited(
      SuperOverlay.showToast(
        feedback,
      ).withDisplayType(ToastDisplayType.last).fire<void>(),
    );
  }
}
