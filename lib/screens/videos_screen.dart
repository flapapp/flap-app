import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'video_upload_screen.dart';
import 'video_player_screen.dart';
import '../widgets/rating_display.dart';
import '../widgets/user_chip.dart';
import '../services/notification_service.dart';
import '../services/friends_service.dart';
import '../models/friend_request.dart' show Friend;
import '../utils/i18n.dart';

class VideosScreen extends StatefulWidget {
  final bool showOnlyMyVideos;
  const VideosScreen({Key? key, this.showOnlyMyVideos = false}) : super(key: key);

  @override
  _VideosScreenState createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  String _selectedCity = '';
  String _selectedCategory = '';
  final Set<String> _selectedCategories = <String>{};
  String _selectedRating = '';
  String _selectedTab = 'all'; // all, trending, my
  bool _showOnlyMyVideos = false;
  String _selectedSort = 'Нові'; // Нові, Рейтинг, Перегляди

  List<String> get _cities => [
    I18n.t('all_cities'),
    I18n.t('kyiv'),
    I18n.t('lviv'),
    I18n.t('odesa'),
    I18n.t('kharkiv'),
    I18n.t('dnipro'),
  ];

  List<String> get _categories => [
    I18n.t('all_categories'),
    I18n.t('technique'),
    I18n.t('physics'),
    I18n.t('tactics'),
    I18n.t('teamplay'),
    I18n.t('freestyle'),
    I18n.t('other'),
  ];

  List<String> get _ratings => [
    I18n.t('all_ratings'),
    '4.0+',
    '3.0+',
    '2.0+',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Column(
        children: [
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildTab(I18n.t('all_tab'), 'all'),
                _buildTab(I18n.t('trending'), 'trending'),
                _buildTab(I18n.t('my'), 'my'),
              ],
            ),
          ),

          // Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // Quick categories
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategories.contains(category);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (category == I18n.t('all_categories')) {
                            _selectedCategories.clear();
                          } else {
                            if (isSelected) {
                              _selectedCategories.remove(category);
                            } else {
                              _selectedCategories.add(category);
                            }
                          }
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF4caf50) : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF4caf50) : Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                              ),
                              if (isSelected) const SizedBox(width: 6),
                              if (isSelected) const Icon(Icons.check, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Dropdown filters + sort
                Row(
                  children: [
                    Expanded(flex: 1, child: _buildDropdown('🏙️', _selectedCity, _cities, (value) => setState(() => _selectedCity = value))),
                    const SizedBox(width: 8),
                    Expanded(flex: 1, child: _buildDropdown('⭐', _selectedRating, _ratings, (value) => setState(() => _selectedRating = value))),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedSort,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF1a1a2e),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          icon: const Icon(Icons.sort, color: Colors.white70),
                          items: ['Нові', 'Рейтинг', 'Перегляди']
                              .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedSort = v ?? 'Нові'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Videos list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getVideosStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final currentUser = FirebaseAuth.instance.currentUser;
                final allDocs = snapshot.data!.docs;

                // Клієнтська фільтрація для стабільності без індексів
                var docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if ((_selectedTab == 'my' || widget.showOnlyMyVideos) && currentUser != null) {
                    if ((data['userId'] ?? '') != currentUser.uid) return false;
                  }
                  if (_selectedCity.isNotEmpty && _selectedCity != I18n.t('all_cities')) {
                    if ((data['city'] ?? '') != _selectedCity) return false;
                  }
                  if (_selectedCategories.isNotEmpty) {
                    final category = (data['category'] ?? '').toString();
                    if (!_selectedCategories.contains(category)) return false;
                  }
                  return true;
                }).toList();

                // Сортування
                docs.sort((a, b) {
                  final ad = a.data() as Map<String, dynamic>;
                  final bd = b.data() as Map<String, dynamic>;
                  switch (_selectedSort) {
                    case 'Рейтинг':
                      final ar = (ad['rating'] ?? 0.0) as num;
                      final br = (bd['rating'] ?? 0.0) as num;
                      return br.compareTo(ar);
                    case 'Перегляди':
                      final av = (ad['views'] ?? 0) as num;
                      final bv = (bd['views'] ?? 0) as num;
                      return bv.compareTo(av);
                    case 'Нові':
                    default:
                      final at = ad['createdAt'];
                      final bt = bd['createdAt'];
                      if (at is Timestamp && bt is Timestamp) {
                        return bt.compareTo(at);
                      }
                      return 0;
                  }
                });

                if (_selectedTab == 'trending') {
                  docs.sort((a, b) {
                    final ad = a.data() as Map<String, dynamic>;
                    final bd = b.data() as Map<String, dynamic>;
                    final alikes = (ad['likes'] ?? 0) as int;
                    final blikes = (bd['likes'] ?? 0) as int;
                    return blikes.compareTo(alikes);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final videoData = docs[index].data() as Map<String, dynamic>;
                    videoData['id'] = docs[index].id;
                    return _buildVideoCard(videoData);
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

  Widget _buildTab(String text, String value) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4caf50) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: value.isEmpty ? items[0] : value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1a1a2e),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
        items: items.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getVideosStream() {
    // Щоб уникнути вимог до складених індексів, беремо останні відео без складних where/ordering
    return FirebaseFirestore.instance
        .collection('videos')
        .limit(50)
        .snapshots();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 'my' ? 'Ви ще не завантажили жодного відео' : 'Немає відео',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTab == 'my' 
                ? 'Завантажте своє перше відео!'
                : 'Зачекайте, поки з\'являться нові відео.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final videoTime = timestamp.toDate();
    final difference = now.difference(videoTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} днів тому';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} годин тому';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} хвилин тому';
    } else {
      return 'Щойно';
    }
  }

  Future<void> _playVideo(String videoUrl, String title, String videoId, String userId) async {
    if (videoUrl.isNotEmpty) {
      // Increment views before navigation (best-effort)
      try {
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .update({'views': FieldValue.increment(1)});
      } catch (_) {}

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: videoUrl,
            title: title,
            authorName: '', // Real name + avatar will be loaded in VideoPlayerScreen
            videoId: videoId,
          ),
        ),
      );
    }
  }

  Future<void> _toggleLike(String videoId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final likeRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('likes')
          .doc(uid);

      final likeDoc = await likeRef.get();
      final isLiked = likeDoc.exists;
      if (isLiked) {
        await likeRef.delete();
        await FirebaseFirestore.instance.collection('videos').doc(videoId).update({'likes': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.collection('videos').doc(videoId).update({'likes': FieldValue.increment(1)});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка лайку: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _shareVideo(String videoId, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📤 Відео "$title" поділено!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4caf50),
      ),
    );
  }

  Future<void> _requestRatingForVideo(String videoId, String title) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      final friendsService = FriendsService();
      final friends = await friendsService.getUserFriends(currentUser.uid);
      if (friends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Немає друзів для запиту оцінки')),
        );
        return;
      }
      final selected = <String>{};
      await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: const Text('Запросити друзів оцінити відео', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final f = friends[index] as Friend;
                  final friendId = f.userId;
                  final friendName = f.name;
                  final isSel = selected.contains(friendId);
                  return CheckboxListTile(
                    value: isSel,
                    onChanged: (val) => setStateDialog(() {
                      if (val == true) { selected.add(friendId); } else { selected.remove(friendId); }
                    }),
                    title: Text(friendName, style: const TextStyle(color: Colors.white)),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати', style: TextStyle(color: Colors.white70))),
              ElevatedButton(
                onPressed: selected.isEmpty ? null : () async {
                  final meDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                  final myName = (meDoc.data()?['displayName'] ?? meDoc.data()?['name'] ?? 'Користувач').toString();
                  await NotificationService().sendRatingRequest(
                    toUserIds: selected.toList(),
                    fromUserName: myName,
                    videoIds: [videoId],
                  );
                  if (!mounted) return;
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Запити на оцінку надіслано')),
                  );
                },
                child: const Text('Надіслати'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showComments(String videoId, String title) {
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
                    const Icon(Icons.comment, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Коментарі до "$title"',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              
              // Comments list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('videos')
                      .doc(videoId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
                    }
                    
                    final comments = snapshot.data!.docs;
                    
                    if (comments.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.comment_outlined, size: 64, color: Colors.white54),
                            SizedBox(height: 16),
                            Text(
                              'Поки немає коментарів',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            Text(
                              'Будьте першим!',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final commentData = comments[index].data() as Map<String, dynamic>;
                        return _buildCommentItem(commentData);
                      },
                    );
                  },
                ),
              ),
              
              // Add comment
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Додати коментар...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFF4caf50)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF4caf50),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => _addComment(videoId),
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
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
  }

  Widget _buildCommentItem(Map<String, dynamic> commentData) {
    final authorName = commentData['authorName'] ?? 'Користувач';
    final text = commentData['text'] ?? '';
    final createdAt = commentData['createdAt'] as Timestamp?;
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt.toDate()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF4caf50),
                child: Text(
                  authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} хв тому';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} год тому';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн тому';
    } else {
      return '${(difference.inDays / 7).floor()} тиж тому';
    }
  }

  void _addComment(String videoId) {
    // TODO: Implement add comment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Додавання коментарів буде додано незабаром!')),
    );
  }

  // Градієнти для різних категорій відео
  List<Color> _getVideoGradient(String category) {
    switch (category.toLowerCase()) {
      case 'техніка':
        return [const Color(0xFF4834d4), const Color(0xFF686de0)];
      case 'фізика':
        return [const Color(0xFF00d2d3), const Color(0xFF54a0ff)];
      case 'тактика':
        return [const Color(0xFF5f27cd), const Color(0xFF341f97)];
      case 'командна гра':
        return [const Color(0xFF43a047), const Color(0xFF66bb6a)];
      case 'фрістайл':
        return [const Color(0xFFff9ff3), const Color(0xFFf368e0)];
      case 'інше':
        return [const Color(0xFF607d8b), const Color(0xFF90a4ae)];
      default:
        return [const Color(0xFF4caf50), const Color(0xFF8bc34a)]; // Зелений за замовчуванням
    }
  }

  // Іконки для категорій
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'техніка':
        return Icons.build;
      case 'фізика':
        return Icons.fitness_center;
      case 'тактика':
        return Icons.timeline;
      case 'командна гра':
        return Icons.groups;
      case 'фрістайл':
        return Icons.auto_awesome;
      case 'інше':
        return Icons.category;
      default:
        return Icons.video_library;
    }
  }

  Widget _buildVideoCard(Map<String, dynamic> videoData) {
    final videoId = videoData['id'];
    final title = videoData['title'] ?? 'Без назви';
    final userId = videoData['userId'] ?? '';
    final videoUrl = videoData['videoUrl'] ?? '';
    final thumbnailUrl = videoData['thumbnailUrl'];
    final likes = videoData['likes'] ?? 0;
    final rating = (videoData['rating'] ?? 0.0).toDouble();
    final createdAt = videoData['createdAt'] as Timestamp?;
    final category = videoData['category'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .snapshots(),
      builder: (context, commentSnapshot) {
        final commentsCount = commentSnapshot.hasData ? commentSnapshot.data!.docs.length : 0;

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
          // Video thumbnail
          GestureDetector(
            onTap: () => _playVideo(videoUrl, title, videoId, userId),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  // Реалістичне превью відео
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        gradient: LinearGradient(
                        colors: _getVideoGradient(category),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    child: thumbnailUrl != null && thumbnailUrl.toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // На веб показуємо перший кадр відео
                                kIsWeb && thumbnailUrl == videoUrl
                                    ? _buildWebVideoPreview(videoUrl)
                                    : Image.network(
                                        thumbnailUrl,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return _buildVideoPlaceholder(category, title);
                                        },
                                        errorBuilder: (context, error, stackTrace) => _buildVideoPlaceholder(category, title),
                                      ),
                                // Темний оверлей для кращої видимості play кнопки
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildVideoPlaceholder(category, title),
                    ),
                  
                  // Play button
                  const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  
                  // Category badge (top-left)
                  if (category.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Average rating badge (top-right) — рахуємо зі стріму голосів для миттєвого відображення
                  Positioned(
                    top: 8,
                    right: 8,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('videos')
                          .doc(videoId)
                          .collection('votes')
                          .snapshots(),
                      builder: (context, voteSnap) {
                        if (!voteSnap.hasData || voteSnap.data!.docs.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        double sum = 0.0;
                        for (final d in voteSnap.data!.docs) {
                          final m = d.data() as Map<String, dynamic>;
                          sum += (m['rating'] ?? 0.0).toDouble();
                        }
                        final cnt = voteSnap.data!.docs.length;
                        final avg = cnt == 0 ? 0.0 : double.parse((sum / cnt).toStringAsFixed(2));
                        if (avg <= 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6)),
                          ),
                          child: Row(
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
                      ),
                    ),
                  
                  // Duration (if available)
                  if (videoData['duration'] != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(videoData['duration']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Video info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Author info (unified)
                Row(
                        children: [
                          Expanded(
                      child: UserChip(
                        userId: userId,
                        showName: true,
                      ),
                    ),
                          if (rating > 0)
                            Row(
                              children: [
                                const Icon(Icons.star, color: Color(0xFF4caf50), size: 16),
                                const SizedBox(width: 4),
                                Text(
                            rating.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Color(0xFF4caf50),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                ),
                
                const SizedBox(height: 12),
                
                // Stats and actions
                Row(
                  children: [
                    // Likes (live)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('videos').doc(videoId).snapshots(),
                      builder: (context, docSnap) {
                        final likeCount = docSnap.hasData && docSnap.data!.exists
                            ? ((docSnap.data!.data() as Map<String, dynamic>)['likes'] ?? likes) as int
                            : likes;
                        return Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text(
                              likeCount.toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    // Comments - клікабельні з реальною кількістю
                    GestureDetector(
                      onTap: () => _showComments(videoId, title),
                      child: Row(
                      children: [
                        const Icon(Icons.comment, color: Colors.blue, size: 16),
                        const SizedBox(width: 4),
                        Text(
                            commentsCount.toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    ),
                    const Spacer(),
                    // Action buttons
                    Row(
                      children: [
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseAuth.instance.currentUser == null
                              ? null
                              : FirebaseFirestore.instance
                                  .collection('videos')
                                  .doc(videoId)
                                  .collection('likes')
                                  .doc(FirebaseAuth.instance.currentUser!.uid)
                                  .snapshots(),
                          builder: (context, likeSnap) {
                            final isLiked = likeSnap.hasData && likeSnap.data!.exists;
                            return IconButton(
                              onPressed: () => _toggleLike(videoId),
                              icon: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.white70,
                                size: 20,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () => _shareVideo(videoId, title),
                          icon: const Icon(Icons.share, color: Colors.white70, size: 20),
                        ),
                        if (FirebaseAuth.instance.currentUser?.uid == userId)
                          IconButton(
                            tooltip: 'Запросити оцінку',
                            onPressed: () => _requestRatingForVideo(videoId, title),
                            icon: const Icon(Icons.notifications_active, color: Colors.white70, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildVideoPlaceholder(String category, String title) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Велика іконка категорії
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: Colors.white70,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          
          // Назва відео як заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          
          // Індикатор відео
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: Colors.white70, size: 12),
                const SizedBox(width: 4),
                Text(
                  category.isEmpty ? 'Відео' : category,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(controller),
                // Темний оверлей
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ],
      ),
    );
  }
        return Container(
          color: Colors.black54,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          ),
        );
      },
    );
  }

  Future<VideoPlayerController> _createVideoController(String videoUrl) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await controller.initialize();
    await controller.seekTo(const Duration(seconds: 1)); // Перший кадр
    await controller.pause(); // Зупиняємо відео
    return controller;
  }
}
