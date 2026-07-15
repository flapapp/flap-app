import '../services/rating_service.dart';
import '../../domain/repositories/ratings_repository.dart';

class RatingsRepositoryImpl implements RatingsRepository {
  RatingsRepositoryImpl(this._rating);

  final RatingService _rating;

  @override
  Future<void> updateVideoAggregate(String videoId) {
    return _rating.updateVideoAggregate(videoId);
  }

  @override
  Future<double> getUserRating(String userId) {
    return _rating.getUserRating(userId);
  }

  @override
  Future<Map<String, dynamic>> getUserRatingStats(String userId) {
    return _rating.getUserRatingStats(userId);
  }

  @override
  Future<void> ratePlayerAfterMatch({
    required String matchId,
    required String playerId,
    required String ratedBy,
    required Map<String, double> criteria,
  }) {
    return _rating.ratePlayerAfterMatch(
      matchId: matchId,
      playerId: playerId,
      ratedBy: ratedBy,
      criteria: criteria,
    );
  }

  @override
  Future<bool> rateVideo({
    required String videoId,
    required String ratedBy,
    required Map<String, double> criteria,
  }) {
    return _rating.rateVideo(
      videoId: videoId,
      ratedBy: ratedBy,
      criteria: criteria,
    );
  }

  @override
  String getPlayerLevel(double rating) {
    return _rating.getPlayerLevel(rating);
  }

  @override
  int getPlayerLevelColor(double rating) {
    return _rating.getPlayerLevelColor(rating);
  }

  @override
  Future<void> createUserWithDefaultRating(
    String userId,
    Map<String, dynamic> userData,
  ) {
    return _rating.createUserWithDefaultRating(userId, userData);
  }

  @override
  double getDefaultRating() {
    return _rating.getDefaultRating();
  }

  @override
  Future<void> recomputeOverallRating(
    String userId, {
    String? reason,
    String? source,
    String? sourceType,
    String? sourceId,
  }) {
    return _rating.recomputeOverallRating(
      userId,
      reason: reason,
      source: source,
      sourceType: sourceType,
      sourceId: sourceId,
    );
  }

  @override
  Future<void> recomputeForMatchParticipants(String matchId) {
    return _rating.recomputeForMatchParticipants(matchId);
  }

  @override
  Future<void> recomputeAllUsers({int pageSize = 200}) {
    return _rating.recomputeAllUsers(pageSize: pageSize);
  }

  @override
  Future<List<Map<String, dynamic>>> getTopPlayers({
    int limit = 50,
    String? city,
    String? position,
  }) {
    return _rating.getTopPlayers(
      limit: limit,
      city: city,
      position: position,
    );
  }
}
