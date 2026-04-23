import 'package:flutter/material.dart';

/// Global navigator key so services (notifications, deep links) can push
/// routes without a BuildContext.
class AppNav {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;
}
