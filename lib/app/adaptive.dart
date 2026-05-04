import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Breakpoint used to decide when to display the wide (web) layout.
const double _webLayoutBreakpoint = 900;

/// Returns `true` when the UI should use the web-only layout.
///
/// On native platforms this always returns `false`. On the web it checks the
/// available width so that a narrow browser (e.g., mobile emulator in Chrome)
/// will still render the mobile experience.
bool useWebLayout(BuildContext context) {
  if (!kIsWeb) {
    return false;
  }

  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery == null) {
    // Without MediaQuery fall back to the safest option for web: assume wide.
    return true;
  }

  return mediaQuery.size.width >= _webLayoutBreakpoint;
}

/// Convenience helper that flips [useWebLayout].
bool useMobileLayout(BuildContext context) => !useWebLayout(context);
