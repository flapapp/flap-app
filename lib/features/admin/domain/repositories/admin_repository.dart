/// Deletes all challenge-related rows in Supabase (submissions, then challenges via RPC).
abstract class AdminRepository {
  Future<void> deleteAllChallengesAndSubmissions();
}
