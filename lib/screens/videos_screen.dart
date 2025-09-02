import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'video_upload_screen.dart';
import 'video_player_screen.dart';
import '../widgets/rating_display.dart';

class VideosScreen extends StatefulWidget {
  @override
  _VideosScreenState createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  String _selectedCity = '';
  String _selectedCategory = '';
  String _selectedRating = '';
  String _selectedTab = 'all'; // all, trending, my
  bool _showOnlyMyVideos = false;
  String _selectedSort = 'Нові'; // Нові, Рейтинг, Перегляди

  final List<String> _cities = [
    'Всі міста',
    'Київ',
    'Львів',
    'Одеса',
    'Харків',
    'Дніпро',
  ];

  final List<String> _categories = [
    'Всі категорії',
    'Удари',
    'Дриблінг',
    'Передачі',
    'Захист',
    'Воротар',
  ];

  final List<String> _ratings = [
    'Всі рейтинги',
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
                _buildTab('Всі', 'all'),
                _buildTab('Тренди', 'trending'),
                _buildTab('Мої', 'my'),
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
                      final isSelected = _selectedCategory == category;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = category),
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
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
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
                  if (_selectedTab == 'my' && currentUser != null) {
                    if ((data['userId'] ?? '') != currentUser.uid) return false;
                  }
                  if (_selectedCity.isNotEmpty && _selectedCity != 'Всі міста') {
                    if ((data['city'] ?? '') != _selectedCity) return false;
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
            authorName: '', // Will be loaded in VideoPlayerScreen
            videoId: videoId,
          ),
        ),
      );
    }
  }

  void _likeVideo(String videoId) {
    // Implement like functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Відео вподобано!'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF4caf50),
      ),
    );
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
      case 'удари':
      case 'голи':
        return [const Color(0xFFff6b6b), const Color(0xFFee5a24)]; // Червоний
      case 'дриблінг':
      case 'техніка':
        return [const Color(0xFF4834d4), const Color(0xFF686de0)]; // Фіолетовий
      case 'передачі':
        return [const Color(0xFF00d2d3), const Color(0xFF54a0ff)]; // Блакитний
      case 'захист':
        return [const Color(0xFF5f27cd), const Color(0xFF341f97)]; // Темно-фіолетовий
      case 'воротар':
        return [const Color(0xFFff9ff3), const Color(0xFFf368e0)]; // Рожевий
      default:
        return [const Color(0xFF4caf50), const Color(0xFF8bc34a)]; // Зелений за замовчуванням
    }
  }

  // Іконки для категорій
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'удари':
      case 'голи':
        return Icons.sports_soccer;
      case 'дриблінг':
      case 'техніка':
        return Icons.directions_run;
      case 'передачі':
        return Icons.compare_arrows;
      case 'захист':
        return Icons.shield;
      case 'воротар':
        return Icons.sports;
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
                  
                  // Category badge
                  if (category.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
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
                
                // Author info
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFF4caf50),
                            child: Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                          SizedBox(width: 8),
                          Text('Завантаження...', style: TextStyle(color: Colors.white70)),
                        ],
                      );
                    }
                    
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final userName = userData['displayName'] ?? userData['name'] ?? userData['email']?.split('@')[0] ?? 'Користувач';
                    final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
                    
                    return GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/player-profile',
                        arguments: {
                          'playerId': userId,
                          'playerName': userName,
                        },
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            backgroundColor: const Color(0xFF4caf50),
                            child: avatarUrl.isEmpty ? Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ) : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    _formatTimestamp(createdAt),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Rating display
                          if (rating > 0)
                            Row(
                              children: [
                                const Icon(Icons.star, color: Color(0xFF4caf50), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
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
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Stats and actions
                Row(
                  children: [
                    // Likes
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          likes.toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
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
                        IconButton(
                          onPressed: () => _likeVideo(videoId),
                          icon: const Icon(Icons.favorite_border, color: Colors.white70, size: 20),
                        ),
                        IconButton(
                          onPressed: () => _shareVideo(videoId, title),
                          icon: const Icon(Icons.share, color: Colors.white70, size: 20),
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
