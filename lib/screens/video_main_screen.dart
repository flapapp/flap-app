import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_upload_screen.dart';
import 'video_player_screen.dart';
import 'challenge_list_screen.dart';
import '../models/challenge.dart';
import '../widgets/rating_display.dart';
import '../services/notification_service.dart';
import '../utils/i18n.dart';

class VideoMainScreen extends StatefulWidget {
  @override
  _VideoMainScreenState createState() => _VideoMainScreenState();
}

class _VideoMainScreenState extends State<VideoMainScreen> {
  final NotificationService _notificationService = NotificationService();
  String _selectedCity = '';
  String _selectedCategory = '';
  String _selectedRating = '';
  String _selectedTab = 'all'; // all, challenges, trending
  bool _showOnlyMyVideos = false;
  bool _showOnlyMyChallenges = false;

  List<String> get _cities => [
    I18n.t('all_cities'),
    I18n.t('kyiv'),
    I18n.t('lviv'),
    I18n.t('odesa'),
    I18n.t('kharkiv'),
    I18n.t('dnipro'),
  ];

  List<String> get _categories => [
    I18n.inline('Всі категорії', 'All categories'),
    I18n.inline('Техніка', 'Technique'),
    I18n.inline('Фізика', 'Physics'),
    I18n.inline('Тактика', 'Tactics'),
    I18n.inline('Командна гра', 'Teamplay'),
    I18n.inline('Фрістайл', 'Freestyle'),
    I18n.inline('Дриблінг', 'Dribbling'),
    I18n.inline('Удари', 'Shots'),
    I18n.inline('Передачі', 'Passes'),
    I18n.inline('Воротарі', 'Goalkeepers'),
    I18n.inline('Комбінації', 'Combinations'),
  ];

  List<String> get _ratings => [
    I18n.inline('Всі рейтинги', 'All ratings'),
    '4.0+',
    '4.5+',
  ];

  @override
  Widget build(BuildContext context) {
    // Читаємо навігаційні аргументи (напр. з профілю)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && (args['myContent'] == 'videos' || args['myContent'] == 'challenges')) {
      _showOnlyMyVideos = args['myContent'] == 'videos';
      _showOnlyMyChallenges = args['myContent'] == 'challenges';
      _selectedTab = _showOnlyMyChallenges ? 'challenges' : 'all';
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23), // Темний фон як у HTML MVP
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23).withOpacity(0.95),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/logo/flap_logo.jpg', fit: BoxFit.cover, width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            const Text(
              'FLAP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          // User chips: coins and rating
          _buildUserChips(),
          // Notifications
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    tooltip: I18n.t('notifications'),
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Profile button with avatar
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return IconButton(
                  icon: const Icon(Icons.person, color: Colors.white),
                  onPressed: () => _showProfile(context),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
              final userName = userData['displayName'] ?? userData['name'] ?? userData['email']?.split('@')[0] ?? 'User';

              return IconButton(
                onPressed: () => _showProfile(context),
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF4caf50),
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
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
                  _buildTab(I18n.t('all'), 'all'),
                  _buildTab(I18n.t('challenges'), 'challenges'),
                  _buildTab(I18n.inline('Тренди', 'Trending'), 'trending'),
                ],
              ),
            ),

            // Filters (тільки для відео та трендів)
            if (_selectedTab != 'challenges')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    // Швидкі категорії (як у HTML MVP)
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...[I18n.inline('Дриблінг', 'Dribbling'), I18n.inline('Удари', 'Shots'), I18n.inline('Передачі', 'Passes'), I18n.inline('Фрістайл', 'Freestyle'), I18n.inline('Воротарі', 'Goalkeepers'), I18n.inline('Комбінації', 'Combinations')]
                              .map((c) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      selected: _selectedCategory == c,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedCategory = selected ? c : '';
                                        });
                                      },
                                      label: Text(c),
                                      selectedColor: const Color(0xFF4caf50),
                                      labelStyle: TextStyle(color: _selectedCategory == c ? Colors.white : Colors.black87),
                                    ),
                                  )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // City and Category filters
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 40) / 2, // 20px паддінг зліва+справа
                          child: _buildFilterDropdown(
                            _cities,
                            _selectedCity.isEmpty ? I18n.t('all_cities') : _selectedCity,
                            (value) {
                              setState(() {
                                _selectedCity = value == I18n.t('all_cities') ? '' : value;
                              });
                            },
                            '🏙️',
                          ),
                        ),
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 40) / 2,
                          child: _buildFilterDropdown(
                            _categories,
                            _selectedCategory.isEmpty ? I18n.inline('Всі категорії', 'All categories') : _selectedCategory,
                            (value) {
                              setState(() {
                                _selectedCategory = value == I18n.inline('Всі категорії', 'All categories') ? '' : value;
                              });
                            },
                            '⚽',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Rating filter
                    _buildFilterDropdown(
                      _ratings,
                      _selectedRating.isEmpty ? I18n.inline('Всі рейтинги', 'All ratings') : _selectedRating,
                      (value) {
                        setState(() {
                          _selectedRating = value == I18n.inline('Всі рейтинги', 'All ratings') ? '' : value;
                        });
                      },
                      '⭐',
                    ),
                  ],
                ),
              ),

            // Content based on selected tab
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
      // FAB for quick actions
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Button to switch to matches mode (like in matches screen)
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Navigator.pushNamed(context, '/matches');
                },
                child: const Center(
                  child: Text(
                    '⚽',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          // Create Challenge FAB
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            child: FloatingActionButton(
              heroTag: "challenge_fab",
              onPressed: () {
                Navigator.pushNamed(context, '/challenge-create');
              },
              backgroundColor: const Color(0xFF4caf50),
              elevation: 8,
              child: const Icon(Icons.emoji_events, color: Colors.white),
              tooltip: I18n.t('create_challenge'),
            ),
          ),
          const SizedBox(height: 12),
          // Upload Video FAB
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.bounceOut,
            child: FloatingActionButton(
              heroTag: "video_fab",
              onPressed: () {
                Navigator.pushNamed(context, '/video-upload');
              },
              backgroundColor: const Color(0xFFFF6B35),
              elevation: 8,
              child: const Icon(Icons.videocam, color: Colors.white),
              tooltip: I18n.t('upload_video'),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildTab(String title, String tab) {
    final isActive = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            gradient: isActive ? LinearGradient(
              colors: [
                const Color(0xFF4caf50),
                const Color(0xFF66bb6a),
              ],
            ) : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color(0xFF4caf50).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
        ),
        child: Text(
          title.toUpperCase(),
            textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    List<String> items,
    String selectedValue,
    Function(String) onChanged,
    String icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Text(icon),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 'challenges':
        return _buildChallengesList(); // Вбудований список челенджів
      case 'trending':
        return _buildTrendingVideos(); // Трендові відео
      default:
        return _buildVideosList(); // Загальні відео (без челенджів)
    }
  }

  Widget _buildVideosList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getVideosStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              I18n.inline('Помилка завантаження: ${snapshot.error}', 'Error loading: ${snapshot.error}'),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  I18n.inline('Поки що немає відео', 'No videos yet'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18n.inline('Будьте першим, хто завантажить відео!', 'Be the first to upload a video!'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/video-upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Завантажити відео',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        // Клієнтська фільтрація (щоб не вимагати композитні індекси)
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          
          // Виключаємо відео з челенджів
          final title = (data['title'] ?? '').toString();
          final description = (data['description'] ?? '').toString();
          if (title == 'Відео створювача' || 
              title == 'Відео челенджу' ||
              description == 'Відео челенджу') {
            return false; // Виключаємо відео з челенджів
          }
          
          // Фільтр рейтингу
          if (_selectedRating.isNotEmpty) {
            final minRating = double.parse(_selectedRating.replaceAll('+', ''));
            final r = (data['rating'] ?? 0).toDouble();
            if (r < minRating) return false;
          }
          
          // Фільтр категорії
          if (_selectedCategory.isNotEmpty) {
            final category = data['category'] ?? '';
            if (category != _selectedCategory) return false;
          }
          
          // Фільтр міста
          if (_selectedCity.isNotEmpty) {
            final city = data['city'] ?? '';
            if (city != _selectedCity) return false;
          }
          
          return true;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final video = docs[index];
            final data = video.data() as Map<String, dynamic>;
            
            return AnimatedContainer(
              duration: Duration(milliseconds: 300 + (index * 100)),
              curve: Curves.easeOutBack,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.5, 0.5),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: AlwaysStoppedAnimation(1.0),
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: FadeTransition(
                  opacity: Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).animate(
                    CurvedAnimation(
                      parent: AlwaysStoppedAnimation(1.0),
                      curve: Interval(
                        (index * 0.1).clamp(0.0, 1.0),
                        1.0,
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                  child: _buildVideoCard(data, video.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getVideosStream() {
    Query query = FirebaseFirestore.instance.collection('videos');
    
    // Apply only basic filters that don't conflict with orderBy
    if (_showOnlyMyVideos) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) query = query.where('userId', isEqualTo: uid);
    }
    
    // Remove city and category filters from Firestore query to avoid composite index issues
    // These will be applied on the client side in _buildVideosList()
    
    // Apply tab filters
    switch (_selectedTab) {
      case 'trending':
        query = query.orderBy('views', descending: true);
        break;
      default:
        query = query.orderBy('createdAt', descending: true);
    }
    
    return query.snapshots();
  }

  Widget _buildVideoCard(Map<String, dynamic> data, String videoId) {
    final title = data['title'] ?? I18n.inline('Без назви', 'No title');
    final description = data['description'] ?? '';
    final category = data['category'] ?? I18n.inline('Без категорії', 'No category');
    final rating = (data['rating'] ?? 0.0).toDouble();
    final views = data['views'] ?? 0;
    final likes = data['likes'] ?? 0;
    final comments = data['comments'] ?? 0;
    final authorName = data['authorName'] ?? 'Невідомий';
    final authorId = data['userId'] as String?;
    final city = data['city'] ?? 'Невідомо';
    final createdAt = data['createdAt'] as Timestamp?;
    final isLiked = data['isLikedByCurrentUser'] ?? false;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video thumbnail
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    videoUrl: data['videoUrl'] ?? '',
                    title: title,
                    authorName: authorName,
                    videoId: videoId,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Colors.black54,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  // Video preview or placeholder
                  Center(
                    child: data['videoUrl'] != null && data['videoUrl'].isNotEmpty
                        ? Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                              ),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4caf50).withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 60,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(color: Colors.white24, width: 2),
                                ),
                                child: const Icon(
                                Icons.videocam_off,
                                color: Colors.white54,
                                  size: 40,
                              ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Відео недоступне',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                  // Category badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4caf50),
                            const Color(0xFF66bb6a),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4caf50).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Rating badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFffd700),
                            const Color(0xFFffa000),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFffd700).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Duration badge (bottom right)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${views > 0 ? "${views} переглядів" : "Новинка"}',
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
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Description
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Author info
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (authorId != null) {
                          Navigator.pushNamed(
                            context,
                            '/player-profile',
                            arguments: {'playerId': authorId, 'playerName': authorName},
                          );
                        }
                      },
                        child: Row(
                          children: [
                            ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: authorId != null
                              ? FirebaseFirestore.instance.collection('users').doc(authorId).get()
                              : null,
                          builder: (context, s) {
                            final url = s.hasData ? (s.data!.data()?['avatarUrl'] as String?) : null;
                            if (url != null && url.isNotEmpty) {
                              return Image.network(url, width: 32, height: 32, fit: BoxFit.cover);
                            }
                            return Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFff9800), Color(0xFFf57c00)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 18),
                            );
                          },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '$city • ${_formatDate(createdAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          if (authorId != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CompactRatingDisplay(userId: authorId, size: 16),
                              ],
                            ),
                          ],
                        ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                
                // Interactive Actions Row (responsive)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    // Like button
                    _buildActionButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: '$likes',
                      color: isLiked ? Colors.red : Colors.white70,
                      onTap: () => _toggleLike(videoId, isLiked),
                    ),
                        const SizedBox(width: 8),
                    // Comment button
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: '$comments',
                      color: Colors.white70,
                      onTap: () => _showComments(videoId, title),
                    ),
                        const SizedBox(width: 8),
                    // Share button
                    _buildActionButton(
                      icon: Icons.share,
                      label: 'Поділитися',
                      color: Colors.white70,
                      onTap: () => _shareVideo(videoId, title),
                    ),
                      ],
                    ),
                    // Enhanced Watch button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4caf50),
                            const Color(0xFF66bb6a),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4caf50).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                      child: ElevatedButton.icon(
                      onPressed: () async {
                        // increment views best-effort before opening
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
                              videoUrl: data['videoUrl'] ?? '',
                              title: title,
                              authorName: authorName,
                              videoId: videoId,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                        'Дивитися',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Нещодавно';
    
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} дн. тому';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} год. тому';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} хв. тому';
    } else {
      return 'Щойно';
    }
  }

  void _showProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  Widget _buildProfileSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Профіль не знайдено'));
          }

                     final userData = snapshot.data!.data()!;
           final displayName = userData['authorName'] ?? userData['displayName'] ?? 'Невідомий';
           final avatarUrl = userData['avatarUrl'] as String?;
           final email = userData['email'] ?? '';

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6a1b9a), Color(0xFF9c27b0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Color(0xFF6a1b9a),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xFF6a1b9a),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Profile options
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                                         _buildProfileOption(
                       icon: Icons.edit,
                       title: 'Редагувати профіль',
                       onTap: () {
                         Navigator.pop(context);
                         Navigator.pushNamed(context, '/profile');
                       },
                     ),
                    _buildProfileOption(
                      icon: Icons.video_library,
                      title: 'Мої відео',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Show user's videos
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.favorite,
                      title: 'Улюблені',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Show liked videos
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.settings,
                      title: 'Налаштування',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to settings
                      },
                    ),
                    const Divider(height: 30),
                    _buildProfileOption(
                      icon: Icons.logout,
                      title: 'Вийти',
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6a1b9a)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // Список челенджів
  Widget _buildChallengesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: (() {
        Query q = FirebaseFirestore.instance
            .collection('challenges')
            .orderBy('createdAt', descending: true)
            .limit(20);
        if (_showOnlyMyChallenges) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            q = q.where('creatorId', isEqualTo: uid);
          }
        }
        return q.snapshots();
      })(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Помилка: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final challenges = snapshot.data?.docs ?? [];

        if (challenges.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Поки що немає челенджів',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Створіть перший челендж або дочекайтеся нових!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/challenge-create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Створити челендж',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index].data() as Map<String, dynamic>;
            return AnimatedContainer(
              duration: Duration(milliseconds: 400 + (index * 150)),
              curve: Curves.elasticOut,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-0.5, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: AlwaysStoppedAnimation(1.0),
                    curve: Curves.elasticOut,
                  ),
                ),
                child: FadeTransition(
                  opacity: Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).animate(
                    CurvedAnimation(
                      parent: AlwaysStoppedAnimation(1.0),
                      curve: Interval(
                        (index * 0.15).clamp(0.0, 1.0),
                        1.0,
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                  child: _buildChallengeCard(challenge, challenges[index].id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Картка челенджу
  Widget _buildChallengeCard(Map<String, dynamic> challenge, String challengeId) {
    final status = challenge['status'] ?? 'recruiting';
    final currentParticipants = challenge['currentParticipants'] ?? 0;
    final maxParticipants = challenge['maxParticipants'] ?? 50;
    final prizePool = (challenge['prizePool'] ?? 0.0).toDouble();
    final entryFee = challenge['entryFee'] ?? 10;
    final duration = challenge['duration'] ?? 7;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4caf50).withOpacity(0.1),
            const Color(0xFF66bb6a).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4caf50).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Заголовок челенджу
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4caf50).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with status badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                  challenge['title'] ?? 'Без назви',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  challenge['description'] ?? 'Без опису',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Author and duration info
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      challenge['creatorName'] ?? 'Невідомо',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$duration днів',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Інформація про челендж
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
            child: Column(
              children: [
                Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                          Text(
                            'Прогрес: $currentParticipants/$maxParticipants',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${((currentParticipants / maxParticipants) * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                    ),
                  ],
                ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: currentParticipants / maxParticipants,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF66bb6a),
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.people,
                        value: '$currentParticipants',
                        label: 'Учасники',
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.attach_money,
                        value: '$entryFee',
                        label: 'Вхід',
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.emoji_events,
                        value: '${prizePool.toInt()}',
                        label: 'Приз',
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons Row
                Row(
                  children: [
                    // Переглянути челендж
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      child: ElevatedButton.icon(
                          onPressed: () => _viewChallengeDetails(challengeId, challenge),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Переглянути',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Приєднатися
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4caf50).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _joinChallenge(challengeId, challenge),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.video_library,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Участь',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'recruiting':
        return 'Збір';
      case 'submission':
        return 'Відео';
      case 'voting':
        return 'Голосування';
      case 'completed':
        return 'Завершено';
      default:
        return 'Активний';
    }
  }

  // Мої відео
  Widget _buildMyVideosList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Помилка: ${snapshot.error}'));
        }

        final videos = snapshot.data?.docs ?? [];

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off,
                  color: Colors.white.withOpacity(0.5),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'У вас поки що немає відео',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Завантажте своє перше відео!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/video-upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Завантажити відео',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index].data() as Map<String, dynamic>;
            return _buildVideoCard(video, videos[index].id);
          },
        );
      },
    );
  }

  // Трендові відео
  Widget _buildTrendingVideos() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .orderBy('views', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Помилка: ${snapshot.error}'));
        }

        final videos = snapshot.data?.docs ?? [];

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.white.withOpacity(0.5),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Поки що немає трендових відео',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index].data() as Map<String, dynamic>;
            return _buildVideoCard(video, videos[index].id);
          },
        );
      },
    );
  }

  // Методи для роботи з челенджами
  void _joinChallenge(String challengeId, Map<String, dynamic> challenge) {
    // Перевірити чи користувач вже учасник
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Показуємо підтвердження участі
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e7d32),
        title: Text(
          'Приєднатися до челенджу',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ви приєднуєтеся до челенджу "${challenge['title']}"',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Ставка входу: ${challenge['entryFee'] ?? 0} монет',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Спочатку додаємо користувача в учасники
              try {
                await FirebaseFirestore.instance
                    .collection('challenges')
                    .doc(challengeId)
                    .update({
                  'participants': FieldValue.arrayUnion([currentUser.uid]),
                  'currentParticipants': FieldValue.increment(1),
                });
                
                // Тепер переходимо до завантаження відео
    Navigator.pushNamed(
      context,
      '/video-upload',
      arguments: {
        'challengeId': challengeId,
        'challengeTitle': challenge['title'],
        'isChallengeVideo': true,
      },
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Помилка приєднання: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4caf50)),
            child: const Text('Завантажити відео', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _viewChallengeDetails(String challengeId, Map<String, dynamic> challengeData) {
    // Створюємо Challenge об'єкт з даних
    final challenge = Challenge(
      id: challengeId,
      title: challengeData['title'] ?? '',
      description: challengeData['description'] ?? '',
      type: ChallengeType.values.firstWhere(
        (e) => e.toString() == 'ChallengeType.${challengeData['type']}',
        orElse: () => ChallengeType.technical,
      ),
      audience: ChallengeAudience.values.firstWhere(
        (e) => e.toString() == 'ChallengeAudience.${challengeData['audience']}',
        orElse: () => ChallengeAudience.city,
      ),
      creatorId: challengeData['creatorId'] ?? '',
      creatorName: challengeData['creatorName'] ?? '',
      city: challengeData['city'] ?? '',
      entryFee: challengeData['entryFee'] ?? 10,
      duration: challengeData['duration'] ?? 7,
      createdAt: (challengeData['createdAt'] as Timestamp).toDate(),
      startDate: (challengeData['startDate'] as Timestamp).toDate(),
      submissionDeadline: (challengeData['submissionDeadline'] as Timestamp).toDate(),
      votingDeadline: (challengeData['votingDeadline'] as Timestamp).toDate(),
      endDate: (challengeData['endDate'] as Timestamp).toDate(),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.toString() == 'ChallengeStatus.${challengeData['status']}',
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
      imageUrl: challengeData['imageUrl'],
      tags: List<String>.from(challengeData['tags'] ?? []),
    );
    
    // Переходимо на екран деталей челенджу
    Navigator.pushNamed(
      context,
      '/challenge-details',
      arguments: challenge,
    );
  }

  // Helper method for action buttons
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Interactive methods
  Future<void> _toggleLike(String videoId, bool isCurrentlyLiked) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final likeRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('likes')
          .doc(uid);
      if (isCurrentlyLiked) {
        await likeRef.delete();
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .update({'likes': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .update({'likes': FieldValue.increment(1)});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка лайку: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showComments(String videoId, String videoTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1e7d32), Color(0xFF2e7d32)],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Коментарі до "$videoTitle"',
                      style: const TextStyle(
                color: Colors.white,
                        fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Поки що немає коментарів',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Будьте першим, хто залишить коментар!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final comment = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final userId = comment['userId'] ?? '';
                      final commentText = comment['comment'] ?? '';
                      final timestamp = comment['createdAt'] as Timestamp?;
                      
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .get(),
                        builder: (context, userSnapshot) {
                          String authorName = 'Користувач';
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            final name = userData['name'] ?? '';
                            final surname = userData['surname'] ?? '';
                            authorName = '$name $surname'.trim();
                            if (authorName.isEmpty) {
                              authorName = userData['authorName'] ?? 'Користувач';
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar (кліабельний)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/player-profile',
                                      arguments: {
                                        'playerId': userId,
                                        'playerName': authorName,
                                      },
                                    );
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Comment content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Author name (кліабельний)
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/player-profile',
                                            arguments: {
                                              'playerId': userId,
                                              'playerName': authorName,
                                            },
                                          );
                                        },
                                        child: Text(
                                          authorName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                            decorationColor: Colors.white30,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Comment text
                                      Text(
                                        commentText,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Timestamp
                                      if (timestamp != null)
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 11,
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
                },
              ),
            ),
            // Comment input
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Написати коментар...',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            _addComment(videoId, text.trim());
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareVideo(String videoId, String videoTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📤 Відео "$videoTitle" поділено!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4caf50),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final commentTime = timestamp.toDate();
    final difference = now.difference(commentTime);

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

  void _addComment(String videoId, String comment) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Перевірка чи videoId не порожній
    if (videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Помилка: ID відео не знайдено'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Додати коментар
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .add({
        'userId': currentUser.uid,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Оновити лічильник коментарів
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .update({
        'comments': FieldValue.increment(1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💬 Коментар додано!'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Помилка додавання коментаря: $e'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // User chips with coins and rating
  Widget _buildUserChips() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final coins = userData['coins'] ?? 0;
        final rating = (userData['rating'] ?? 0.0).toDouble();

        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coins chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFffc107).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFffc107), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFffc107), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      coins.toString(),
                      style: const TextStyle(
                        color: Color(0xFFffc107),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Rating chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4caf50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4caf50), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Color(0xFF4caf50), size: 16),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
