# Overlay 运行时职责与状态约束

本说明记录单活动 root host 的状态、返回分发与关闭结算约束。

## 所有者

| 所有者 | 持有的状态 | 负责的行为 |
| --- | --- | --- |
| `OverlayManager` | host/generation、候选 host、dialog/notify 队列、in-flight 集合、display timer、上次锚点矩形 | 命令归属、宿主交接、呈现/暂停、返回优先级、最终资源清理 |
| `NavigatorScopeRegistry` | Navigator scope、route snapshot、observer 绑定、route PopEntry | 精确路由归属与路由活动状态；不拥有弹层关闭动画 |
| `OverlayAnchorGeometry` | 无持久状态 | 安全读取 RenderBox、host 坐标转换、矩形有效性/视口交集、移动量计算；不决定关闭或注册 observer |
| `OverlayDismissalOperation` | 一次 dismissal 的 future、启动标记、一次 cleanup claim | 合并重复 close、驱动异步 dismiss 与 cleanup、保留首个异常、允许 host teardown 提前结算 |
| 内容 State | 输入/滚动状态、业务 Timer/Stream | 自行释放业务资源；路由暂停不自动暂停 Timer/Stream |
| API services | 每个命令的 options、controller 和 handle | 直接生成 ShowParam；内容 builder 接收所属 typed handle；不持有路由 registry 或另一套 fluent 配置 |

## Host 交接

`empty → active`：第一个 host 获得独立 generation、loading/toast 资源与 registry 绑定。

同帧出现候选或 active 卸载时进入 `pending`。帧末先清理已卸载 host；旧 generation 的队列、in-flight、timer、loading/toast 与 registry 绑定全部结算后，唯一存活候选才能晋升为 `active`。无候选回到 `empty`；多个存活 host 或旧 active 与新候选同时存活属于拓扑冲突，不能接受新命令。交接期间命令报错，旧句柄不会重新绑定新 generation。

Host 生命周期集中在 manager，generation、候选晋升和 registry 协调保持一个状态所有者。关闭操作通过窄接口协调，不接管队列所有权。

## 返回目标选择

路由 PopEntry 的阻止判断与实际返回分发共用 manager 的 `_backTargets`。按 Loading、通知、Dialog/Popup 顺序检查；同一组活动弹层按最新优先。没有 callback 的 `passThrough` 不成为消费目标，继续检查下层，全部穿透时允许应用处理返回。

暂停的、不可见的或 permanent 的活动 Dialog/Popup 不参与返回。消费型关闭中任务仍参与，后续返回加入其已有关闭 future，不再次调用业务 callback 或关闭下层。generation 内的分发锁避免一次请求并发消费多层。

全局关闭默认的 `highestPriority` 表示类别优先级，不表示视觉 z-order。scoped facade 只暴露 route-owned Dialog/Popup；全局反馈、查询和清理通过 `SuperOverlay` 明确发起。

## Dialog / Popup 呈现

`presented ↔ suspended → closing → closed`。owner 路由覆盖时暂停，恢复 current 时重新呈现。已显示内容保留 Element 状态，但停用命中测试、语义、焦点和 ticker；首次可见前暂停的内容延迟构建。路由/observer 移除、绑定目标卸载优先于暂停返回，必须关闭。

声明式路由以 Navigator 当前 `pages` 顺序为准，pageless route 与其所属 Page 一起移动；不能仅依靠 `didChangeTop`，因为顶层 PopupRoute 不变时底层 Page 仍能重排。已绘制内容若在首次可见确认前暂停，由 controller 在恢复后的帧补做确认；关闭后的失败结果不能被恢复覆盖。

更新路由事件后，以 Navigator 中 Route 的 `isCurrent` 核对当前路由，再安装 PopEntry gate 和捕获全局命令 owner。非顶层 Page 的插入或替换也会产生 `didPush`，当前路由记录必须保留实际顶层。

排队命令在替换清理前和实际激活前分别检查 generation、显式取消、路由 owner 与组件 mounted 状态。Dialog 使用 `bindToWidget`，挂载型 Popup 使用 `targetContext`；组件失效时不构建内容，`visible` 失败而 `closed` 正常完成并保留首次关闭结果。检查先于替换清理时保留已有匹配项，已经开始的关闭不会撤销。Popup 的几何校验独立保留，不把 Dialog 的零尺寸组件视为卸载。激活、取消及异常出口都释放待执行 factory 和 owner 引用。

Escape 仍局限于内容焦点链，由局部 ShortcutManager 派发 `DismissIntent`，优先保留焦点内容的 Actions 处理结果。输入框可先收起选择工具栏；只有 `ignored` 才回退到 Overlay 或应用策略，包括 Flutter 3.29 MenuAnchor 关闭后残留禁用动作的情况。`handled` 与 `skipRemainingHandlers` 不触发回退。没有消费目标时转交外层应用 Actions，没有应用处理器则继续传播按键，不依赖内容拥有 ModalRoute。

应用动作的查找位置与调用上下文分开：在本层 Actions 外查找应用处理器，以实际调用上下文判断 ContextAction 启用状态并经对应 dispatcher 调用。每次局部快捷键分发单独保存动作选择，在 dispatcher 返回后转换其实际返回值；invoke 仍返回应用原值，不保存跨按键结果。分发器拦截或禁用、本层已调用或已转换的动作都不能导致同一边界重复回退。重入保留外层动作选择，异常通过 finally 释放本次分发上下文。其他原生 ShortcutManager 可以直接使用桥接动作：应用返回值正常转交，桥接发起的异步返回请求通过弱引用标记识别。外层其他快捷键映射仍保留 Flutter 自己的派发行为，原生内容的 handled 结果不被绕过。

每个快捷键边界只在桥接动作实际调用 manager 消费返回时记录 consumedBack，并优先将该键转换为 handled。dispatcher 完全拦截且不 invoke 时，不能仅凭存在消费型弹层判断该键已被消费，而由应用 Action 转换最终返回值；无应用 Action 则使用 Flutter 默认消费结果。原生 ShortcutManager 可绕过桥接的 isEnabled 和 invoke，因此不尝试提前猜测其开始时的返回策略。early handler 只标记按键观察期，实际动作选择惰性读取；原生转换、局部分发栈、异常及微任务出口分别清理状态。

manager 保存 `lastRenderedAnchorRect` 和 0.5 logical pixel 移动容差。几何 helper 只返回测量结果：部分越界继续跟随，完全离开 host 视口或无效目标由 manager 终止；暂停期间不测量。持久帧回调依托已有帧工作，不为监测自行持续请求帧。

## Close 的结算顺序

1. 若 record 已有 dismissal，后续 close 加入同一个 operation，不启动第二次动画，也不覆盖首次结果。
2. 首次 dialog close 先验证 typed result；验证失败不移出队列、不改变状态。有效关闭才创建 operation、移到 in-flight、更新返回状态并取消 display timer。
3. operation await 内容 dismiss；manager 的 cleanup claim 保证 in-flight 删除和 OverlayEntry 移除只执行一次。句柄结果仍由内容的原有 close/teardown 路径结算。
4. dismiss 失败仍尝试 cleanup，operation 保留首个异常；cleanup 的二次失败不替换原异常。
5. host teardown 可以先取得 cleanup claim，移除记录、entry 和 timer，按现有契约结算句柄，并提前 settle operation。后续动画完成/异常不能再次结算或清理新 generation。
6. 批量关闭在调用时捕获匹配的活动与 in-flight 记录，等待全部关闭操作结算。全局 `all` 同步启动各 surface 的快照与关闭，再等待全部任务，不在等待后查询其他 surface；后续新建的 owner 不属于这次清理。tag、surface 和 generation 过滤同时作用于两组；不重启已有动画，不覆盖首次关闭结果。

内部关闭按已选中的实际 record 执行，不把实例身份降级为业务 tag 查找。自动到期、绑定组件失效及延迟路由清理都遵循此约束，包括内部调用显式复用 identity tag 的情况。遮罩与 Popup 目标失败回调额外绑定展示轮次，复用同一 record 或同一个参数对象也不能转移旧回调。UI 回调通过弱 owner 引用避免保留替换内容；调用用户 onMask 前后都检查归属，关闭中的回调只加入原关闭任务。Loading 使用独立 lifecycle，Toast 使用当前 lane 展示轮次；Toast 历史句柄仍共享 lane 关闭信号。显式全局 tag 清理保留原匹配语义。

Loading、Toast 拥有各自生命周期。`loading.run()` 返回业务结果并自动关闭其 generation/identity 所属 Loading；业务与清理同时失败时保留业务异常。并发任务独立执行，最新调用占用显示位置，旧调用收尾不能关闭替代 Loading。关闭与宿主销毁不会取消业务任务。

Loading 的最短可见时长从 controller 首次可见确认后计时；正值下首帧前的关闭请求仍等待呈现与最短时长。每次替换有独立 lifecycle，旧可见回调不能给新调用安装 timer；宿主清理立即结算并取消 timer。
句柄的关闭和可见查询仅按 identity 匹配，不能用业务 tag 扩展所有权。此约束同时作用于活动请求、等待最短时长的关闭任务和延迟显示请求；全局按 tag 操作保留业务匹配语义。

Toast 刷新 lane 只保存当前内容请求。关闭信号经过 runtime 与句柄按需关联，未观察 closed 的历史刷新不向共享信号注册等待链；保留历史 closed 语义而不累积已丢弃请求的生命周期和控制器。激活前观察 closed 的请求仍关联自己的结算；排队请求在激活前暴露的独立 future 仍由当前请求关闭时结算。拒绝显示时必须独立使 visible 失败，不能依赖 closed 被观察。

命令 fire 工厂在使用或取消后释放。Dialog、Popup、通知与 Toast 句柄的可见查询使用 lifecycle 方法；Loading 的句柄回调由独立工厂生成，避免与默认内容工厂共享捕获上下文。关闭后的句柄不持有内容 builder，其 closed 结果仍按原契约保留。

按需调试快照仅在测试/测量读取时分配，不构成全局内存泄漏证明。

## 布局边界

Popup 的位置适配与通知/Toast 的既有避让机制由组件负责。普通自定义 dialog 沿用内容拥有键盘布局的契约：使用 `AlertDialog`，或在自定义内容中响应 `MediaQuery.viewInsets` 并提供滚动约束。manager 不重写任意 builder 的布局或自动捕获局部 Provider。
