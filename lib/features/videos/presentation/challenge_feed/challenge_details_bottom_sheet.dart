import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/features/videos/presentation/challenge_feed/challenge_join_flow.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/utils/i18n.dart';

String _statusLabel(String status) {
  switch (status) {
    case 'recruiting':
      return I18n.inline('Набір', 'Recruiting');
    case 'submission':
      return I18n.inline('Подання', 'Submission');
    case 'voting':
      return I18n.inline('Голосування', 'Voting');
    case 'completed':
      return I18n.inline('Завершено', 'Completed');
    default:
      return status;
  }
}

Future<void> showChallengeDetailsBottomSheet(
  BuildContext context, {
  required Challenge challenge,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      final now = DateTime.now();
      final isCompletedByDate = now.isAfter(challenge.votingDeadline);
      final isCompleted = challenge.status == ChallengeStatus.completed || isCompletedByDate;
      final displayStatus = isCompleted ? 'completed' : challenge.status.name;
      final remaining = challenge.votingDeadline.difference(now);
      final remainingDays =
          remaining.inSeconds <= 0 ? 0 : (remaining.inHours / 24).ceil();
      final totalSeconds =
          challenge.votingDeadline.difference(challenge.createdAt).inSeconds;
      final elapsedSeconds =
          now.difference(challenge.createdAt).inSeconds.clamp(0, totalSeconds);
      final timelineProgress =
          totalSeconds > 0 ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: FlapTheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: FlapTheme.outlineMuted),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlapTheme.onDarkMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              challenge.title.isNotEmpty
                                  ? challenge.title
                                  : I18n.inline('Без назви', 'Untitled'),
                              style: const TextStyle(
                                color: FlapTheme.onDark,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: FlapTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusLabel(displayStatus),
                              style: const TextStyle(
                                color: FlapTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        challenge.description.isNotEmpty
                            ? challenge.description
                            : I18n.inline('Без опису', 'No description'),
                        style: TextStyle(
                          color: FlapTheme.onDark.withValues(alpha: 0.88),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _metaRow(
                        icon: Icons.person_outline_rounded,
                        label: I18n.inline('Організатор', 'Organizer'),
                        value: challenge.creatorName.isNotEmpty
                            ? challenge.creatorName
                            : I18n.inline('Невідомо', 'Unknown'),
                      ),
                      _metaRow(
                        icon: Icons.location_city_outlined,
                        label: I18n.inline('Місто', 'City'),
                        value: challenge.city.isNotEmpty
                            ? challenge.city
                            : I18n.inline('—', '—'),
                      ),
                      _metaRow(
                        icon: Icons.schedule_rounded,
                        label: I18n.inline('Тривалість', 'Duration'),
                        value:
                            '${challenge.duration} ${I18n.inline('днів', 'days')}',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: FlapTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: FlapTheme.outlineMuted),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isCompleted
                                      ? I18n.inline('Статус: завершено', 'Status: completed')
                                      : I18n.inline(
                                          'До завершення голосування: $remainingDays дн.',
                                          'Voting ends in: $remainingDays days',
                                        ),
                                  style: const TextStyle(
                                    color: FlapTheme.onDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: isCompleted ? 1.0 : timelineProgress,
                                backgroundColor: FlapTheme.outlineMuted,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  FlapTheme.accent,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _statTile(
                              icon: Icons.people_rounded,
                              value: '${challenge.currentParticipants}',
                              label: I18n.inline('Учасники', 'Participants'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statTile(
                              icon: Icons.payments_outlined,
                              value: '${challenge.entryFee}',
                              label: I18n.inline('Вхід', 'Entry'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statTile(
                              icon: Icons.emoji_events_outlined,
                              value: '${challenge.prizePool.toInt()}',
                              label: I18n.inline('Приз', 'Prize'),
                            ),
                          ),
                        ],
                      ),
                      if (challenge.participants.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          I18n.inline('Учасники', 'Participants'),
                          style: const TextStyle(
                            color: FlapTheme.onDarkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${challenge.participants.length}',
                          style: const TextStyle(
                            color: FlapTheme.onDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.pushRoute(ChallengeDetailsRoute(challenge: challenge));
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        label: Text(I18n.inline('Повна сторінка челенджу', 'Open challenge page')),
                        style: FilledButton.styleFrom(
                          backgroundColor: FlapTheme.accent,
                          foregroundColor: FlapTheme.pitch,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isCompleted
                            ? null
                            : () {
                                Navigator.pop(context);
                                showChallengeJoinDialog(ctx, challenge);
                              },
                        icon: const Icon(Icons.video_call_rounded, size: 20),
                        label: Text(I18n.inline('Участь / завантажити відео', 'Join & upload')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FlapTheme.accent,
                          side: const BorderSide(color: FlapTheme.accent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _metaRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: FlapTheme.onDarkMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: FlapTheme.onDarkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: FlapTheme.onDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _statTile({
  required IconData icon,
  required String value,
  required String label,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: FlapTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlapTheme.outlineMuted),
    ),
    child: Column(
      children: [
        Icon(icon, color: FlapTheme.accent, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: FlapTheme.onDark,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: FlapTheme.onDarkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
