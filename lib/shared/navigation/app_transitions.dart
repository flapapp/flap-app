import 'package:flutter/material.dart';

import '../../core/motion/app_motion.dart';

abstract final class AppTransitions {
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppMotion.pagePush,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        );
        return SlideTransition(
          position: animation.drive(CurveTween(curve: AppMotion.standardOut)).drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
