import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ViewUtils {
  static void addSafeUse(VoidCallback callback) {
    if (schedulerBinding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      widgetsBinding.addPostFrameCallback((_) => callback());
      return;
    }
    callback();
  }

  static Future<void> awaitSafeUse({VoidCallback? onPostFrame}) async {
    final completer = Completer<void>();

    void complete() {
      onPostFrame?.call();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    if (schedulerBinding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      widgetsBinding.addPostFrameCallback((_) => complete());
    } else {
      complete();
    }

    return completer.future;
  }

  static Future<void> awaitPostFrame({VoidCallback? onPostFrame}) {
    final completer = Completer<void>();
    widgetsBinding.addPostFrameCallback((_) {
      onPostFrame?.call();
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }
}

WidgetsBinding get widgetsBinding => WidgetsBinding.instance;

SchedulerBinding get schedulerBinding => SchedulerBinding.instance;

OverlayState overlayOf(BuildContext context) => Overlay.of(context);
