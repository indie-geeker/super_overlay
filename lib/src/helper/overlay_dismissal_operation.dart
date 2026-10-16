import 'dart:async';

/// One dismissal and one cleanup claim shared by concurrent close callers and
/// host teardown. The manager retains queues and resource ownership.
class OverlayDismissalOperation {
  final Completer<void> _completer = Completer<void>();
  bool _cleanupClaimed = false;
  bool _started = false;

  Future<void> get future => _completer.future;

  bool beginCleanup() {
    if (_cleanupClaimed) return false;
    _cleanupClaimed = true;
    return true;
  }

  void start({
    required Future<void> Function() dismiss,
    required void Function() cleanup,
  }) {
    if (_started) return;
    _started = true;
    unawaited(_run(dismiss, cleanup));
  }

  Future<void> _run(
    Future<void> Function() dismiss,
    void Function() cleanup,
  ) async {
    try {
      await dismiss();
      cleanup();
      _complete();
    } catch (error, stack) {
      try {
        cleanup();
      } catch (_) {
        /* Preserve the first failure. */
      }
      if (!_completer.isCompleted) _completer.completeError(error, stack);
    }
  }

  void _complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void settleForTeardown() => _complete();
}
