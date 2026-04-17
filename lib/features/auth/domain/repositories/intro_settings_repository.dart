/// Intro / onboarding persistence (domain contract).
abstract class IntroSettingsRepository {
  Future<bool> isIntroCompleted();

  Future<void> markIntroCompleted();
}
