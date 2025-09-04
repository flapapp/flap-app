import 'package:flutter/material.dart';
import '../services/rating_service.dart';

class RatingDisplay extends StatelessWidget {
  final String userId;
  final double? rating;
  final double size;
  final bool showLevel;
  final bool showNumber;
  final VoidCallback? onTap;

  const RatingDisplay({
    Key? key,
    required this.userId,
    this.rating,
    this.size = 24.0,
    this.showLevel = true,
    this.showNumber = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: rating != null 
          ? Future.value(rating!) 
          : RatingService().getUserRating(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingRating();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildDefaultRating();
        }

        final currentRating = snapshot.data!;
        final level = RatingService().getPlayerLevel(currentRating);
        final levelColor = Color(RatingService().getPlayerLevelColor(currentRating));

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  levelColor.withOpacity(0.2),
                  levelColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: levelColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showNumber) ...[
                  const Text('⭐', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    currentRating.toStringAsFixed(2),
                    style: TextStyle(
                      color: levelColor,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (showLevel)
                  Text(
                    level,
                    style: TextStyle(
                      color: levelColor,
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingRating() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          SizedBox(
            width: 20,
            height: 12,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultRating() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '3.0',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Середній',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: size * 0.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Компактний варіант тільки з числом
class CompactRatingDisplay extends StatelessWidget {
  final String userId;
  final double? rating;
  final double size;
  final VoidCallback? onTap;

  const CompactRatingDisplay({
    Key? key,
    required this.userId,
    this.rating,
    this.size = 20.0,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: rating != null 
          ? Future.value(rating!) 
          : RatingService().getUserRating(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingRating();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildDefaultRating();
        }

        final currentRating = snapshot.data!;
        final levelColor = Color(RatingService().getPlayerLevelColor(currentRating));

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: levelColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 2),
                Text(
                  currentRating.toStringAsFixed(2),
                  style: TextStyle(
                    color: levelColor,
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingRating() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
              child: SizedBox(
          width: 20,
          height: 12,
          child: LinearProgressIndicator(
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withOpacity(0.6),
            ),
          ),
        ),
    );
  }

  Widget _buildDefaultRating() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 2),
          Text(
            '3.0',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: size * 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
