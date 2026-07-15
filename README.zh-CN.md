# SuperOverlay

[English](README.md) | 简体中文

SuperOverlay 是一个面向 Flutter 应用级弹层的包，支持对话框、加载指示器、
Toast、目标挂载 Popup、高亮引导和通知。它使用自行管理的 `OverlayEntry` host，
提供类型化 handle、路由与 widget 生命周期归属、嵌套 Navigator 作用域、返回策略、
键盘/焦点行为和移动锚点跟踪，不会安装包自有的 navigator key。

## 安装

```yaml
dependencies:
  super_overlay: ^0.3.0
```

包要求 Dart `>=3.7.0 <4.0.0` 和 Flutter `>=3.29.0`。运行时依赖仅限
Flutter SDK；`go_router` 只作为开发期兼容性测试夹具。

## 根节点集成

在 `build` 外创建一个稳定的 `SuperOverlayIntegration`，然后把它配套的 builder
和根 observer 用于同一个 `MaterialApp`。应用根节点销毁时需要 dispose 该集成。

```dart
// snippet:root-integration:start
class RootOverlayApp extends StatefulWidget {
  const RootOverlayApp({super.key});

  @override
  State<RootOverlayApp> createState() => _RootOverlayAppState();
}

class _RootOverlayAppState extends State<RootOverlayApp> {
  late final SuperOverlayIntegration integration;

  @override
  void initState() {
    super.initState();
    integration = SuperOverlay.integration();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const AppHome(),
    );
  }

  @override
  void dispose() {
    integration.dispose();
    super.dispose();
  }
}
// snippet:root-integration:end
```

对于单个稳定根节点，`SuperOverlay.init()` 和 `SuperOverlay.observer` 仍可作为
紧凑的旧式配对。新的生产集成应优先使用上面的自有对象，因为 observer 的所有权
和释放过程更加明确。

### 原子根节点替换

替换整个 `MaterialApp` 时，给旧根和新根分别创建独立且稳定的集成，并把两组集成
保存在各自 `build` 方法之外。同一帧内发生替换重叠时，候选根会被冻结，直到旧根
脱离后再原子提升。现有 handle 仍绑定原 generation，不能修改新根。

不要把一个 observer 同时用于两个 Navigator，也不要让两个根在替换帧之后继续
同时挂载。一个 isolate 内存在两个活动 app host 属于不支持的冲突，而不是多租户模式。

## 嵌套 Navigator 集成

每个嵌套 Navigator 创建一个 scoped observer。它必须保存在 `build` 外，只挂到
一个 Navigator，并在该 Navigator 移除时 dispose。

```dart
// snippet:nested-navigator:start
class NestedCheckoutFlow extends StatefulWidget {
  const NestedCheckoutFlow({super.key, required this.integration});

  final SuperOverlayIntegration integration;

  @override
  State<NestedCheckoutFlow> createState() => _NestedCheckoutFlowState();
}

class _NestedCheckoutFlowState extends State<NestedCheckoutFlow> {
  late final SuperOverlayNavigatorObserver observer;

  @override
  void initState() {
    super.initState();
    observer = widget.integration.navigatorObserver();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      observers: [observer],
      onGenerateRoute:
          (_) => MaterialPageRoute<void>(builder: (_) => const CheckoutHome()),
    );
  }

  @override
  void dispose() {
    observer.dispose();
    super.dispose();
  }
}
// snippet:nested-navigator:end
```

调用 `SuperOverlay.of(context)` 时，context 必须位于拥有目标路由的 Navigator
之下。分支 Navigator 上方的 shell AppBar context 会解析到 shell 或根作用域，
而不是分支作用域。

```dart
final handle = SuperOverlay.of(context).dialog.show<bool>(
  builder: (_) => const ConfirmDeleteDialog(),
);
```

带路由归属的 scoped 对话框和 Popup 会在所属路由被覆盖时暂停，在路由重新成为
当前路由时恢复，并在 owner 路由或 observer 被移除时关闭。Toast、Loading 和通知
等路由中立表面仍归属于唯一的 app host。

## go_router ShellRoute

根 `GoRouter.observers` 接收根 observer；每个 `ShellRoute` 接收自己的 scoped
observer。

```dart
// snippet:shell-route:start
class ShellRouterOwner {
  ShellRouterOwner(this.integration);

  final SuperOverlayIntegration integration;
  late final SuperOverlayNavigatorObserver shellObserver =
      integration.navigatorObserver();
  late final GoRouter router = GoRouter(
    observers: [integration.observer],
    routes: [
      ShellRoute(
        observers: [shellObserver],
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const ShellHome()),
        ],
      ),
    ],
  );

  void dispose() {
    router.dispose();
    shellObserver.dispose();
  }
}
// snippet:shell-route:end
```

对于 `StatefulShellRoute.indexedStack`，每个分支都要创建不同的 observer，
分支命令应从该分支内部的后代 context 发起。

```dart
// snippet:stateful-shell-branches:start
class StatefulShellRouterOwner {
  StatefulShellRouterOwner(this.integration);

  final SuperOverlayIntegration integration;
  late final SuperOverlayNavigatorObserver firstBranchObserver =
      integration.navigatorObserver();
  late final SuperOverlayNavigatorObserver secondBranchObserver =
      integration.navigatorObserver();
  late final GoRouter router = GoRouter(
    observers: [integration.observer],
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                Scaffold(body: navigationShell),
        branches: [
          StatefulShellBranch(
            observers: [firstBranchObserver],
            routes: [
              GoRoute(
                path: '/first',
                builder: (context, state) => const FirstBranchHome(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [secondBranchObserver],
            routes: [
              GoRoute(
                path: '/second',
                builder: (context, state) => const SecondBranchHome(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  void dispose() {
    router.dispose();
    firstBranchObserver.dispose();
    secondBranchObserver.dispose();
  }
}
// snippet:stateful-shell-branches:end
```

默认 indexed-stack 容器会提供 Navigator 级 `TickerMode`，因此非活动分支的
Overlay 会释放命中测试、语义、焦点和返回优先级。自定义 stateful-shell 容器必须
提供同样的“恰好一个活动 Navigator”信号。

## 命令与 Handle 基础

对于非空 tag，`OverlayStrategy.stack` 总是创建新条目；`keepExisting` 返回同一
surface、同一 tag 的现有 handle；`replaceExisting` 会先关闭同一 surface、同一
tag 的全部匹配项，再显示替代项。空 tag 不属于任何冲突组。

当调用流程拥有 Overlay 生命周期时，应保留返回的 handle：

```dart
final loading = SuperOverlay.loading.show(message: 'Syncing profile...');
try {
  await syncProfile();
  SuperOverlay.toast(
    'Saved',
    options: const OverlayToastOptions(
      displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
    ),
  );
} finally {
  await loading.close();
}
```

对话框和 Popup 通过 `closed` 返回类型化结果：

```dart
late final OverlayHandle<bool> handle;
handle = SuperOverlay.dialog.show<bool>(
  builder: (_) => ConfirmDeleteDialog(
    onDecision: (confirmed) => handle.close(confirmed),
  ),
  options: const OverlayDialogOptions(
    tag: 'delete-confirmation',
    strategy: OverlayStrategy.replaceExisting,
  ),
);

final confirmed = await handle.closed;
```

对于有明确 owner 的内容，优先使用 `handle.close()`。应用关闭、测试或无法获取
handle 的内容，可使用类型化全局清理：

```dart
await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
await SuperOverlay.close(
  target: OverlayCloseTarget.allDialogs,
  tag: 'checkout',
  force: true,
);
```

## 返回、焦点与语义

`OverlayBackBehavior.dismiss` 关闭优先级最高且消费返回事件的 Overlay；`block`
保持可见并阻止路由返回；`passThrough` 把返回事件交给应用。Android predictive
back 通过与 `PopScope` 相同的 `ModalRoute` `PopEntry` 协议协调。

在键盘平台上，Escape 是焦点局部行为：只有键盘焦点位于 Overlay 内部时，才使用
同一个 Overlay 策略。`requestFocus` 只控制初始焦点捕获；当它为 `false` 时，
页面最初保留焦点，因此在焦点进入 Overlay 前，Escape 仍由页面处理。SuperOverlay
不会安装 host 级键盘分发器。

Flutter 会在一次 pop 失败后通知每个 `PopEntry`。因此当 SuperOverlay 阻止路由
返回时，应用的 `PopScope` 或 `Form` 回调也可能收到 `didPop == false`。失败回调
应保持幂等，并在 `didPop` 为 true 前避免破坏性副作用。

Modal 对话框和 Loading 默认捕获焦点，使用闭环焦点作用域，阻止背景语义，暴露
语义路由，并尽可能恢复先前焦点。`semanticsLabel` 标记 Overlay 语义容器，并作为
Modal 对话框的路由标签。周围内容无法说明用途时请显式提供标签：

```dart
const OverlayDialogOptions(
  requestFocus: true,
  semanticsLabel: 'Delete confirmation',
  barrierSemanticsLabel: 'Dismiss delete confirmation',
);
```

`consumeEvents: false` 的对话框在指针输入和语义上都属于非 Modal：底层页面保持
可交互、可发现，焦点遍历也不会被限制在 Overlay 内。`requestFocus` 仍只控制
初始焦点；若页面需要保留键盘焦点，应设为 `false`。由于非 Modal 遍历不封闭，
焦点可以回到页面，此时 Escape 也继续由页面处理。

Popup 默认采用非 Modal 焦点。Toast 和通知属于 live region，不抢占焦点。应用
仍需自行给按钮、输入框和自定义控件提供语义标签。

消费返回行为（`dismiss` 或 `block`）需要已被观察的 `ModalRoute`。自定义非
`ModalRoute` 路由或绕过 Navigator 的 dispatcher 不具备这一保证；这些场景应
使用 `passThrough` 或路由中立的表面。

## 移动锚点 Popup

挂载型 Popup 会在已 mounted 的 `targetContext` 发生滚动、布局和 transform
变化后继续跟随。运行时把目标转换到根 Overlay 的本地坐标系，仅当移动超过 0.5
逻辑像素时刷新该 Popup。布局、高亮挖孔和高亮命中测试共享同一个不可变矩形快照。

```dart
SuperOverlay.popup.show<void>(
  targetContext: buttonContext,
  builder: (_) => const FilterMenu(),
  options: const OverlayPopupOptions(
    tag: 'filter-menu',
    alignment: Alignment.bottomCenter,
    strategy: OverlayStrategy.replaceExisting,
  ),
);
```

未挂载或几何无效的目标会 fail closed，并移除其注册记录。
在 Overlay 视口任一边缘部分裁剪仍然有效并继续跟踪；
当已挂载目标与 Overlay 视口不再存在正面积交集时，
目标会被视为不可用并 fail closed。`maskIgnoreArea` 不同：它固定在 Overlay host
坐标中，不随目标移动。

## 刷新契约

`OverlayToastDisplayPolicy.refreshActive` 会在策略拥有的刷新 lane 中启动一个新
Toast 命令，或替换该 lane 的内容。它不是 handle 的内容刷新。

`handle.refresh()` 只重建该现有 handle 拥有的内容。它适合更新进度或可变展示
状态，不会启动另一个命令。可运行示例并排展示了这两类行为。

## Handle 生命周期

`OverlayHandle.visible` 在首次渲染帧后完成。如果命令被拒绝或在渲染前关闭，它会
以 `StateError` 失败，包括 Popup 目标无效或路由在首次绘制前移除。特意设计的
例外是 `OverlayHandle.detached()`：它表示无操作 owner，`visible` 立即完成且永远
不可见。

`OverlayHandle.closed` 只结算一次并带可选结果。重复 `close()` 调用共享同一个
关闭 future。暂停的路由归属 Overlay 在恢复前会报告 `isVisible == false`。

## 支持的拓扑与平台

SuperOverlay 在每个 isolate 中支持一个活动根 host。下表记录发布策略；设备证据
状态维护在[设备验证矩阵](tool/verification/example_device_matrix.md)中。

| 平台 | 等级 | 发布要求 |
| --- | --- | --- |
| Android | 支持 | 自动化门禁通过，并在发布前记录 edge-to-edge/挖孔真机证据 |
| iOS | 支持 | 自动化门禁通过，并在发布前记录刘海/Dynamic Island 真机证据 |
| Web | 支持 | CI 中运行完整 example 测试和 `flutter build web` |
| macOS | 尽力支持 | 单窗口行为；只有记录构建和人工结果后才能在该版本中声明支持 |
| Windows | 尽力支持 | 单窗口行为；只有记录构建和人工结果后才能在该版本中声明支持 |
| Linux | 尽力支持 | 单窗口行为；只有记录构建和人工结果后才能在该版本中声明支持 |

支持的导航拓扑包括单个稳定 MaterialApp、同帧原子完整根替换、普通嵌套
Navigator、`ShellRoute` 和默认 `StatefulShellRoute.indexedStack` 容器。

明确限制：

- 一个 isolate 内同时存在多个活动 `MaterialApp` host 会 fail fast；
- 让新旧 host 跨多帧同时挂载的根切换不受支持；
- 一个 isolate/view registry 内的桌面多窗口路由不受支持；
- 缺少 Navigator 级 `TickerMode` 的自定义 stateful-shell 容器无法可靠提供分支活动状态；
- 非 `ModalRoute` 上的消费型返回行为不受支持；
- 每个版本都必须记录真实设备的挖孔和键盘证据；
- 桌面声明仅为单窗口尽力支持，除非该版本记录了构建和人工结果。

## 示例、验证与维护

[示例应用](example/README.md)演示类型化对话框结果、`dismiss`/`block`/
`passThrough`、嵌套 Navigator 暂停与清理、移动锚点，以及 `refreshActive` 与
`handle.refresh()` 的区别。

可追踪性记录在[示例覆盖矩阵](tool/verification/example_coverage_matrix.md)中。
贡献者门禁见 [CONTRIBUTING.md](CONTRIBUTING.md)，发布清单见
[RELEASE.md](RELEASE.md)，漏洞报告策略见 [SECURITY.md](SECURITY.md)。

## 许可证

SuperOverlay 使用 MIT 许可证，详见 [LICENSE](LICENSE)。
