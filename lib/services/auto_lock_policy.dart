class AutoLockPolicy {
  AutoLockPolicy._();

  static const List<int> allowedTimeoutSeconds = [0, 30, 60, 300];
  static const int defaultTimeoutSeconds = 0;

  static bool isAllowedTimeout(int seconds) =>
      allowedTimeoutSeconds.contains(seconds);

  static int normalizeTimeout(int? seconds) {
    if (seconds == null || !isAllowedTimeout(seconds)) {
      return defaultTimeoutSeconds;
    }
    return seconds;
  }

  static bool lockImmediatelyOnPause(int timeoutSeconds) =>
      normalizeTimeout(timeoutSeconds) <= 0;

  static bool shouldLockOnResume({
    required int timeoutSeconds,
    required DateTime? pausedAt,
    required DateTime now,
  }) {
    final timeout = normalizeTimeout(timeoutSeconds);
    if (timeout <= 0) return false;
    if (pausedAt == null) return false;
    final elapsed = now.difference(pausedAt);
    if (elapsed.isNegative) return false;
    return elapsed >= Duration(seconds: timeout);
  }

  static String labelForTimeout(int seconds) {
    switch (normalizeTimeout(seconds)) {
      case 30:
        return 'After 30 seconds';
      case 60:
        return 'After 1 minute';
      case 300:
        return 'After 5 minutes';
      case 0:
      default:
        return 'Immediately';
    }
  }
}
