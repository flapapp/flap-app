import 'package:flutter/material.dart';

/// Shared with [AppRouter] so locale can be changed without a [BuildContext].
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
