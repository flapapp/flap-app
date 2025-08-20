import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import 'video_upload_screen.dart';
import 'challenge_voting_screen.dart';
import 'video_player_screen.dart';

class ChallengeDetailsScreen extends StatefulWidget {
  final Challenge challenge;
  
  const ChallengeDetailsScreen({Key? key, required this.challenge}) : super(key: key);

  @override
  _ChallengeDetailsScreenState createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isJoining = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final isCreator = currentUser?.uid == widget.challenge.creatorId;
    final isParticipant = widget.challenge.participants.contains(currentUser?.uid);
    final hasSubmitted = widget.challenge.submissions.contains(currentUser?.uid);

    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      body: CustomScrollView(
        slivers: [
          // App Bar з зображенням
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1e7d32),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.challenge.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1e7d32),
                      const Color(0xFF1e7d32).withOpacity(0.8),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.challenge.typeIcon,
                    style: const TextStyle(fontSize: 80),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Основний контент
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Статус та тип
                  _buildStatusSection(),
                  const SizedBox(height: 20),

                  // Опис
                  _buildDescriptionSection(),
                  const SizedBox(height: 20),

                  // Статистика
                  _buildStatsSection(),
                  const SizedBox(height: 20),

                  // Етапи
                  _buildStagesSection(),
                  const SizedBox(height: 20),

                  // Призовий фонд
                  _buildPrizeSection(),
                  const SizedBox(height: 20),

                  // Дії користувача
                  if (!isCreator) _buildUserActionsSection(
                    isParticipant: isParticipant,
                    hasSubmitted: hasSubmitted,
                  ),

                  // Учасники
                  _buildParticipantsSection(),
                  const SizedBox(height: 20),

                  // Відео (якщо є)
                  if (widget.challenge.submissions.isNotEmpty)
                    _buildVideosSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color(widget.challenge.statusColor).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Color(widget.challenge.statusColor)),
          ),
          child: Text(
            widget.challenge.statusText,
            style: TextStyle(
              color: Color(widget.challenge.statusColor),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Text(
            widget.challenge.typeText,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📝 Опис',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.challenge.description,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Статистика',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('👥', 'Учасники', 
                  '${widget.challenge.currentParticipants}/${widget.challenge.maxParticipants}'),
              ),
              Expanded(
                child: _buildStatItem('🎬', 'Відео', 
                  '${widget.challenge.submissions.length}'),
              ),
              Expanded(
                child: _buildStatItem('💰', 'Призовий фонд', 
                  '${widget.challenge.prizePool.toInt()} монет'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('${widget.challenge.audienceIcon}', 'Аудиторія', 
                  widget.challenge.audienceText),
              ),
              Expanded(
                child: _buildStatItem('💸', 'Ставка входу', 
                  '${widget.challenge.entryFee} монет'),
              ),
              Expanded(
                child: _buildStatItem('⏰', 'Тривалість', 
                  '${widget.challenge.duration} дн.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String icon, String label, String value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStagesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⏰ Етапи',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStageItem('1️⃣', 'Збір учасників', 
            widget.challenge.startDate, widget.challenge.submissionDeadline, 
            Colors.green, widget.challenge.recruitmentProgress),
          _buildStageItem('2️⃣', 'Подання відео', 
            widget.challenge.submissionDeadline, widget.challenge.votingDeadline, 
            Colors.orange, widget.challenge.submissionProgress),
          _buildStageItem('3️⃣', 'Голосування', 
            widget.challenge.votingDeadline, widget.challenge.endDate, 
            Colors.blue, widget.challenge.votingProgress),
        ],
      ),
    );
  }

  Widget _buildStageItem(String icon, String title, DateTime start, DateTime end, 
      Color color, double progress) {
    final isActive = DateTime.now().isAfter(start) && DateTime.now().isBefore(end);
    final isCompleted = DateTime.now().isAfter(end);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? color : Colors.grey[600],
                  ),
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 8),
          Text(
            '${start.day}.${start.month} - ${end.day}.${end.month}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 Призовий фонд',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPrizeItem('🥇', '1-е місце', 
                  '${widget.challenge.firstPlacePrize.toInt()} монет', Colors.amber),
              ),
              Expanded(
                child: _buildPrizeItem('🥈', '2-е місце', 
                  '${widget.challenge.secondPlacePrize.toInt()} монет', Colors.grey),
              ),
              Expanded(
                child: _buildPrizeItem('🥉', '3-є місце', 
                  '${widget.challenge.thirdPlacePrize.toInt()} монет', Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeItem(String icon, String place, String prize, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          place,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          prize,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildUserActionsSection({required bool isParticipant, required bool hasSubmitted}) {
    if (widget.challenge.isCompleted) {
      return Container();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎯 Дії',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (widget.challenge.isRecruiting && !isParticipant)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _joinChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Приєднатися (${widget.challenge.entryFee} монет)',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          
          if (widget.challenge.isSubmissionOpen && isParticipant && !hasSubmitted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Подати відео',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          
          if (widget.challenge.isVotingOpen && !isParticipant)
            const Text(
              'Голосування відкрите! Оцініть відео учасників.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👥 Учасники (${widget.challenge.participants.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.challenge.participants.isEmpty)
            const Text(
              'Поки що немає учасників',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.challenge.participants.length,
              itemBuilder: (context, index) {
                final participantId = widget.challenge.participants[index];
                final hasSubmitted = widget.challenge.submissions.contains(participantId);
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF9800),
                    child: Text(
                      participantId.substring(0, 2).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(participantId),
                  trailing: hasSubmitted
                      ? const Icon(Icons.video_library, color: Colors.green)
                      : const Icon(Icons.pending, color: Colors.orange),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVideosSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎬 Відео',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('challenges')
                .doc(widget.challenge.id)
                .collection('submissions')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Помилка: ${snapshot.error}');
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('Поки що немає відео');
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final author = data['authorName'] ?? docs[index].id;
                  final videoUrl = data['videoUrl'] as String?;
                  return ListTile(
                    leading: const Icon(Icons.play_circle_fill, color: Colors.green),
                    title: Text(author),
                    subtitle: Text(
                      videoUrl == null || videoUrl.isEmpty
                          ? 'Відео недоступне'
                          : 'Натисніть, щоб переглянути',
                    ),
                    trailing: widget.challenge.isVotingOpen
                        ? ElevatedButton(
                            onPressed: () => _showVotingDialog(docs[index].id),
                            child: const Text('Голосувати'),
                          )
                        : null,
                    onTap: () {
                      if (videoUrl == null || videoUrl.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoUrl: videoUrl,
                            title: 'Відео учасника',
                            authorName: author,
                            videoId: 'challenge_${docs[index].id}',
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _joinChallenge() async {
    setState(() {
      _isJoining = true;
    });

    try {
      await _challengeService.joinChallenge(widget.challenge.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ви успішно приєдналися до челенджу! +${widget.challenge.entryFee} монет'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  Future<void> _submitVideo() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Відкрити екран завантаження відео для челенджу
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoUploadScreen(
            challengeId: widget.challenge.id,
            challengeTitle: widget.challenge.title,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showVotingDialog(String participantId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeVotingScreen(
          challenge: widget.challenge,
          participantId: participantId,
        ),
      ),
    );
  }
}
