import 'package:flutter/material.dart';

enum ModeArtType { matches, videos, teams }

class ModeArt extends StatelessWidget {
  const ModeArt({super.key, required this.type, required this.colors});

  final ModeArtType type;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case ModeArtType.matches:
        return _buildMatchesArt();
      case ModeArtType.videos:
        return _buildVideoArt();
      case ModeArtType.teams:
        return _buildTeamsArt();
    }
  }

  Widget _buildMatchesArt() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        children: [
          _blurredCircle(colors.first),
          Positioned(
            right: 16,
            top: 12,
            child: Icon(
              Icons.sports_soccer,
              color: Colors.white.withValues(alpha: 0.3),
              size: 72,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 10,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArt() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        children: [
          _blurredCircle(colors.last),
          Positioned(
            right: 12,
            top: 20,
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white.withValues(alpha: 0.3),
              size: 78,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 16,
            child: Container(
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsArt() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        children: [
          _blurredCircle(colors.first),
          Positioned(
            right: 20,
            top: 10,
            child: Icon(
              Icons.shield,
              color: Colors.white.withValues(alpha: 0.25),
              size: 70,
            ),
          ),
          Positioned(
            right: -6,
            bottom: 12,
            child: Container(
              width: 90,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  Icon(Icons.person, color: Colors.white54, size: 18),
                  Icon(Icons.person, color: Colors.white38, size: 18),
                  Icon(Icons.person, color: Colors.white24, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurredCircle(Color base) {
    return Positioned(
      right: -30,
      top: -30,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.2),
              base.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
