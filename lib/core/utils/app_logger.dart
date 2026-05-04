import 'package:flutter/foundation.dart';

bool _appLoggerEnabled = true;

/// Allows tests to silence development logs without weakening production
/// behaviour. Logging is still assert-only and stripped from release builds.
@visibleForTesting
void setAppLoggerEnabledForTesting(bool enabled) {
  _appLoggerEnabled = enabled;
}

/// Development-only logger. Messages are stripped from release builds because
/// they are executed inside assert callbacks.
void appLog(Object? message) {
  assert(() {
    if (_appLoggerEnabled) {
      debugPrint(message?.toString());
    }
    return true;
  }());
}

/// Development-only error logger. Avoid passing sensitive payloads or full rows.
void appLogError(Object error, [StackTrace? stackTrace]) {
  assert(() {
    if (_appLoggerEnabled) {
      debugPrint('Error: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
    return true;
  }());
}
