/// Maps UI labels to `public.video_difficulty` enum values (EASY, MEDIUM, HARD, EXPERT).
String videoDifficultyToPostgres(String? uiLabel) {
  if (uiLabel == null || uiLabel.trim().isEmpty) {
    return 'EASY';
  }
  final u = uiLabel.toUpperCase().trim();
  if (u == 'EASY' || u == 'MEDIUM' || u == 'HARD' || u == 'EXPERT') {
    return u;
  }
  final s = uiLabel.toLowerCase();
  if (s.contains('легк') || s.contains('easy')) return 'EASY';
  if (s.contains('серед') || s.contains('medium')) return 'MEDIUM';
  if (s.contains('склад') || s.contains('hard')) return 'HARD';
  if (s.contains('експерт') || s.contains('expert')) return 'EXPERT';
  return 'EASY';
}
