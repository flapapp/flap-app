String formatRating(num rating, {int decimals = 2}) {
  try {
    return rating.toDouble().toStringAsFixed(decimals);
  } catch (_) {
    return rating.toString();
  }
}



