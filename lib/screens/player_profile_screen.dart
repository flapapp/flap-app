import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import '../services/friends_service.dart';
import 'video_player_screen.dart';
import '../services/notification_service.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String playerId;
  final String? playerName;

  const PlayerProfileScreen({
    Key? key,
    required this.playerId,
    this.playerName,
  }) : super(key: key);

  @override
  _PlayerProfileScreenState createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Map<String, dynamic>? playerData;
  List<Map<String, dynamic>> playerVideos = [];
  bool isLoading = true;
  final FriendsService _friendsService = FriendsService();
  bool _isSendingRequest = false;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    try {
      // Завантажити дані гравця
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.playerId)
          .get();

      if (userDoc.exists) {
        playerData = userDoc.data();
      }

      // Завантажити відео гравця (simplified query to avoid index issues)
      final videosQuery = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: widget.playerId)
          .limit(10)
          .get();

      playerVideos = videosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort on client side to avoid index requirement
      playerVideos.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading player data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _areFriends() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      return await _friendsService.areUsersFriends(currentUser.uid, widget.playerId);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasPendingRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      // Check outgoing requests
      final outgoingRequests = await _friendsService.getOutgoingFriendRequests().first;
      return outgoingRequests.any((request) => request.toUserId == widget.playerId);
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendFriendRequest() async {
    try {
      setState(() {
        _isSendingRequest = true;
      });

      await _friendsService.sendFriendRequest(widget.playerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Запрошення надіслано!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка: $e')),
        );
      }
    } finally {
      setState(() {
        _isSendingRequest = false;
      });
    }
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          rating > index 
            ? (rating > index + 0.5 ? Icons.star : Icons.star_half)
            : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.playerName ?? 'Профіль гравця',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4caf50)),
        ),
      );
    }

    if (playerData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Профіль не знайдено',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text(
            'Профіль гравця не знайдено',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final name = playerData!['name'] ?? '';
    final surname = playerData!['surname'] ?? '';
    final displayName = '$name $surname'.trim();
    final position = playerData!['position'] ?? '';
    final experience = playerData!['experience'] ?? '';
    final city = playerData!['city'] ?? '';
    final rating = (playerData!['rating'] ?? 0.0).toDouble();
    final matches = playerData!['matches'] ?? 0;
    final averageRating = (playerData!['averageRating'] ?? rating).toDouble();
    final wins = playerData!['wins'] ?? 0;
    final losses = playerData!['losses'] ?? 0;
    final draws = playerData!['draws'] ?? 0;
    final avatarUrl = playerData!['avatarUrl'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.playerName ?? 'Профіль гравця', style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Аватар
              Container(
              width: 96,
              height: 96,
                decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(48),
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultAvatar(displayName))
                      : _buildDefaultAvatar(displayName),
                ),
              ),
            const SizedBox(height: 12),
            Text(displayName.isNotEmpty ? displayName : 'Гравець', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
              if (position.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('⚽ $position', style: const TextStyle(color: Colors.white)),
              ),
            const SizedBox(height: 12),
              if (city.isNotEmpty)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                Text(city, style: const TextStyle(color: Colors.white70)),
              ]),
            const SizedBox(height: 20),
            // Рейтинг
              Container(
                padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                const Text('Загальний рейтинг', style: TextStyle(color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statBox(value: matches.toString(), label: 'Матчі зіграно')),
              const SizedBox(width: 10),
              Expanded(child: _statBox(value: averageRating.toStringAsFixed(1), label: 'Середня оцінка')),
            ]),
            const SizedBox(height: 20),
            // Кнопки
            FutureBuilder<Map<String, bool>>(
              future: Future.wait([_areFriends(), _hasPendingRequest()]).then((results) {
                return {'isFriend': results[0], 'hasPendingRequest': results[1]};
              }),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {'isFriend': false, 'hasPendingRequest': false};
                final isFriend = data['isFriend']!;
                final hasPendingRequest = data['hasPendingRequest']!;

                return Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isFriend || hasPendingRequest || _isSendingRequest
                          ? null
                          : () => _sendFriendRequest(),
                      icon: Icon(isFriend ? Icons.people : hasPendingRequest ? Icons.schedule : Icons.person_add),
                      label: Text(
                        isFriend ? 'Друзі' :
                        hasPendingRequest ? 'Запрошення надіслано' :
                        _isSendingRequest ? 'Надсилання...' : 'Додати в друзі'
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFriend ? Colors.grey.withOpacity(0.3) :
                                       hasPendingRequest ? Colors.orange.withOpacity(0.3) :
                                       const Color(0xFF4caf50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showInviteToChallengeDialog(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.12), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    child: const Icon(Icons.emoji_events, size: 16),
                  ),
                ]);
              },
              ),
              const SizedBox(height: 12),
              // Відео гравця
              if (playerVideos.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text('Відео', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: playerVideos.length,
                    itemBuilder: (context, index) {
                      final v = playerVideos[index];
                      final thumb = (v['thumbnailUrl'] ?? '') as String;
                      final vUrl = (v['videoUrl'] ?? '') as String;
                      final title = (v['title'] ?? 'Відео') as String;
                      return GestureDetector(
                        onTap: () {
                          if (vUrl.isEmpty) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(
                                videoUrl: vUrl,
                                title: title,
                                authorName: displayName.isNotEmpty ? displayName : 'Гравець',
                                videoId: (v['id'] ?? '') as String,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: thumb.isNotEmpty
                                ? (kIsWeb && thumb == vUrl
                                    ? _buildWebVideoPreview(vUrl)
                                    : Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _videoThumbFallback(title)))
                                : (kIsWeb && vUrl.isNotEmpty
                                    ? _buildWebVideoPreview(vUrl)
                                    : _videoThumbFallback(title)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Поки що немає відео', style: TextStyle(color: Colors.white54)),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _statBox({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _videoThumbFallback(String title) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildWebVideoPreview(String videoUrl) {
    return FutureBuilder<VideoPlayerController>(
      future: _createVideoController(videoUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.value.isInitialized) {
          final controller = snapshot.data!;
          return AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );
        }
        return Container(
          color: Colors.black54,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50), strokeWidth: 2),
          ),
        );
      },
    );
  }

  Future<VideoPlayerController> _createVideoController(String videoUrl) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await controller.initialize();
    await controller.seekTo(const Duration(seconds: 1));
    await controller.pause();
    return controller;
  }

  Future<void> _showInviteToChallengeDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('challenges')
          .where('creatorId', isEqualTo: currentUser.uid)
          .limit(50)
          .get();

      final all = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return data;
      }).where((c) {
        final participants = List<String>.from(c['participants'] ?? []);
        return !participants.contains(widget.playerId);
      }).toList();

      if (all.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Немає доступних ваших челенджів для запрошення.')),
        );
        return;
      }

      int selectedIndex = -1;
      await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              backgroundColor: const Color(0xFF1a1a2e),
              title: const Text('Запросити до челенджу', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: all.length,
                  itemBuilder: (context, index) {
                    final c = all[index];
                    return RadioListTile<int>(
                      value: index,
                      groupValue: selectedIndex,
                      onChanged: (v) => setStateDialog(() => selectedIndex = v ?? -1),
                      title: Text(c['title'] ?? 'Челендж', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('Учасників: ${(c['participants'] as List?)?.length ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Скасувати', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: selectedIndex < 0 ? null : () async {
                    final selected = all[selectedIndex];
                    final ok = await _notificationService.sendChallengeInvitation(
                      toUserId: widget.playerId,
                      challengeId: selected['id'] as String,
                      challengeTitle: (selected['title'] ?? 'Челендж') as String,
                      creatorName: (playerData?['displayName'] ?? 'Користувач') as String,
                      challengeType: (selected['type'] ?? 'technical') as String,
                    );
                    if (!mounted) return;
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '✅ Запрошення надіслано' : '❌ Не вдалося надіслати')),
                    );
                  },
                  child: const Text('Запросити'),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка: $e')),
      );
    }
  }
}
