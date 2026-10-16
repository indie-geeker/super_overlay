# go_router 18 compatibility fixture

This private project pins go_router 18.0.2 and uses SuperOverlay through a path
dependency. It reuses the root navigation tests, which resolve against
go_router 14.8.1 in the minimum-SDK project. Runtime dependencies and the package
SDK floor are unchanged.

Verified SDK: Flutter 3.47.4. From this directory:

```bash
flutter pub get
flutter analyze
flutter test
```

Keep each nested Navigator's scoped observer even though go_router 18 forwards
shell events to root observers by default. SuperOverlay filters forwarded
events by their actual Navigator; disabling forwarding is not required.
