/// Shared rules for profile onboarding redirects ([AvatarRequiredGuard], post-login routing).
bool onboardingHasCompletedNames(Map<String, dynamic> doc) {
  final firstName = (doc['firstName'] ?? '').toString().trim();
  final lastName = (doc['lastName'] ?? '').toString().trim();
  return firstName.isNotEmpty && lastName.isNotEmpty;
}
