import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/matches/data/rating_service.dart';
import 'package:flap_app/features/videos/domain/entities/library_video.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/utils/i18n.dart';

/// Full rating vote (simple / advanced sliders) — same backend as [VideoMainScreen] / [VideoPlayerScreen].
Future<void> showFeedVideoVoteSheet(
  BuildContext hostContext, {
  required LibraryVideo video,
  VoidCallback? onVoteSubmitted,
}) async {
  final currentUser = AppAuthContext.currentUser;
  if (currentUser == null) {
    ScaffoldMessenger.of(hostContext).showSnackBar(
      SnackBar(
        content: Text(
          I18n.inline('Увійдіть, щоб оцінювати відео', 'Sign in to rate videos'),
        ),
      ),
    );
    return;
  }

  if (video.userId.isNotEmpty && video.userId == currentUser.id) {
    ScaffoldMessenger.of(hostContext).showSnackBar(
      SnackBar(
        content: Text(
          I18n.inline(
            'Не можна голосувати за власне відео',
            'You cannot vote on your own video',
          ),
        ),
      ),
    );
    return;
  }

  try {
    final has = await hostContext.read<VideosRepository>().userHasVote(
          videoId: video.id,
          userId: currentUser.id,
        );
    if (has) {
      if (!hostContext.mounted) return;
      ScaffoldMessenger.of(hostContext).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Ви вже оцінили це відео', 'You already rated this video'),
          ),
        ),
      );
      return;
    }
  } catch (_) {}

  if (!hostContext.mounted) return;

  final ratingService = RatingService();
  final videoTitle =
      video.title.trim().isNotEmpty ? video.title.trim() : I18n.inline('Відео', 'Video');

  double overall = 3.0;
  double technical = 3.0;
  double creativity = 3.0;
  double difficulty = 3.0;
  double quality = 3.0;
  bool advanced = false;
  bool submitting = false;

  await showModalBottomSheet<void>(
    context: hostContext,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF101320),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (modalContext, setModalState) {
        Widget sliderTile(
          String label,
          double value,
          ValueChanged<double> onChanged,
        ) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Slider(
                value: value,
                min: 0,
                max: 5,
                divisions: 50,
                label: value.toStringAsFixed(1),
                activeColor: const Color(0xFFFFC107),
                onChanged: onChanged,
              ),
            ],
          );
        }

        Future<void> submitVote() async {
          if (submitting) return;
          setModalState(() => submitting = true);
          final criteria = advanced
              ? <String, double>{
                  'technical': technical,
                  'creativity': creativity,
                  'difficulty': difficulty,
                  'quality': quality,
                }
              : <String, double>{
                  'technical': overall,
                  'creativity': overall,
                  'difficulty': overall,
                  'quality': overall,
                };
          try {
            final success = await ratingService.rateVideo(
              videoId: video.id,
              ratedBy: currentUser.id,
              criteria: criteria,
            );
            if (!sheetContext.mounted) return;
            if (success) {
              Navigator.pop(sheetContext);
              onVoteSubmitted?.call();
              if (hostContext.mounted) {
                ScaffoldMessenger.of(hostContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      I18n.inline('Оцінку збережено', 'Rating submitted'),
                    ),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(
                    I18n.inline(
                      'Не вдалося зберегти оцінку',
                      'Unable to save rating',
                    ),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          } catch (e) {
            if (sheetContext.mounted) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(I18n.inline('Помилка: $e', 'Error: $e')),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          } finally {
            if (sheetContext.mounted) {
              setModalState(() => submitting = false);
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  I18n.inline('Оцініть відео', 'Rate video'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  videoTitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => advanced = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !advanced
                                  ? const Color(0xFF4caf50)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              I18n.inline('Простий', 'Simple'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !advanced ? Colors.white : Colors.white54,
                                fontWeight:
                                    !advanced ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => advanced = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: advanced
                                  ? const Color(0xFF4caf50)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              I18n.inline('Розширений', 'Advanced'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: advanced ? Colors.white : Colors.white54,
                                fontWeight:
                                    advanced ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (advanced) ...[
                  sliderTile(
                    I18n.inline('Техніка', 'Technical'),
                    technical,
                    (v) => setModalState(() => technical = v),
                  ),
                  sliderTile(
                    I18n.inline('Креативність', 'Creativity'),
                    creativity,
                    (v) => setModalState(() => creativity = v),
                  ),
                  sliderTile(
                    I18n.inline('Складність', 'Difficulty'),
                    difficulty,
                    (v) => setModalState(() => difficulty = v),
                  ),
                  sliderTile(
                    I18n.inline('Якість відео', 'Video quality'),
                    quality,
                    (v) => setModalState(() => quality = v),
                  ),
                ] else ...[
                  sliderTile(
                    I18n.inline('Загальна оцінка', 'Overall rating'),
                    overall,
                    (v) => setModalState(() => overall = v),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: submitting ? null : submitVote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      disabledBackgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      submitting
                          ? I18n.inline('Надсилаємо...', 'Submitting...')
                          : I18n.inline('Оцінити відео', 'Submit rating'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
