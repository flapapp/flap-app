import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import 'challenge_create_screen.dart';
import 'challenge_details_screen.dart';
import 'video_player_screen.dart';

class ChallengesScreen extends StatefulWidget {
  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final ChallengeService _challengeService = ChallengeService();
  String _selectedFilter = 'all'; // all, active, my, completed
  
  @override
  Widget build(BuildContext context) {
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
                  _buildFilterChip('Всі', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Активні', 'active'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Мої', 'my'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Завершені', 'completed'),
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

                final challenges = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: challenges.length,
                  itemBuilder: (context, index) {
                    final challengeData = challenges[index].data() as Map<String, dynamic>;
                    challengeData['id'] = challenges[index].id;
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
    final currentUser = FirebaseAuth.instance.currentUser;
    Query query = FirebaseFirestore.instance.collection('challenges');

    switch (_selectedFilter) {
      case 'active':
        query = query.where('status', whereIn: ['recruiting', 'submission', 'voting']);
        break;
      case 'my':
        if (currentUser != null) {
          query = query.where('creatorId', isEqualTo: currentUser.uid);
        }
        break;
      case 'completed':
        query = query.where('status', isEqualTo: 'completed');
        break;
      default: // all
        query = query.where('isActive', isEqualTo: true);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
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
            _selectedFilter == 'my' ? 'Ви ще не створили жодного челенджу' : 'Немає челенджів',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'my' 
                ? 'Створіть свій перший челендж!'
                : 'Зачекайте, поки з\'являться нові челенджі.',
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
    final title = challengeData['title'] ?? 'Челендж';
    final description = challengeData['description'] ?? '';
    final creatorName = challengeData['creatorName'] ?? 'Невідомий';
    final creatorVideoUrl = challengeData['creatorVideoUrl'] ?? '';
    final thumbnailUrl = challengeData['thumbnailUrl'];
    final participants = (challengeData['participants'] as List?)?.length ?? 0;
    final submissions = (challengeData['submissions'] as List?)?.length ?? 0;
    final entryFee = challengeData['entryFee'] ?? 10;
    final status = challengeData['status'] ?? 'recruiting';
    final endDate = challengeData['endDate'] as Timestamp?;
    
    final daysLeft = endDate != null 
        ? endDate.toDate().difference(DateTime.now()).inDays.clamp(0, 999)
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4caf50).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Автор: $creatorName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const SizedBox(height: 16),

            // Creator video section (half of the card)
            GestureDetector(
              onTap: () => _playCreatorVideo(creatorVideoUrl, title, creatorName),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  image: thumbnailUrl != null && thumbnailUrl.toString().isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(thumbnailUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    if (thumbnailUrl == null || thumbnailUrl.toString().isEmpty)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.black.withOpacity(0.3),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    
                    // Play button overlay
                    if (creatorVideoUrl.isNotEmpty)
                      const Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    
                    // Video info overlay
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Відео від $creatorName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Submissions gallery (horizontal slider)
            if (submissions > 0) ...[
              const Text(
                'Відео учасників:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
                      .limit(5)
                      .snapshots(),
                  builder: (context, submissionSnapshot) {
                    if (!submissionSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final submissionDocs = submissionSnapshot.data!.docs;
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: submissionDocs.length,
                      itemBuilder: (context, index) {
                        final submissionData = submissionDocs[index].data() as Map<String, dynamic>;
                        return Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Stats row
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showParticipants(challengeData),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$participants учасників',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$submissions відео',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$daysLeft днів',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$entryFee монет',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _joinChallenge(challengeId),
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Прийняти участь'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewChallengeDetails(challengeId, challengeData),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: Text('Переглянути ($submissions)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'recruiting':
        return 'Набір';
      case 'submission':
        return 'Подача відео';
      case 'voting':
        return 'Голосування';
      case 'completed':
        return 'Завершено';
      default:
        return 'Активний';
    }
  }

  void _playCreatorVideo(String videoUrl, String title, String creatorName) {
    if (videoUrl.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: videoUrl,
            title: title,
            authorName: creatorName,
            videoId: '',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Відео творця ще завантажується...'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _joinChallenge(String challengeId) {
    Navigator.pushNamed(
      context,
      '/video-upload',
      arguments: {
        'challengeId': challengeId,
        'challengeTitle': 'Челендж',
      },
    );
  }

  void _viewChallengeDetails(String challengeId, Map<String, dynamic> challengeData) {
    try {
      final challenge = Challenge(
        id: challengeId,
        title: challengeData['title'] ?? '',
        description: challengeData['description'] ?? '',
        type: ChallengeType.values.firstWhere(
          (e) => e.toString().split('.').last == challengeData['type'],
          orElse: () => ChallengeType.technical,
        ),
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
        const SnackBar(content: Text('Помилка відкриття челенджу')),
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
                                return const ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(0xFF4caf50),
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text('Завантаження...', style: TextStyle(color: Colors.white)),
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
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                    backgroundColor: const Color(0xFF4caf50),
                                    child: avatarUrl.isEmpty ? Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                    ) : null,
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
                                            rating.toStringAsFixed(1),
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
}
