# Example Coverage Matrix

This matrix connects advertised capabilities to documentation, a runnable
example where appropriate, and automated evidence. A row without an interactive
example must have an explicit reason and a package-level fixture.

| Capability | README contract | Runnable example | Automated evidence |
| --- | --- | --- | --- |
| Stable root integration | [Root Integration](../../README.md) | [`showcase_app.dart`](../../example/lib/showcase/showcase_app.dart) | [`consumer_import_smoke_test.dart`](../../test/consumer_import_smoke_test.dart), [`super_overlay_integration_test.dart`](../../test/super_overlay_integration_test.dart) |
| Typed dialog result | [Command And Handle Basics](../../README.md) | [`dialog_demo_panel.dart`](../../example/lib/showcase/dialog_demo_panel.dart) | [`dialog_result_test.dart`](../../example/test/dialog_result_test.dart) |
| Back `dismiss`, `block`, `passThrough` | [Back, Focus, And Semantics](../../README.md) | [`lifecycle_demo_page.dart`](../../example/lib/showcase/lifecycle_demo_page.dart) | [`back_behavior_demo_test.dart`](../../example/test/back_behavior_demo_test.dart), [`super_overlay_back_dispatch_test.dart`](../../test/super_overlay_back_dispatch_test.dart) |
| Nested Navigator ownership | [Nested Navigator Integration](../../README.md) | [`nested_navigation_demo_page.dart`](../../example/lib/showcase/nested_navigation_demo_page.dart) | [`nested_navigation_demo_test.dart`](../../example/test/nested_navigation_demo_test.dart), [`super_overlay_nested_navigation_test.dart`](../../test/super_overlay_nested_navigation_test.dart) |
| `ShellRoute` ownership | [go_router ShellRoute](../../README.md) | Documentation fixture only; the example intentionally stays Flutter-only | [`documentation_contract_test.dart`](../../test/documentation_contract_test.dart), [`super_overlay_shell_route_test.dart`](../../test/super_overlay_shell_route_test.dart) |
| Stateful shell branch activity | [go_router ShellRoute](../../README.md) | Documentation fixture only; branch topology is tested with real `go_router` | [`documentation_contract_test.dart`](../../test/documentation_contract_test.dart), [`super_overlay_shell_route_test.dart`](../../test/super_overlay_shell_route_test.dart) |
| Moving popup anchors | [Moving Anchored Popups](../../README.md) | [`anchored_menu_panel.dart`](../../example/lib/showcase/anchored_menu_panel.dart) | [`super_overlay_popup_anchor_tracking_test.dart`](../../test/super_overlay_popup_anchor_tracking_test.dart), [`anchored_menu_panel_test.dart`](../../example/test/anchored_menu_panel_test.dart) |
| Highlight and fixed mask ignore area | [Moving Anchored Popups](../../README.md) | [`guided_mask_panel.dart`](../../example/lib/showcase/guided_mask_panel.dart), [`advanced_popup_panel.dart`](../../example/lib/showcase/advanced_popup_panel.dart) | [`guided_mask_panel_test.dart`](../../example/test/guided_mask_panel_test.dart), [`super_overlay_popup_anchor_tracking_test.dart`](../../test/super_overlay_popup_anchor_tracking_test.dart) |
| `refreshActive` versus `handle.refresh()` | [Refresh Contracts](../../README.md) | [`instant_feedback_panel.dart`](../../example/lib/showcase/instant_feedback_panel.dart) | [`instant_feedback_panel_test.dart`](../../example/test/instant_feedback_panel_test.dart) |
| Modal focus, semantics, and Escape | [Back, Focus, And Semantics](../../README.md) | Lifecycle and confirmation flows | [`super_overlay_accessibility_test.dart`](../../test/super_overlay_accessibility_test.dart) |
| Host replacement and conflict safety | [Atomic Root Replacement](../../README.md) | Not interactive; requires controlled root ownership fixtures | [`super_overlay_host_lifecycle_test.dart`](../../test/super_overlay_host_lifecycle_test.dart), [`super_overlay_host_ownership_test.dart`](../../test/super_overlay_host_ownership_test.dart) |
| Responsive and safe-area behavior | [example README](../../example/README.md) | Full showcase | [`responsive_layout_test.dart`](../../example/test/responsive_layout_test.dart), [`widget_test.dart`](../../example/test/widget_test.dart) |

Manual cutout, orientation, keyboard, and platform evidence is tracked in the
[device verification matrix](example_device_matrix.md).
