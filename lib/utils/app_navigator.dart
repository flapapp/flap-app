import 'package:flutter/material.dart';

import '../router/app_router.dart';

/// Legacy access to the root [NavigatorState] for code that still uses
/// imperative `Navigator` APIs (dialogs, legacy snippets).
final class AppNavigator {
  static GlobalKey<NavigatorState> get navigatorKey => appRouter.navigatorKey;
}
