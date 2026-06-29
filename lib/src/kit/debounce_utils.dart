enum OverlayDebounceType { custom, attach, notify, toast, mask }

typedef DateTimeClock = DateTime Function();

class DebounceUtils {
  DebounceUtils({DateTimeClock? clock}) : _clock = clock ?? DateTime.now;

  static final DebounceUtils instance = DebounceUtils();

  static const Duration maskDuration = Duration(milliseconds: 500);

  final DateTimeClock _clock;
  final Map<OverlayDebounceType, DateTime> _lastTriggerByType = {};

  bool banContinue(
    OverlayDebounceType type, {
    required bool debounce,
    required Duration duration,
  }) {
    if (!debounce) {
      return false;
    }

    final now = _clock();
    final lastTrigger = _lastTriggerByType[type];
    _lastTriggerByType[type] = now;

    if (lastTrigger == null) {
      return false;
    }

    return now.difference(lastTrigger) < duration;
  }

  bool banMaskContinue() {
    return banContinue(
      OverlayDebounceType.mask,
      debounce: true,
      duration: maskDuration,
    );
  }

  void reset() {
    _lastTriggerByType.clear();
  }
}
