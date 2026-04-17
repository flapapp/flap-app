/// Where the app should navigate after cold start (guest vs signed-in).
enum StartupDestination {
  /// Signed-in hub.
  authenticated,

  /// First launch guest flow — show one-time intro.
  guestIntro,

  /// Returning guest — skip intro.
  guestWelcome,
}
