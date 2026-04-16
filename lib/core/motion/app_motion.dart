import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const Duration pagePush = Duration(milliseconds: 240);
  static const Duration modal = Duration(milliseconds: 280);
  static const Duration micro = Duration(milliseconds: 160);

  static const Curve standardOut = Curves.easeOutCubic;
  static const Curve standardInOut = Curves.easeInOutCubic;
}
