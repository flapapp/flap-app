import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/features/challenges/domain/entities/challenge_submission_entry.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:flap_app/features/challenges/presentation/bloc/challenges_state.dart';
import 'challenge_create_screen.dart';
import 'challenge_details_screen.dart';
import 'package:flap_app/features/videos/presentation/screens/video_player_screen.dart';
import 'challenge_video_player_screen.dart';
import 'package:flap_app/widgets/user_chip.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/video_preview_box.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/media/flap_cached_image.dart';

class ChallengesScreen extends StatefulWidget {
  final bool showOnlyMyChallenges;

  const ChallengesScreen({Key? key, this.showOnlyMyChallenges = false}) : super(key: key);

  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  String _selectedFilter = 'all'; // all, active, my, completed
  String _selectedSort = 'new'; // 'new', 'rating', 'views'
  
  @override
  Widget build(BuildContext context) {
    if (widget.showOnlyMyChallenges && _selectedFilter != 'my') {
      _selectedFilter = 'my';
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(I18n.t('all'), 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip(I18n.t('active_challenges'), 'active'),
                  const SizedBox(width: 8),
                  _buildFilterChip(I18n.t('my_challenges'), 'my'),
                  const SizedBox(width: 8),
                  _buildFilterChip(I18n.t('completed_challenges'), 'completed'),
                  const SizedBox(width: 12),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedSort,
                      underline: const SizedBox(),
                      dropdownColor: const Color(0xFF0f0f23),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      icon: const Icon(Icons.sort, color: Colors.white70),
                      items: [
                        DropdownMenuItem(value: 'new', child: Text(I18n.inline('Нові', 'New'))),
                        DropdownMenuItem(value: 'rating', child: Text(I18n.inline('Рейтинг', 'Rating'))),
                        DropdownMenuItem(value: 'views', child: Text(I18n.inline('Перегляди', 'Views'))),
                      ],
                      onChanged: (v) => setState(() => _selectedSort = v ?? 'new'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Challenges list
          Expanded(
            child: BlocBuilder<ChallengesBloc, ChallengesState>(
              builder: (context, state) {
                if (state is ChallengesInitial || state is ChallengesLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                  );
                }
                if (state is ChallengesFailure) {
                  return Center(
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (state is! ChallengesReady) {
                  return const SizedBox.shrink();
                }

                final all = state.challenges;
                if (all.isEmpty) {
                  return _buildEmptyState();
                }

                final currentUser = AppAuthContext.currentUser;
                final filtered = all.where((c) {
                  switch (_selectedFilter) {
                    case 'active':
                      final s = c.status.toString().split('.').last;
                      return s == 'recruiting' || s == 'submission' || s == 'voting';
                    case 'my':
                      if (currentUser == null) return false;
                      return c.creatorId == currentUser.id;
                    case 'completed':
                      return c.status == ChallengeStatus.completed;
                    default:
                      return true;
                  }
                }).toList()
                  ..sort((a, b) {
                    switch (_selectedSort) {
                      case 'rating':
                        final ar = 0.0;
                        final br = 0.0;
                        return br.compareTo(ar);
                      case 'views':
                        return 0;
                      case 'new':
                      default:
                        return b.createdAt.compareTo(a.createdAt);
                    }
                  });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildChallengeCard(filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Видаляю FloatingActionButton - він вже є в MainScreen
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4caf50) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4caf50) : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'my' ? I18n.inline('Ви ще не створили жодного челенджу', 'You haven\'t created any challenges yet') : I18n.inline('Немає челенджів', 'No challenges'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'my' 
                ? I18n.inline('Створіть свій перший челендж!', 'Create your first challenge!')
                : I18n.inline('Зачекайте, поки з\'являться нові челенджі.', 'Wait for new challenges to appear.'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(Challenge c) {
    final challengeId = c.id;
    final title = c.title.isNotEmpty ? c.title : I18n.inline('Челендж', 'Challenge');
    final description = c.description;
    final creatorName =
        c.creatorName.isNotEmpty ? c.creatorName : I18n.inline('Невідомий', 'Unknown');
    final creatorVideoUrl = c.creatorVideoUrl ?? '';
    final creatorThumbnailUrl = c.creatorThumbnailUrl ?? c.imageUrl;
    final participants = c.participants.length;
    final submissions = c.submissions.length;
    final entryFee = c.entryFee;
    final actualPrizePool = participants * entryFee;
    final status = c.status.toString().split('.').last;
    final creatorId = c.creatorId;

    final now = DateTime.now();
    final targetDate = c.votingDeadline.isBefore(c.endDate) ? c.endDate : c.votingDeadline;
    final daysLeft = targetDate.difference(now).inDays.clamp(0, 999);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header з інформацією про челендж
          Container(
            padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
        ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      color: Colors.white,
                          fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
                const SizedBox(height: 6),
              Text(
                description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/player-profile',
                  arguments: {'playerId': creatorId, 'playerName': creatorName},
                ),
                child: UserChip(userId: creatorId, name: creatorName, showName: true, size: 20),
              ),
                const SizedBox(height: 8),
                // Статистика
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(I18n.inline('$participants відео', '$participants videos'), style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(I18n.inline('$daysLeft днів', '$daysLeft days'), style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 12),
                        const SizedBox(width: 4),
                        Text(I18n.inline('$actualPrizePool банк', '$actualPrizePool bank'), style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Контентна частина
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Верхня половина: відео творця челенджу (займає половину картки)
                VideoPreviewBox(
                  thumbnailUrl: creatorThumbnailUrl,
                  videoUrl: creatorVideoUrl,
                  aspectRatio: 16 / 9,
                  borderRadius: 12,
                  onTap: () => _playCreatorVideo(
                    creatorVideoUrl,
                    title,
                    creatorName,
                    challengeId,
                    creatorId,
                    thumbnailUrl: creatorThumbnailUrl,
                  ),
                  topRight: _buildCreatorRatingBadge(challengeId),
                  bottomLeft: _buildCreatorLabel(creatorName),
                ),
            
                const SizedBox(height: 12),

                // Нижня половина: слайдер з відео учасників
            if (submissions > 0) ...[
              Text(
                I18n.inline('Відео учасників:', 'Participant videos:'),
                style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: StreamBuilder<List<ChallengeSubmissionEntry>>(
                  stream: context.read<ChallengeRepository>().watchSubmissions(challengeId).map(
                        (list) => list.where((s) => !s.isCreatorVideo).take(8).toList(),
                      ),
                  builder: (context, submissionSnapshot) {
                    if (!submissionSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }

                    final submissionDocs = submissionSnapshot.data!;

                    if (submissionDocs.isEmpty) {
                      return Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Center(
                          child: Text(
                            I18n.inline('Поки немає відео учасників', 'No participant videos yet'),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          submissionDocs.length + (submissionDocs.length < submissions ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < submissionDocs.length) {
                          final s = submissionDocs[index];
                          final authorName =
                              s.authorName.isNotEmpty ? s.authorName : I18n.t('participant');
                          final submissionUserId = s.userId;
                          final videoUrl = s.videoUrl;
                          final submissionId = s.userId;
                          final submissionThumb = s.thumbnailUrl;

                          return GestureDetector(
                            onTap: () => _playParticipantVideo(
                              videoUrl: videoUrl,
                              title: s.title.isNotEmpty
                                  ? s.title
                                  : I18n.inline('Відео учасника', 'Participant video'),
                              authorName: authorName,
                              challengeId: challengeId,
                              submissionId: submissionId,
                              thumbnailUrl: submissionThumb,
                            ),
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: FutureBuilder(
                                future: context
                                    .read<UserProfileRepository>()
                                    .loadProfile(submissionUserId),
                                builder: (context, userSnapshot) {
                                  final snap = userSnapshot.data;
                                  final avatarUrl = snap?.avatarUrl ?? '';

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/player-profile',
                                            arguments: {
                                              'playerId': submissionUserId,
                                              'playerName': authorName,
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: avatarUrl.isNotEmpty
                                                ? FlapCachedImage(
                                                    imageUrl: avatarUrl,
                                                    width: 32,
                                                    height: 32,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        _buildMiniAvatar(authorName),
                                                  )
                                                : _buildMiniAvatar(authorName),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        authorName.length > 8
                                            ? '${authorName.substring(0, 8)}...'
                                            : authorName,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        } else {
                          final remainingCount = submissions - submissionDocs.length;
                          return Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4caf50).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF4caf50)),
                            ),
                            child: Center(
                              child: Text(
                                '+$remainingCount',
                                style: const TextStyle(
                                  color: Color(0xFF4caf50),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
                ] else ...[
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Center(
                      child: Text(
                        I18n.inline('Поки немає відео учасників', 'No participant videos yet'),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),

                // Кнопки дій
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _joinChallenge(challengeId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4caf50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(I18n.t('join'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _viewChallengeDetails(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(I18n.inline('📹 Переглянути ($submissions)', '📹 View ($submissions)'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (AppAuthContext.userId == creatorId && status == 'voting') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _finishChallenge(challengeId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(I18n.t('finish_match'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
            ),
          ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'recruiting':
        return I18n.inline('Набір', 'Recruitment');
      case 'submission':
        return I18n.inline('Подача відео', 'Video Submission');
      case 'voting':
        return I18n.inline('Голосування', 'Voting');
      case 'completed':
        return I18n.t('status_finished');
      default:
        return I18n.inline('Активний', 'Active');
    }
  }

  void _playCreatorVideo(
    String videoUrl,
    String title,
    String creatorName,
    String challengeId,
    String creatorSubmissionUserId, {
    String? thumbnailUrl,
  }) {
    print('Playing creator video: $videoUrl');
    if (videoUrl.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChallengeVideoPlayerScreen(
            videoUrl: videoUrl,
            title: I18n.inline('Відео творця: $title', 'Creator video: $title'),
            authorName: creatorName,
            challengeId: challengeId,
            submissionId: creatorSubmissionUserId,
            thumbnailUrl: thumbnailUrl,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${I18n.t('video_upload_failed')}: "$videoUrl"'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _joinChallenge(String challengeId) async {
    try {
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) return;

      final loaded = await context.read<ChallengeRepository>().getChallenge(challengeId);
      if (loaded == null) {
        throw Exception(I18n.inline('Челендж не знайдено', 'Challenge not found'));
      }
      final entryFee = loaded.entryFee;
      final challengeTitle =
          loaded.title.isNotEmpty ? loaded.title : I18n.inline('Челендж', 'Challenge');

      // Показуємо діалог підтвердження оплати
      final shouldJoin = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  I18n.inline('Підтвердження участі', 'Confirmation of participation'),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${I18n.inline('Челендж', 'Challenge')}: $challengeTitle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  I18n.inline('Вартість участі: $entryFee монет', 'Participation fee: $entryFee coins'),
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18n.inline('Після оплати ви зможете завантажити своє відео та взяти участь у голосуванні.', 'After payment you will be able to upload your video and participate in voting.'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  I18n.t('cancel'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4caf50),
                  foregroundColor: Colors.white,
                ),
                child: Text('${I18n.t('pay')} $entryFee ${I18n.t('coins')}'),
              ),
            ],
          );
        },
      );

      if (shouldJoin == true) {
        await context.read<ChallengeRepository>().joinChallenge(challengeId);
        
        // Показуємо повідомлення про успіх
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(I18n.inline('✅ Ви приєдналися до челенджу! Списано $entryFee монет.', '✅ You joined the challenge! $entryFee coins deducted.'))),
              ],
            ),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );
        
        // Потім переходимо на завантаження відео
    Navigator.pushNamed(
      context,
      '/video-upload',
      arguments: {
        'challengeId': challengeId,
            'challengeTitle': challengeTitle,
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewChallengeDetails(Challenge challenge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeDetailsScreen(challenge: challenge),
      ),
    );
  }

  void _showParticipants(Map<String, dynamic> challengeData) {
    final participants = List<String>.from(challengeData['participants'] ?? []);
    final creatorId = challengeData['creatorId'] ?? '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Учасники челенджу (${participants.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              // Participants list
              Expanded(
                child: participants.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Поки немає учасників',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final participantId = participants[index];
                          return FutureBuilder(
                            future: context.read<UserProfileRepository>().loadProfile(participantId),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(0xFF4caf50),
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(I18n.t('loading'), style: TextStyle(color: Colors.white)),
                                );
                              }

                              final prof = snapshot.data!;
                              final userName = prof.resolveDisplayName().isNotEmpty
                                  ? prof.resolveDisplayName()
                                  : I18n.inline('Користувач', 'User');
                              final avatarUrl = prof.avatarUrl ?? '';
                              final rating = prof.rating ?? 0.0;
                              final city = prof.city ?? I18n.inline('Невідоме місто', 'Unknown city');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(
                                      context,
                                      '/player-profile',
                                      arguments: {
                                        'playerId': participantId,
                                        'playerName': userName,
                                      },
                                    );
                                  },
                                  leading: PlayerAvatarButton(
                                    userId: participantId,
                                    displayName: userName,
                                    avatarUrl: avatarUrl,
                                    size: 40,
                                  ),
                                  title: Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        city,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Color(0xFF4caf50), size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            rating.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Color(0xFF4caf50),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: participantId == creatorId
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4caf50).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Творець',
                                            style: TextStyle(
                                              color: Color(0xFF4caf50),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _playParticipantVideo({
    required String videoUrl,
    required String title,
    required String authorName,
    required String challengeId,
    required String submissionId,
    String? thumbnailUrl,
  }) {
    if (videoUrl.isNotEmpty) {
      // Відкриваємо відео учасника з голосуванням (1 повзунок)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChallengeVideoPlayerScreen(
            videoUrl: videoUrl,
            title: title,
            authorName: authorName,
            challengeId: challengeId,
            submissionId: submissionId,
            thumbnailUrl: thumbnailUrl,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.t('video_upload_failed')),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildMiniAvatar(String name) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF4caf50),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorLabel(String creatorName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        I18n.inline('Відео від $creatorName', 'Video from $creatorName'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCreatorRatingBadge(String challengeId) {
    return StreamBuilder<List<ChallengeSubmissionEntry>>(
      stream: context.read<ChallengeRepository>().watchSubmissions(challengeId).map(
            (list) => list.where((s) => s.isCreatorVideo).take(1).toList(),
          ),
      builder: (context, snap) {
        double avg = 0;
        if (snap.hasData && snap.data!.isNotEmpty) {
          avg = snap.data!.first.averageRating;
        }
        if (avg <= 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
              const SizedBox(width: 4),
              Text(
                avg.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishChallenge(String challengeId) async {
    try {
      await context.read<ChallengeRepository>().completeChallenge(challengeId);
      final updated = await context.read<ChallengeRepository>().getChallenge(challengeId);
      final winners = updated?.winners ?? [];

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0f0f23),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆 Переможці', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...List.generate(winners.length, (i) => _winnerTile(winners[i], place: i + 1)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(I18n.t('done')),
                )
              ],
            ),
          );
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('✅ Челендж завершено. Нараховано призи переможцям.', '✅ Challenge completed. Prizes credited.'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('❌ Помилка завершення: $e', '❌ Finish error: $e'))),
      );
    }
  }

  Widget _winnerTile(String userId, {required int place}) {
    return FutureBuilder(
      future: context.read<UserProfileRepository>().loadProfile(userId),
      builder: (context, snap) {
        final prof = snap.data;
        final name = prof != null && prof.resolveDisplayName().isNotEmpty
            ? prof.resolveDisplayName()
            : I18n.inline('Користувач', 'User');
        final avatar = prof?.avatarUrl ?? '';
        final medal = place == 1 ? '🥇' : place == 2 ? '🥈' : '🥉';
        return ListTile(
          onTap: () => Navigator.pushNamed(context, '/player-profile', arguments: {'playerId': userId, 'playerName': name}),
          leading: PlayerAvatarButton(
            userId: userId,
            displayName: name,
            avatarUrl: avatar,
            size: 36,
          ),
          title: Text('$medal $name', style: const TextStyle(color: Colors.white)),
          subtitle: Text('Місце: $place', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        );
      },
    );
  }
}

