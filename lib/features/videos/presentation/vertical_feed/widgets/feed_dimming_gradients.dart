import 'package:flutter/material.dart';

/// Full-screen vignette used behind overlays on feed-style pages (videos, challenges).
class FeedDimmingGradients extends StatelessWidget {
  const FeedDimmingGradients({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.72),
            ],
            stops: const [0, 0.18, 0.52, 1],
          ),
        ),
      ),
    );
  }
}
