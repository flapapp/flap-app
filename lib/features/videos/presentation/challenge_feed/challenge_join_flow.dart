import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/features/challenges/domain/challenge_failure.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/utils/i18n.dart';

/// Confirmation + join + navigate to upload (same flow as the legacy challenge card).
void showChallengeJoinDialog(BuildContext context, Challenge challenge) {
  final challengeId = challenge.id;
  final currentUser = AppAuthContext.currentUser;
  if (currentUser == null) return;
  final now = DateTime.now();
  final isCompletedByDate =
      now.isAfter(challenge.votingDeadline) || now.isAfter(challenge.endDate);
  if (challenge.status == ChallengeStatus.completed || isCompletedByDate) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          I18n.inline(
            'Челендж завершено. Подати відео вже неможливо.',
            'Challenge is completed. Video submission is closed.',
          ),
        ),
      ),
    );
    return;
  }

  context.read<ChallengeRepository>().getSubmission(
    challengeId: challengeId,
    submissionUserId: currentUser.id,
  ).then((existingSubmission) {
    if (!context.mounted) return;
    if (existingSubmission != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Ви вже подали відео для цього челенджу.',
              'You already joined this challenge and submitted a video.',
            ),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1e7d32),
        title: Text(
          I18n.inline('Приєднатися до челенджу', 'Join challenge'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              I18n.inline(
                'Ви приєднуєтеся до челенджу "${challenge.title}"',
                'You are joining the challenge "${challenge.title}"',
              ),
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              I18n.inline(
                'Ставка входу: ${challenge.entryFee} монет',
                'Entry fee: ${challenge.entryFee} coins',
              ),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              I18n.t('cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await context.read<ChallengeRepository>().joinChallenge(challengeId);
                if (!context.mounted) return;
                await context.pushRoute(
                  VideoUploadRoute(
                    challengeId: challengeId,
                    challengeTitle: challenge.title,
                  ),
                );
              } on ChallengeFailure catch (f) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(I18n.inline('Помилка приєднання: ${f.message}', 'Join error: ${f.message}')),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(I18n.inline('Помилка приєднання: $e', 'Join error: $e'))),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4caf50)),
            child: Text(
              I18n.inline('Завантажити відео', 'Upload video'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  });
}
