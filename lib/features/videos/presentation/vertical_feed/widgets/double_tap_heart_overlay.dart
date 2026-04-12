import 'package:flutter/material.dart';

/// Brief heart burst at [position] for double-tap-like feedback (TikTok-style).
class DoubleTapHeartOverlay extends StatefulWidget {
  const DoubleTapHeartOverlay({
    super.key,
    required this.position,
    required this.onAnimationEnd,
  });

  final Offset position;
  final VoidCallback onAnimationEnd;

  @override
  State<DoubleTapHeartOverlay> createState() => _DoubleTapHeartOverlayState();
}

class _DoubleTapHeartOverlayState extends State<DoubleTapHeartOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward().whenComplete(widget.onAnimationEnd);

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeIn)),
      weight: 45,
    ),
  ]).animate(_c);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 45),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 48,
      top: widget.position.dy - 48,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            );
          },
          child: Icon(
            Icons.favorite,
            size: 96,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: const [
              Shadow(blurRadius: 16, color: Colors.pinkAccent),
              Shadow(blurRadius: 8, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}
