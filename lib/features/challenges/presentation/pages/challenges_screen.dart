import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../router/app_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/supabase/supabase_date.dart';
import '../../domain/repositories/challenges_repository.dart';
import '../../data/models/challenge.dart';
import '../../../../widgets/user_chip.dart';
import '../../../../widgets/video_preview_box.dart';
import '../../../../widgets/player_avatar_button.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/city_localization.dart';

class ChallengesScreen extends StatefulWidget {
  final bool showOnlyMyChallenges;

  const ChallengesScreen({Key? key, this.showOnlyMyChallenges = false}) : super(key: key);

  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  ChallengesRepository get _challengesRepo => sl<ChallengesRepository>();

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
                  _buildFilterChip(tr('all'), 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip(tr('active_challenges'), 'active'),
                  const SizedBox(width: 8),
                  _buildFilterChip(tr('my_challenges'), 'my'),
                  const SizedBox(width: 8),
                  _buildFilterChip(tr('completed_challenges'), 'completed'),
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
                        DropdownMenuItem(value: 'new', child: Text(tr('il_18fdd549b2'))),
                        DropdownMenuItem(value: 'rating', child: Text(tr('il_9f29530464'))),
                        DropdownMenuItem(value: 'views', child: Text(tr('il_69c404591e'))),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getChallengesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final all = snapshot.data!;
                final currentUser = AppAuth.currentUser;
                final filtered = all.where((data) {
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
                ..sort((ad, bd) {
                  switch (_selectedSort) {
                    case 'rating':
                      final ar = (ad['averageRating'] ?? 0.0) as num; // When server provides aggregate rating
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
                      final adt = asDateTimeOrNull(at) ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bdt = asDateTimeOrNull(bt) ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return bdt.compareTo(adt);
                  }
                });
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final challengeData = filtered[index];
                    return _buildChallengeCard(challengeData);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // No FloatingActionButton here — MainScreen already provides one
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

  Stream<List<Map<String, dynamic>>> _getChallengesStream() {
    return _sb
        .from('challenges')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows.map(_mapChallengeRow).toList());
  }

  Map<String, dynamic> _mapChallengeRow(Map<String, dynamic> row) {
    return <String, dynamic>{
      'id': row['id']?.toString() ?? '',
      'title': row['title'],
      'description': row['description'],
      'creatorId': row['creator_id']?.toString() ?? '',
      'creatorName': row['creator_name'] ?? '',
      'creatorVideoUrl': row['video_url'] ?? row['creator_video_url'],
      'creatorThumbnailUrl': row['video_thumbnail_url'] ??
          row['creator_thumbnail_url'] ??
          row['thumbnail_url'],
      'thumbnailUrl': row['video_thumbnail_url'] ?? row['thumbnail_url'],
      'participants': row['participants'] ?? const <String>[],
      'submissions': row['submissions'] ?? const <String>[],
      'entryFee': row['entry_fee'] ?? 10,
      'status': row['status'] ?? 'recruiting',
      'endDate': row['ends_at'] ?? row['end_date'],
      'votingDeadline': row['voting_deadline'],
      'type': row['type'] ?? row['challenge_type'] ?? 'goal',
      'audience': row['audience'] ?? 'city',
      'city': row['city'] ?? '',
      'duration': challengeDurationDaysFromRow(
        Map<String, dynamic>.from(row),
      ),
      'createdAt': row['created_at'],
      'startDate': row['starts_at'] ?? row['start_date'],
      'submissionDeadline': row['submission_deadline'],
      'maxParticipants': row['max_participants'] ?? 50,
      'currentParticipants': row['current_participants'] ?? 0,
      'prizePool': row['prize_pool'] ?? 0.0,
      'votes': row['votes'] ?? const <String, dynamic>{},
      'detailedVotes': row['detailed_votes'] ?? const <String, dynamic>{},
      'winners': row['winners'] ?? const <String>[],
      'finalScores': row['final_scores'] ?? const <String, dynamic>{},
      'isActive': row['is_active'] ?? true,
      'tags': row['tags'] ?? const <String>[],
      'views': row['views'] ?? 0,
      'averageRating': row['average_rating'] ?? row['rating'] ?? 0.0,
    };
  }

  int _daysLeftFromDeadline(Map<String, dynamic> challengeData) {
    final raw =
        challengeData['submissionDeadline'] ?? challengeData['endDate'];
    if (raw == null) return 0;
    DateTime? dt;
    if (raw is String) {
      dt = DateTime.tryParse(raw);
    } else if (raw is DateTime) {
      dt = raw;
    }
    if (dt == null) return 0;
    final d = dt.toLocal().difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
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
            _selectedFilter == 'my' ? tr('il_ca479b0647') : tr('il_e1bd3d8094'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'my' 
                ? tr('il_75c23f6f6c')
                : tr('il_f144c43943'),
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
    final title = challengeData['title'] ?? tr('il_27cf1792f7');
    final description = challengeData['description'] ?? '';
    final creatorName = challengeData['creatorName'] ?? tr('il_b764cdc0ea');
    final creatorVideoUrl = challengeData['creatorVideoUrl'] ?? '';
    final creatorThumbnailUrl = challengeData['creatorThumbnailUrl'] ?? challengeData['thumbnailUrl'];
    final participants = (challengeData['participants'] as List?)?.length ?? 0;
    final submissions = (challengeData['submissions'] as List?)?.length ?? 0;
    final status = challengeData['status'] ?? 'recruiting';
    final creatorId = challengeData['creatorId'] ?? '';
    final daysLeft = _daysLeftFromDeadline(challengeData);
    final prizePool = challengeData['prizePool'];
    final prizeLabel = prizePool is num ? prizePool.toStringAsFixed(0) : '$prizePool';
    
    print('Challenge $challengeId: creatorVideoUrl = "$creatorVideoUrl"');
    print('Challenge $challengeId: title = "$title"');
    print('Challenge $challengeId: creatorName = "$creatorName"');
    print('Challenge $challengeId: participants = $participants');
    print('Challenge $challengeId: submissions = $submissions');
    

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
          // Header with challenge info
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
                onTap: () => context.router.push(
                  PlayerProfileRoute(
                    playerId: creatorId,
                    playerName: creatorName,
                  ),
                ),
                child: UserChip(userId: creatorId, name: creatorName, showName: true, size: 20),
              ),
                const SizedBox(height: 8),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          tr('il_b1784e31d4', args: ['$participants']),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          tr('il_fdd1d3357a', args: ['$daysLeft']),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          tr('il_4fd5220eff', args: [prizeLabel]),
                          style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top half: creator video (half the card)
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

                // Bottom half: participant videos carousel
            if (submissions > 0) ...[
              Text(
                tr('il_740fb949c8'),
                style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sb
                      .from('challenge_submissions')
                      .stream(primaryKey: ['id'])
                      .eq('challenge_id', challengeId)
                      .order('submitted_at', ascending: false)
                      .limit(8)
                      .map((rows) => rows
                          .where((r) =>
                              (r['user_id'] ?? '').toString() != creatorId)
                          .toList()),
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
                                tr('il_2ff70e5905'),
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ),
                          );
                        }
                        
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                          itemCount: submissionDocs.length + (submissionDocs.length < submissions ? 1 : 0), // +1 tile for “more” count
                      itemBuilder: (context, index) {
                            if (index < submissionDocs.length) {
                        final submissionData = submissionDocs[index];
                              final authorName = submissionData['author_name'] ?? tr('participant');
                              final submissionUserId = (submissionData['user_id'] ?? '').toString();
                              final videoUrl = submissionData['video_url'] ?? '';
                              final submissionId = (submissionData['id'] ?? '').toString();
                              final submissionThumb = (submissionData['thumbnail_url'] ?? '').toString();
                              
                        return GestureDetector(
                          onTap: () => _playParticipantVideo(
                            videoUrl: videoUrl,
                            title: submissionData['title'] ?? tr('il_163be06a12'),
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
                                  child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Avatar clickable to profile
                                          GestureDetector(
                                            onTap: () {
                                              context.router.push(
                                                PlayerProfileRoute(
                                                  playerId: submissionUserId,
                                                  playerName: authorName,
                                                ),
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
                                                child: _buildMiniAvatar(authorName),
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
                                      ),
                                ),
                        );
                            } else {
                              // Show count when more videos exist
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
                        tr('il_2ff70e5905'),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),

                // Action buttons
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
                    child: Text(tr('join'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    child: Text(
                      tr('il_1eb956dc4f', args: ['$submissions']),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (AppAuth.currentUserId == creatorId && status == 'voting') ...[
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
                      child: Text(tr('finish_match'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
        return tr('il_9396ed8f29');
      case 'submission':
        return tr('il_363f2af67f');
      case 'voting':
        return tr('il_aca2f665db');
      case 'completed':
        return tr('status_finished');
      default:
        return tr('il_9234069589');
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
      // Open creator video with voting (as challenge participant)
      context.router.push(
        ChallengeVideoPlayerRoute(
          videoUrl: videoUrl,
          title: tr('il_11349005b0', namedArgs: {'title': title}),
          authorName: creatorName,
          challengeId: challengeId,
          submissionId: 'creator',
          thumbnailUrl: thumbnailUrl,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('video_upload_failed')}: "$videoUrl"'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _joinChallenge(String challengeId) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) return;

      // Load challenge for entry fee display
      final challengeData = await _sb
          .from('challenges')
          .select('title, entry_fee')
          .eq('id', challengeId)
          .maybeSingle();
      if (challengeData == null) {
        throw Exception(tr('il_a29799fa76'));
      }

      final entryFee = challengeData['entry_fee'] ?? 10;
      final challengeTitle = challengeData['title'] ?? tr('il_27cf1792f7');

      // Show payment confirmation dialog
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
                  tr('il_38465c722b'),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tr('il_27cf1792f7')}: $challengeTitle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('il_41831034ba', args: ['$entryFee']),
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('il_7d798659ec'),
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
                  tr('cancel'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4caf50),
                  foregroundColor: Colors.white,
                ),
                child: Text('${tr('pay')} $entryFee ${tr('coins')}'),
              ),
            ],
          );
        },
      );

      if (shouldJoin == true) {
        // Join challenge (pay entry fee)
        await _challengesRepo.joinChallenge(challengeId);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tr('il_94f66b2517', args: ['$entryFee'])),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );
        
        // Then go to video upload
    context.router.push(
      VideoUploadRoute(
        challengeId: challengeId,
        challengeTitle: challengeTitle,
      ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('challenges_open_failed', namedArgs: {'error': e.toString()})),
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
        duration: challengeDurationDaysFromRow(
          Map<String, dynamic>.from(challengeData),
        ),
        createdAt: challengeData['createdAt'] != null
            ? (asDateTimeOrNull(challengeData['createdAt']) ?? DateTime.now())
            : DateTime.now(),
        startDate: challengeData['startDate'] != null
            ? (asDateTimeOrNull(challengeData['startDate']) ?? DateTime.now())
            : DateTime.now(),
        submissionDeadline: challengeData['submissionDeadline'] != null
            ? (asDateTimeOrNull(challengeData['submissionDeadline']) ??
                DateTime.now().add(const Duration(days: 7)))
            : DateTime.now().add(const Duration(days: 7)),
        votingDeadline: challengeData['votingDeadline'] != null
            ? (asDateTimeOrNull(challengeData['votingDeadline']) ??
                DateTime.now().add(const Duration(days: 14)))
            : DateTime.now().add(const Duration(days: 14)),
        endDate: challengeData['endDate'] != null
            ? (asDateTimeOrNull(challengeData['endDate']) ??
                DateTime.now().add(const Duration(days: 19)))
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
      
      context.router.push(ChallengeDetailsRoute(challenge: challenge));
    } catch (e) {
      print('Error creating Challenge object: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('error'))),
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
                        tr(
                          'challenge_participants_title',
                          namedArgs: {'count': '${participants.length}'},
                        ),
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
                    ? Center(
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
                              tr('challenge_no_participants_yet'),
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
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _sb
                                .from('profiles')
                                .select('display_name,avatar_url,rating,city,email')
                                .eq('id', participantId)
                                .maybeSingle(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(0xFF4caf50),
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(tr('loading'), style: TextStyle(color: Colors.white)),
                                );
                              }

                              final userData = snapshot.data ?? {};
                              final userName = userData['display_name'] ??
                                  userData['email']?.toString().split('@')[0] ??
                                  tr('il_b512d97e7c');
                              final avatarUrl = userData['avatar_url'] ?? '';
                              final rating = (userData['rating'] ?? 0.0).toDouble();
                              final city = localizeCity(
                                (userData['city'] ?? '').toString(),
                              );

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
                                    context.router.push(
                                      PlayerProfileRoute(
                                        playerId: participantId,
                                        playerName: userName,
                                      ),
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
                                          child: Text(
                                            tr('il_88447b8309'),
                                            style: const TextStyle(
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
      // Open participant video with voting (single slider)
      context.router.push(
        ChallengeVideoPlayerRoute(
          videoUrl: videoUrl,
          title: title,
          authorName: authorName,
          challengeId: challengeId,
          submissionId: submissionId,
          thumbnailUrl: thumbnailUrl,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('video_upload_failed')),
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
        tr('il_a3b4c4cfcd', namedArgs: {'creatorName': creatorName}),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCreatorRatingBadge(String challengeId) {
    return FutureBuilder<double>(
      future: _creatorAvgRating(challengeId),
      builder: (context, snap) {
        final avg = snap.data ?? 0.0;
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

  Future<double> _creatorAvgRating(String challengeId) async {
    final subs = await _sb
        .from('challenge_submissions')
        .select('id')
        .eq('challenge_id', challengeId)
        .order('submitted_at', ascending: true)
        .limit(1);
    final subRows = subs as List<dynamic>;
    if (subRows.isEmpty) return 0.0;
    final subId = ((subRows.first as Map<String, dynamic>)['id'] ?? '').toString();
    if (subId.isEmpty) return 0.0;
    final ratings = await _sb
        .from('challenge_submission_ratings')
        .select('overall_rating')
        .eq('challenge_submission_id', subId);
    final rows = ratings as List<dynamic>;
    if (rows.isEmpty) return 0.0;
    final total = rows.fold<double>(
      0,
      (p, e) => p + (((e as Map<String, dynamic>)['overall_rating'] as num?) ?? 0).toDouble(),
    );
    return total / rows.length;
  }

  Future<void> _finishChallenge(String challengeId) async {
    try {
      final ok = await _challengesRepo.completeChallenge(challengeId);
      if (!ok) return;

      // Reload winners from prize places (set when challenge is finalized)
      final prizeRows = await _sb
          .from('challenge_prize_places')
          .select('winner_user_id, place')
          .eq('challenge_id', challengeId)
          .order('place', ascending: true);
      final winners = (prizeRows as List<dynamic>)
          .map(
            (r) =>
                (r as Map<String, dynamic>)['winner_user_id']?.toString() ?? '',
          )
          .where((id) => id.isNotEmpty)
          .toList();

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
                Text(tr('challenge_winners'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...List.generate(winners.length, (i) => _winnerTile(winners[i], place: i + 1)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('done')),
                )
              ],
            ),
          );
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_569817ca4b'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_4b0700b8b6', namedArgs: {'e': e.toString()}),
          ),
        ),
      );
    }
  }

  Widget _winnerTile(String userId, {required int place}) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _sb
          .from('profiles')
          .select('display_name,avatar_url,email')
          .eq('id', userId)
          .maybeSingle(),
      builder: (context, snap) {
        final ud = snap.data ?? {};
        final name = ud['display_name'] ??
            ud['email']?.toString().split('@')[0] ??
            tr('il_b512d97e7c');
        final avatar = ud['avatar_url'] ?? '';
        final medal = place == 1 ? '🥇' : place == 2 ? '🥈' : '🥉';
        return ListTile(
          onTap: () => context.router.push(
            PlayerProfileRoute(
              playerId: userId,
              playerName: name.toString(),
            ),
          ),
          leading: PlayerAvatarButton(
            userId: userId,
            displayName: name,
            avatarUrl: avatar,
            size: 36,
          ),
          title: Text('$medal $name', style: const TextStyle(color: Colors.white)),
          subtitle: Text(tr('place_rank', args: ['$place']), style: TextStyle(color: Colors.white.withOpacity(0.7))),
        );
      },
    );
  }
}

