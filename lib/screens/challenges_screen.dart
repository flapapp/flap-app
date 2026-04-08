import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import 'challenge_create_screen.dart';
import 'challenge_details_screen.dart';
import 'video_player_screen.dart';
import 'challenge_video_player_screen.dart';
import '../widgets/user_chip.dart';
import '../utils/i18n.dart';
import '../widgets/video_preview_box.dart';
import '../widgets/player_avatar_button.dart';
import '../core/app_auth_context.dart';

class ChallengesScreen extends StatefulWidget {
  final bool showOnlyMyChallenges;

  const ChallengesScreen({Key? key, this.showOnlyMyChallenges = false}) : super(key: key);

  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final ChallengeService _challengeService = ChallengeService();
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _getChallengesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final all = snapshot.data!.docs;
                final currentUser = AppAuthContext.currentUser;
                final filtered = all.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  switch (_selectedFilter) {
                    case 'active':
                      final status = (data['status'] ?? '').toString();
                      return status == 'recruiting' || status == 'submission' || status == 'voting';
                    case 'my':
                      if (currentUser == null) return false;
                      return (data['creatorId'] ?? '') == currentUser.id;
                    case 'completed':
                      return (data['status'] ?? '') == 'completed';
                    default:
                      return true;
                  }
                }).toList()
                ..sort((a, b) {
                  final ad = a.data() as Map<String, dynamic>;
                  final bd = b.data() as Map<String, dynamic>;
                  switch (_selectedSort) {
                    case 'rating':
                      final ar = (ad['averageRating'] ?? 0.0) as num; // якщо є агрегований рейтинг
                      final br = (bd['averageRating'] ?? 0.0) as num;
                      return br.compareTo(ar);
                    case 'views':
                      final av = (ad['views'] ?? 0) as num;
                      final bv = (bd['views'] ?? 0) as num;
                      return bv.compareTo(av);
                    case 'new':
                    default:
                      final at = ad['createdAt'];
                      final bt = bd['createdAt'];
                      if (at is Timestamp && bt is Timestamp) {
                        return bt.compareTo(at);
                      }
                      return 0;
                  }
                });
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final challengeData = filtered[index].data() as Map<String, dynamic>;
                    challengeData['id'] = filtered[index].id;
                    return _buildChallengeCard(challengeData);
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

  Stream<QuerySnapshot> _getChallengesStream() {
    // Базовий потік усіх челенджів, далі фільтр на клієнті для стабільності
    return FirebaseFirestore.instance
        .collection('challenges')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
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

  Widget _buildChallengeCard(Map<String, dynamic> challengeData) {
    final challengeId = challengeData['id'];
    final title = challengeData['title'] ?? I18n.inline('Челендж', 'Challenge');
    final description = challengeData['description'] ?? '';
    final creatorName = challengeData['creatorName'] ?? I18n.inline('Невідомий', 'Unknown');
    final creatorVideoUrl = challengeData['creatorVideoUrl'] ?? '';
    final creatorThumbnailUrl = challengeData['creatorThumbnailUrl'] ?? challengeData['thumbnailUrl'];
    final participants = (challengeData['participants'] as List?)?.length ?? 0;
    final submissions = (challengeData['submissions'] as List?)?.length ?? 0;
    final entryFee = challengeData['entryFee'] ?? 10;
    final actualPrizePool = participants * entryFee; // Реальний призовий фонд
    final status = challengeData['status'] ?? 'recruiting';
    final endDate = challengeData['endDate'] as Timestamp?;
    final votingDeadline = challengeData['votingDeadline'] as Timestamp?;
    final creatorId = challengeData['creatorId'] ?? '';
    
    print('Challenge $challengeId: creatorVideoUrl = "$creatorVideoUrl"');
    print('Challenge $challengeId: title = "$title"');
    print('Challenge $challengeId: creatorName = "$creatorName"');
    print('Challenge $challengeId: participants = $participants');
    print('Challenge $challengeId: submissions = $submissions');
    
    final now = DateTime.now();
    final targetDate = (votingDeadline ?? endDate)?.toDate();
    final daysLeft = targetDate != null
        ? targetDate.difference(now).inDays.clamp(0, 999)
        : 0;

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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('challenges')
                      .doc(challengeId)
                      .collection('submissions')
                          .where('isCreatorVideo', isEqualTo: false)
                          .limit(8)
                      .snapshots(),
                  builder: (context, submissionSnapshot) {
                    if (!submissionSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    
                    final submissionDocs = submissionSnapshot.data!.docs;
                        
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
                          itemCount: submissionDocs.length + (submissionDocs.length < submissions ? 1 : 0), // +1 для показу кількості
                      itemBuilder: (context, index) {
                            if (index < submissionDocs.length) {
                        final submissionData = submissionDocs[index].data() as Map<String, dynamic>;
                              final authorName = submissionData['authorName'] ?? I18n.t('participant');
                              final submissionUserId = submissionData['userId'] ?? '';
                              final videoUrl = submissionData['videoUrl'] ?? '';
                              final submissionId = submissionDocs[index].id;
                              final submissionThumb = (submissionData['thumbnailUrl'] ?? '').toString();
                              
                        return GestureDetector(
                          onTap: () => _playParticipantVideo(
                            videoUrl: videoUrl,
                            title: submissionData['title'] ?? I18n.inline('Відео учасника', 'Participant video'),
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
                                  child: FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(submissionUserId)
                                        .get(),
                                    builder: (context, userSnapshot) {
                                      final userData = userSnapshot.hasData 
                                          ? userSnapshot.data!.data() as Map<String, dynamic>? ?? {}
                                          : <String, dynamic>{};
                                      final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
                                      
                                      return Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Avatar clickable to profile
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
                                                    ? Image.network(
                                                        avatarUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) =>
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
                              // Показуємо кількість якщо є більше відео
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
                    onPressed: () => _viewChallengeDetails(challengeId, challengeData),
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
    String challengeId, {
    String? thumbnailUrl,
  }) {
    print('Playing creator video: $videoUrl');
    if (videoUrl.isNotEmpty) {
      // Відкриваємо відео творця з голосуванням (як учасника челенджу)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChallengeVideoPlayerScreen(
            videoUrl: videoUrl,
            title: I18n.inline('Відео творця: $title', 'Creator video: $title'),
            authorName: creatorName,
            challengeId: challengeId,
            submissionId: 'creator', // Спеціальний ID для відео творця
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

      // Отримуємо дані челенджу для показу вартості
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();
      
      if (!challengeDoc.exists) {
        throw Exception(I18n.inline('Челендж не знайдено', 'Challenge not found'));
      }
      
      final challengeData = challengeDoc.data() as Map<String, dynamic>;
      final entryFee = challengeData['entryFee'] ?? 10;
      final challengeTitle = challengeData['title'] ?? I18n.inline('Челендж', 'Challenge');

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
        // Приєднуємося до челенджу (платимо вступну плату)
        await _challengeService.joinChallenge(challengeId);
        
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

  void _viewChallengeDetails(String challengeId, Map<String, dynamic> challengeData) {
    try {
      final challenge = Challenge(
        id: challengeId,
        title: challengeData['title'] ?? '',
        description: challengeData['description'] ?? '',
        type: parseChallengeType(challengeData['type'] as String?),
        audience: ChallengeAudience.values.firstWhere(
          (e) => e.toString().split('.').last == challengeData['audience'],
          orElse: () => ChallengeAudience.city,
        ),
        creatorId: challengeData['creatorId'] ?? '',
        creatorName: challengeData['creatorName'] ?? '',
        creatorVideoUrl: challengeData['creatorVideoUrl'],
        city: challengeData['city'] ?? '',
        entryFee: challengeData['entryFee'] ?? 10,
        duration: challengeData['duration'] ?? 7,
        createdAt: challengeData['createdAt'] != null
            ? (challengeData['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        startDate: challengeData['startDate'] != null
            ? (challengeData['startDate'] as Timestamp).toDate()
            : DateTime.now(),
        submissionDeadline: challengeData['submissionDeadline'] != null
            ? (challengeData['submissionDeadline'] as Timestamp).toDate()
            : DateTime.now().add(const Duration(days: 7)),
        votingDeadline: challengeData['votingDeadline'] != null
            ? (challengeData['votingDeadline'] as Timestamp).toDate()
            : DateTime.now().add(const Duration(days: 14)),
        endDate: challengeData['endDate'] != null
            ? (challengeData['endDate'] as Timestamp).toDate()
            : DateTime.now().add(const Duration(days: 19)),
        status: ChallengeStatus.values.firstWhere(
          (e) => e.toString().split('.').last == challengeData['status'],
          orElse: () => ChallengeStatus.recruiting,
        ),
        maxParticipants: challengeData['maxParticipants'] ?? 50,
        currentParticipants: challengeData['currentParticipants'] ?? 0,
        prizePool: (challengeData['prizePool'] ?? 0.0).toDouble(),
        participants: List<String>.from(challengeData['participants'] ?? []),
        submissions: List<String>.from(challengeData['submissions'] ?? []),
        votes: Map<String, double>.from(challengeData['votes'] ?? {}),
        detailedVotes: Map<String, Map<String, double>>.from(challengeData['detailedVotes'] ?? {}),
        winners: List<String>.from(challengeData['winners'] ?? []),
        finalScores: Map<String, double>.from(challengeData['finalScores'] ?? {}),
        isActive: challengeData['isActive'] ?? true,
        tags: List<String>.from(challengeData['tags'] ?? []),
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChallengeDetailsScreen(challenge: challenge),
        ),
      );
    } catch (e) {
      print('Error creating Challenge object: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('error'))),
      );
    }
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
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(participantId)
                                .get(),
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

                              final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                              final userName = userData['displayName'] ?? userData['name'] ?? userData['email']?.split('@')[0] ?? 'Користувач';
                              final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
                              final rating = (userData['rating'] ?? 0.0).toDouble();
                              final city = userData['city'] ?? 'Невідоме місто';

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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .collection('submissions')
          .where('isCreatorVideo', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        double avg = 0;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final data = snap.data!.docs.first.data() as Map<String, dynamic>;
          avg = (data['averageRating'] ?? data['rating'] ?? 0.0).toDouble();
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
      final ok = await ChallengeService().completeChallenge(challengeId);
      if (!ok) return;

      // Reload winners and show
      final doc = await FirebaseFirestore.instance.collection('challenges').doc(challengeId).get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final winners = List<String>.from(data['winners'] ?? []);

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
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snap) {
        final ud = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = ud['displayName'] ?? ud['name'] ?? ud['email']?.split('@')[0] ?? 'Користувач';
        final avatar = ud['avatarUrl'] ?? ud['avatar'] ?? '';
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

