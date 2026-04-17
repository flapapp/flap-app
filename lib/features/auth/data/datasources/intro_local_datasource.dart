/// Local persistence for intro onboarding (data layer).
abstract class IntroLocalDataSource {
  Future<bool> getIntroCompleted();

  Future<void> setIntroCompleted(bool value);
}
