# SuperOverlay

[English](README.md) | 简体中文

SuperOverlay 是一个面向 Flutter 应用级弹层的包，支持对话框、加载指示器、
Toast、目标挂载 Popup、高亮引导和通知。它使用自行管理的 `OverlayEntry` host，
提供类型化 handle、路由与 widget 生命周期归属、嵌套 Navigator 作用域、返回策略、
键盘/焦点行为和移动锚点跟踪，不会安装包自有的 navigator key。

## 安装

本文描述 **0.4.0 API**，添加以下 pub.dev 依赖：

```yaml
dependencies:
  super_overlay: ^0.4.0
```

本地开发时，使用路径依赖：

```yaml
dependencies:
  super_overlay:
    path: ../super_overlay
```

包要求 Dart `>=3.7.0 <4.0.0` 和 Flutter `>=3.29.0`。运行时依赖仅限
Flutter SDK；`go_router` 只作为开发期兼容性测试夹具。

## 从 0.3.1 迁移

0.4.0 包含不兼容的 API 调整，升级依赖时请同步修改以下调用：

| 0.3.1 | 0.4.0 |
| --- | --- |
| Dialog/Popup 的 `builder(context)` | 改为 `builder(context, overlay)`，在内容中使用 `overlay.close(result)` 关闭 |
| `OverlayCloseTarget.topMost` | 改为 `OverlayCloseTarget.highestPriority`，仍按类别优先级选择，与视觉叠放顺序无关 |
| scoped 的 `loading`、`notify`、`toast`、`close`、`exists` | 改为全局 `SuperOverlay` 的同名成员；scoped facade 只保留 Dialog/Popup |

原有手动 `loading.show()` / `handle.close()` 方式仍可使用；新增的
`SuperOverlay.loading.run(task)` 可自动清理对应 Loading。

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
  late final integration = SuperOverlay.integration();

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

## 命令与 Handle 基础

普通调用无需配置 options。页面中的 Dialog 和 Popup 使用 `SuperOverlay.of(context)`；
Loading、Toast、通知使用全局 `SuperOverlay`。scoped facade 只提供 Dialog 和 Popup。

| 需求 | 入口 | 默认行为 |
| --- | --- | --- |
| 提示 | `SuperOverlay.toast('Saved')` | 排队，2 秒后关闭 |
| 通知 | `SuperOverlay.notify.success('Saved')` | 2.5 秒后关闭，不抢焦点 |
| 执行任务 | `SuperOverlay.loading.run(task)` | 返回任务结果，成功或失败均关闭本次 Loading |
| 对话框 | `SuperOverlay.of(context).dialog.show<T>(...)` | 绑定当前路由，点击遮罩或返回关闭 |
| 锚点菜单 | `SuperOverlay.of(context).popup.show<T>(...)` | 跟踪目标，目标失效后关闭 |

内容 builder 接收 `(context, overlay)`，直接使用 `overlay.close(result)`，无需
预先声明 `late final handle`。下面展示完整的确认、执行、反馈流程：

```dart
// snippet:quick-commands:start
Future<bool?> confirmAndSync(
  BuildContext context,
  Future<void> Function() syncProfile,
) async {
  final confirmed =
      await SuperOverlay.of(context).dialog
          .show<bool>(
            builder:
                (_, dialog) => AlertDialog(
                  title: const Text('Sync profile?'),
                  actions: [
                    TextButton(
                      onPressed: () => dialog.close(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => dialog.close(true),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
          )
          .closed;
  if (confirmed == true) {
    await SuperOverlay.loading.run(syncProfile, message: 'Syncing profile...');
    SuperOverlay.toast('Saved');
  }
  return confirmed;
}
// snippet:quick-commands:end
```

需要手动控制时，使用 `loading.show()` 保存句柄，并在 `finally` 中执行
`await handle.close()`。Loading 只有一个活动显示位置；并发 `show` 或 `run`
由最新调用显示，旧任务结束不会关闭新 Loading。任务会独立继续运行；返回、关闭
或宿主销毁都不会取消业务任务。

句柄操作按本次调用的独立身份匹配，包括等待最短显示时长和延迟显示的替换请求。
业务 tag 重名不会让旧句柄拥有新 Loading；全局按 tag 查询和关闭仍然可用。
返回事件同样只归属于分发时选中的 Loading，旧返回回调不能关闭替换实例。
关闭期间再次返回只等待原关闭，不会取消等待显示的替换请求；显式全局清理仍可
取消匹配的待显示请求。

遮罩回调同样只归属于渲染该遮罩的实例。替换或关闭过程中点击旧遮罩，不会关闭新
实例，也不会取消等待显示的 Loading。延迟执行的 Popup 目标失效回调只关闭安排
该回调的 Popup，即使 tag 重名也不会误关其他实例。
自动到期和路由、组件失效清理也只关闭原实例，不会重新按全局 tag 查找目标。
显式全局按 tag 清理仍保留原有匹配规则。

`minimumVisibleDuration` 从 Loading 的首次渲染帧之后开始计算。设为正值时，
首帧前请求关闭也会等待首帧及最短显示时长；每次替换独立计时，宿主销毁则立即结算
待关闭任务。`displayDuration` 在本次 Loading 激活显示时安排关闭，早于首帧，
仍受最短可见时长约束。

`tag` 仅在去重、替换或全局查找时需要。同一 app host、同一 surface、同一非空
tag 构成冲突组，包括不同路由的调用。`stack` 新建条目，`keepExisting` 保留原内容，
`replaceExisting` 先关闭全部匹配项再展示新内容。空 tag 不属于冲突组。

优先用句柄关闭所属弹层；全局清理使用明确的 target：

```dart
await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
await SuperOverlay.close(target: OverlayCloseTarget.allDialogs, tag: 'checkout');
```

批量关闭会等待匹配的活动弹层及已经开始的关闭任务完成，包括关闭动画；不会覆盖
已有关闭结果，也不会等待其他 tag。`all` 会先启动全部 surface 的清理，再等待完成；
调用后新建的弹层不属于这次快照。未指定 tag 清空全部 Toast 时，队列和内容立即移除。
`highestPriority` 按 Loading → 通知 →
Dialog/Popup → Toast 选择一个目标，独立于视觉叠放顺序。全局关闭也能清理暂停的弹层。

## Handle 生命周期

`OverlayHandle.visible` 在首次渲染帧后完成。如果命令被拒绝或在渲染前关闭，它会
以 `StateError` 失败，包括 Popup 目标无效或路由在首次绘制前移除。特意设计的
例外是 `OverlayHandle.detached()`：它表示无操作 owner，`visible` 立即完成且永远
不可见。

`OverlayHandle.closed` 只结算一次并带可选结果。重复 `close()` 调用共享同一个
关闭 future。暂停的路由归属 Overlay 在恢复前会报告 `isVisible == false`。
若首次可见确认前发生暂停，`visible` 会等待恢复后的渲染帧；恢复前关闭仍会使其失败。
命令创建的句柄会在关闭后释放内容 builder；保留已关闭句柄不会继续持有已销毁的
内容。可选的关闭结果仍可从 `closed` 获取。
合法创建的路由归属 Dialog 或 Popup 在 `replaceExisting` 等待期间失去所属路由或
observer 时，会取消待显示命令：`visible` 失败，`closed` 正常完成，内容不会显示。
初次调用时 owner 已无效，仍立即抛出错误。
Dialog 设置 `bindToWidget` 时，会在替换清理前和实际激活前检查组件是否仍挂载。
挂载型 Popup 对 `targetContext` 做同样检查。组件已卸载则取消待显示命令，不执行
内容 builder：`visible` 以 `StateError` 失败，`closed` 正常完成，并保留已经提交的
关闭结果。替换清理前取消会保留已有弹层，已经开始的关闭不会撤销。
Popup 仍独立执行几何有效性检查。

## 返回、焦点与语义

`OverlayBackBehavior.dismiss` 关闭优先级最高且消费返回事件的 Overlay；`block`
保持可见并阻止路由返回；`passThrough` 跳过本层并继续检查下层，
全部穿透时才把返回事件交给应用。正在关闭的消费型弹层会阻止重复返回，直到关闭结算。Android predictive
back 通过与 `PopScope` 相同的 `ModalRoute` `PopEntry` 协议协调。

在键盘平台上，Escape 是焦点局部行为：只有键盘焦点位于 Overlay 内部时，才使用
同一个 Overlay 策略。`requestFocus` 只控制初始焦点捕获；当它为 `false` 时，
页面最初保留焦点，因此在焦点进入 Overlay 前，Escape 仍由页面处理。SuperOverlay
不会安装 host 级键盘分发器。
焦点内容优先处理 Escape：输入框选择工具栏显示时，第一次按键只收起工具栏，
未处理的 Escape 会回退到 Overlay 策略，内容动作被禁用时也如此。内容已处理按键
或停止传播时，保留 Flutter 对应的行为。
Flutter 输入框派发 `DismissIntent` 且没有 Overlay 消费返回时，会转交应用提供的
`Actions` 处理器；未配置处理器时安全地不执行操作。

应用 `ContextAction` 使用实际调用上下文判断启用状态并执行；快捷键调用时使用
当前焦点上下文，并经过该上下文的 `ActionDispatcher`。直接调用 `Actions.invoke`
会保留应用处理器的原始返回值。应用动作返回的按键语义会
保留：`ignored` 继续传播到外层快捷键，`handled` 和 `skipRemainingHandlers` 按
Flutter 规则停止快捷键传播。其他祖先快捷键映射可能再次派发同一未处理按键；
SuperOverlay 不会在同一个快捷键边界额外重复执行回退动作。
自定义分发器可以拦截动作、改写返回值，或在返回前触发其他动作，也支持原生子级
`Shortcuts`。快捷键选中 Overlay 桥接动作时，只要本次分发中实际消费过返回事件，
Escape 就会被处理，包括分发器改写返回值、在委托前或委托后重入的情况。
否则由应用动作转换分发器最终返回的值，嵌套应用调用的返回值不会替换它。
如果自定义分发器完全拦截、没有调用桥接动作，即使存在 `block` 或 `dismiss`
弹层，也由应用动作转换最终值；没有应用动作时使用 Flutter 默认按键消费行为。
各快捷键边界和后续按键使用独立状态；程序化调用仍保留原始返回值。

部分 Flutter 内容在菜单关闭时仍会消费 Escape，例如已验证 SDK 上获得输入焦点的
`DropdownMenu`，以及 Flutter 3.29 中包裹 `TextField` 的已关闭 `MenuAnchor`。
Flutter 原生对话框也有同样行为。SuperOverlay 保留这些内容动作；使用这些组合时
应提供明确的关闭按钮。

Flutter 会在一次 pop 失败后通知每个 `PopEntry`。因此当 SuperOverlay 阻止路由
返回时，应用的 `PopScope` 或 `Form` 回调也可能收到 `didPop == false`。失败回调
应保持幂等，并在 `didPop` 为 true 前避免破坏性副作用。

Modal 对话框和 Loading 默认捕获焦点，使用闭环焦点作用域，阻止背景语义，暴露
语义路由，并尽可能恢复先前焦点。`semanticsLabel` 标记 Overlay 语义容器，并作为
Modal 对话框和 Loading 的路由名称。非空显式标签优先于 AlertDialog 等内容的
名称；未提供时允许内容自身提供路由名称。周围内容无法说明用途时请显式提供标签：

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
  builder: (_, popup) => const FilterMenu(),
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

Popup 内容受 host 安全区和当前键盘区域约束。请求方向空间不足且反方向放得下时，
默认定位会翻转；`adjustmentBuilder` 返回的 alignment 优先于自动翻转，但最终位置
仍限制在可用区域内。长内容应自行使用可滚动组件，保证所有操作在有限高度下仍可访问。
锚点和高亮坐标仍使用 host 坐标系。

Toast 会响应键盘打开、高度变化和收起；收起后不会残留偏移。顶部反馈在未被键盘
遮挡时保持原位置。

## 刷新契约

`OverlayToastDisplayPolicy.refreshActive` 会在策略拥有的刷新 lane 中启动一个新
Toast 命令，或替换该 lane 的内容。它不是 handle 的内容刷新。

只有最新请求拥有该 lane 的内容和 tag。被替换的 builder 及其捕获值会释放，历史
句柄的 `closed` 仍等待整个 lane 关闭。关闭或刷新旧句柄不会影响最新请求。
持续刷新时，未保留的历史请求不会累积生命周期对象或关闭监听器。保留的句柄和
显式关闭观察者仍跟踪各自请求的生命周期。历史 `closed` 即使在 lane 关闭后首次
读取，也会正确完成。

`handle.refresh()` 只重建该现有 handle 拥有的内容，适用于 Dialog、Popup、
Loading、通知和 Toast。它适合更新进度或可变展示
状态，不会启动另一个命令。刷新会再次调用全局 `NotifyStyle` 工厂；本次显式
builder 优先，且不会执行未选中的全局工厂。可运行示例并排展示了这两类行为。

需要常驻通知时，设置 `OverlayNotifyOptions(displayDuration: null)`。
省略该选项仍使用 2500 毫秒默认值；显式传入 null 会禁用自动关闭。

## 原子根节点替换

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
  builder: (_, dialog) => const ConfirmDeleteDialog(),
);
```

带路由归属的 scoped 对话框和 Popup 会在所属路由被覆盖时暂停，在路由重新成为
当前路由时恢复，并在 owner 路由或 observer 被移除时关闭。组件绑定的 Overlay
在目标卸载后关闭，包括路由暂停期间。Toast、Loading 和通知
等路由中立表面仍归属于唯一的 app host。

暂停会保留已经展示过的内容状态，包括表单输入和滚动位置，同时停用命中测试、
语义、键盘焦点和 ticker。首次展示前就被暂停的内容，仍会等到路由重新激活后才构建。

暂停不会自动暂停业务 `Timer` 或 Stream 订阅，内容应在 `dispose` 中自行释放。
[刷新与资源生命周期示例](example/lib/refresh_lifecycle_main.dart) 展示了该边界、
全局通知样式刷新和显式 builder 优先级。自定义 dialog 内容还负责键盘避让：
可以使用 `AlertDialog`，或响应 `MediaQuery.viewInsets` 并提供合适的滚动/布局约束。

`SuperOverlay.of(context)` 会在创建 facade 时捕获局部 `InheritedTheme`，包括
Popup 的替换内容和调整内容。局部主题变化后应重新获取 facade。页面局部 Provider、
本地化覆盖等其他继承状态不会自动捕获，应显式传入所需值或自行包装内容。
内容 builder 位于根 host 中，关闭应使用 builder 收到的所属 handle；导航应使用应用持有的 context
或 Navigator key。
builder context 不含 Navigator 祖先。`DropdownButton` 等内部需要 push 路由的控件，
必须在自己的子树中显式提供 Navigator；根 host 中的菜单也可使用
`SuperOverlay.popup` 或 `MenuAnchor`，无需添加 Navigator。

在 owner 页面中先读取 Provider 值和本地化文本，再调用下面的 helper。示例显式
传入文本，并用已捕获的 locale 包装内容。如果依赖页面局部自定义本地化 delegate，
还应通过 `Localizations.override(delegates: ...)` 显式传递。捕获值是快照；值变化后
应重新读取，并获取新的 facade。

```dart
// snippet:explicit-local-values:start
OverlayHandle<void> showLocalizedConfirmation(
  BuildContext owner,
  String confirmationText,
) {
  final locale = Localizations.localeOf(owner);
  return SuperOverlay.of(owner).dialog.show<void>(
    builder:
        (overlayContext, _) => Localizations.override(
          context: overlayContext,
          locale: locale,
          child: AlertDialog(content: Text(confirmationText)),
        ),
  );
}
// snippet:explicit-local-values:end
```

## go_router ShellRoute

已在本地验证：Flutter 3.29.0 + go_router 14.8.1，以及 Flutter 3.47.4 +
go_router 14.8.1 / 18.0.2。较新组合由
[独立兼容性夹具](tool/compatibility/go_router_18/README.md) 检查。go_router 18
默认将 Shell 事件转发给根 observer；SuperOverlay 按 Navigator 归属过滤。每个
Shell/分支仍须独立 scoped observer。这些组合是测试证据，不代表所有路由版本
或设备均已验证。

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
