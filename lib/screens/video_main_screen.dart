import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_upload_screen.dart';
import 'video_player_screen.dart';
import 'challenge_list_screen.dart';

class VideoMainScreen extends StatefulWidget {
  @override
  _VideoMainScreenState createState() => _VideoMainScreenState();
}

class _VideoMainScreenState extends State<VideoMainScreen> {
  String _selectedCity = '';
  String _selectedCategory = '';
  String _selectedRating = '';
  String _selectedTab = 'all'; // all, challenges, trending

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
    'Техніка',
    'Фізика',
    'Тактика',
    'Командна гра',
    'Фрістайл',
  ];

  final List<String> _ratings = [
    'Всі рейтинги',
    '4.0+',
    '4.5+',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ВІДЕО',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          // Створити челендж (завжди доступно з відео екрана, як у MVP)
          IconButton(
            tooltip: 'Створити челендж',
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/challenge-create'),
          ),
          // Завантажити відео
          IconButton(
            tooltip: 'Завантажити відео',
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/video-upload'),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data()!;
                final avatarUrl = userData['avatarUrl'] as String?;
                
                return GestureDetector(
                  onTap: () => _showProfile(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 24,
                                color: Color(0xFF1e7d32),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 24,
                              color: Color(0xFF1e7d32),
                            ),
                    ),
                  ),
                );
              }
              
              return IconButton(
                icon: const Icon(Icons.person, color: Colors.white),
                onPressed: () => _showProfile(context),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _buildTab('Всі', 'all'),
                  const SizedBox(width: 15),
                  _buildTab('Челенджі', 'challenges'),
                  const SizedBox(width: 15),
                  _buildTab('Тренди', 'trending'),
                ],
              ),
            ),

            // Filters (тільки для відео та трендів)
            if (_selectedTab != 'challenges')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    // City and Category filters
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown(
                            _cities,
                            _selectedCity.isEmpty ? 'Всі міста' : _selectedCity,
                            (value) {
                              setState(() {
                                _selectedCity = value == 'Всі міста' ? '' : value;
                              });
                            },
                            '🏙️',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildFilterDropdown(
                            _categories,
                            _selectedCategory.isEmpty ? 'Всі категорії' : _selectedCategory,
                            (value) {
                              setState(() {
                                _selectedCategory = value == 'Всі категорії' ? '' : value;
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
                      _selectedRating.isEmpty ? 'Всі рейтинги' : _selectedRating,
                      (value) {
                        setState(() {
                          _selectedRating = value == 'Всі рейтинги' ? '' : value;
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
    );
  }

  Widget _buildTab(String title, String tab) {
    final isActive = _selectedTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.35),
            width: 2,
          ),
        ),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.5,
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
        return ChallengeListScreen(); // Список челенджів
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
              'Помилка завантаження: ${snapshot.error}',
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
                const Text(
                  'Поки що немає відео',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Будьте першим, хто завантажить відео!',
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

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final video = snapshot.data!.docs[index];
            final data = video.data() as Map<String, dynamic>;
            
            return _buildVideoCard(data, video.id);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getVideosStream() {
    Query query = FirebaseFirestore.instance.collection('videos');
    
    // Apply filters
    if (_selectedCity.isNotEmpty) {
      query = query.where('city', isEqualTo: _selectedCity);
    }
    
    if (_selectedCategory.isNotEmpty) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    if (_selectedRating.isNotEmpty) {
      final minRating = double.parse(_selectedRating.replaceAll('+', ''));
      query = query.where('rating', isGreaterThanOrEqualTo: minRating);
    }
    
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
    final title = data['title'] ?? 'Без назви';
    final description = data['description'] ?? '';
    final category = data['category'] ?? 'Без категорії';
    final rating = (data['rating'] ?? 0.0).toDouble();
    final views = data['views'] ?? 0;
    final likes = data['likes'] ?? 0;
    final authorName = data['authorName'] ?? 'Невідомий';
    final city = data['city'] ?? 'Невідомо';
    final createdAt = data['createdAt'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Stack(
                children: [
                  // Video preview or placeholder
                  Center(
                    child: data['videoUrl'] != null && data['videoUrl'].isNotEmpty
                        ? const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 64,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam_off,
                                color: Colors.white54,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Відео недоступне',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                  // Category badge
                  Positioned(
                    top: 15,
                    left: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Rating badge
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Description
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
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
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFff9800), Color(0xFFf57c00)],
                        ),
                        borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '$city • ${_formatDate(createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                
                // Stats and actions
                Row(
                  children: [
                    // Views
                    Row(
                      children: [
                        const Icon(Icons.visibility, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          '$views',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Likes
                    Row(
                      children: [
                        const Icon(Icons.thumb_up, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          '$likes',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Watch button
                    ElevatedButton(
                      onPressed: () {
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
                        backgroundColor: const Color(0xFF4caf50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                      child: const Text(
                        'Дивитися',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
      stream: FirebaseFirestore.instance
          .collection('challenges')
          .where('status', isEqualTo: 'recruiting')
          .snapshots(),
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
                  'Поки що немає активних челенджів',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Створіть перший челендж!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
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
            return _buildChallengeCard(challenge, challenges[index].id);
          },
        );
      },
    );
  }

  // Картка челенджу
  Widget _buildChallengeCard(Map<String, dynamic> challenge, String challengeId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Заголовок челенджу
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
                Text(
                  challenge['title'] ?? 'Без назви',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  challenge['description'] ?? 'Без опису',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Автор: ${challenge['creatorName'] ?? 'Невідомо'}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${challenge['duration'] ?? 7} днів',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.people,
                      '${challenge['currentParticipants'] ?? 0} учасників',
                    ),
                    const SizedBox(width: 16),
                    _buildInfoItem(
                      Icons.monetization_on,
                      '${challenge['entryFee'] ?? 0} монет',
                    ),
                    const SizedBox(width: 16),
                    _buildInfoItem(
                      Icons.emoji_events,
                      '${(challenge['prizePool'] ?? 0).toInt()} монет',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Кнопки дій
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _joinChallenge(challengeId, challenge),
                        icon: const Icon(Icons.video_library),
                        label: const Text('Приєднатися'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4caf50),
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
                      child: OutlinedButton.icon(
                        onPressed: () => _viewChallengeDetails(challengeId, challenge),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Деталі'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
    
    // Навігація до завантаження відео для челенджу
    Navigator.pushNamed(
      context,
      '/video-upload',
      arguments: {
        'challengeId': challengeId,
        'challengeTitle': challenge['title'],
        'isChallengeVideo': true,
      },
    );
  }

  void _viewChallengeDetails(String challengeId, Map<String, dynamic> challenge) {
    // Показати детальну інформацію про челендж
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e7d32),
        title: Text(
          challenge['title'] ?? 'Деталі челенджу',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Опис:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              challenge['description'] ?? 'Без опису',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Призовий фонд: ${challenge['prizePool']?.toInt() ?? 0} монет',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              'Ставка входу: ${challenge['entryFee'] ?? 0} монет',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              'Учасників: ${challenge['currentParticipants'] ?? 0}',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрити'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinChallenge(challengeId, challenge);
            },
            child: const Text('Приєднатися'),
          ),
        ],
      ),
    );
  }
}
