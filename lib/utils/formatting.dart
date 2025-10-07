String formatRating(num rating, {int decimals = 2}) {
  try {
    return rating.toDouble().toStringAsFixed(decimals);
  } catch (_) {
    return rating.toString();
  }
}

/// Extract display name from user data with robust fallback
String getUserDisplayName(Map<String, dynamic> userData) {
  return (userData['displayName'] ?? 
          userData['name'] ?? 
          userData['authorName'] ?? 
          userData['email']?.toString().split('@').first ?? 
          'Гравець').toString();
}

/// Extract avatar URL from user data with robust fallback
String getUserAvatarUrl(Map<String, dynamic> userData) {
  return (userData['avatarUrl'] ?? 
          userData['avatar'] ?? 
          userData['photoUrl'] ?? '').toString();
}



