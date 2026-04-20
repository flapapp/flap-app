import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'video_player_screen.dart';
import '../../../../widgets/user_chip.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../../widgets/video_preview_box.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import '../../../../core/supabase/supabase_date.dart';

@RoutePage()
class VideosScreen extends StatefulWidget {
  final bool showOnlyMyVideos;
  const VideosScreen({Key? key, this.showOnlyMyVideos = false}) : super(key: key);

  @override
  _VideosScreenState createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  String _selectedCity = '';
  final Set<String> _selectedCategories = <String>{};
  String _selectedRating = '';
  String _selectedTab = 'all'; // all, trending, my
  String _selectedSortKey = 'new'; // new, rating, views

  List<String> get _cities => [
    tr('all_cities'),
    tr('kyiv'),
    tr('lviv'),
    tr('odesa'),
    tr('kharkiv'),
    tr('dnipro'),
  ];

  List<String> get _categories => [
    tr('all_categories'),
    tr('technique'),
    tr('physics'),
    tr('tactics'),
    tr('teamplay'),
    tr('freestyle'),
    tr('other'),
  ];

  List<String> get _ratings => [
    tr('all_ratings'),
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
                _buildTab(tr('all_tab'), 'all'),
                _buildTab(tr('trending'), 'trending'),
                _buildTab(tr('my'), 'my'),
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
                          if (category == tr('all_categories')) {
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
                          value: _selectedSortKey,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF1a1a2e),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          icon: const Icon(Icons.sort, color: Colors.white70),
                          items: [
                                {'key': 'new', 'label': tr('new')},
                                {'key': 'rating', 'label': tr('rating')},
                                {'key': 'views', 'label': tr('views')},
                              ]
                              .map((m) => DropdownMenuItem<String>(value: m['key'] as String, child: Text(m['label'] as String)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedSortKey = v ?? 'new'),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getVideosStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final currentUser = AppAuth.currentUser;
                final allRows = snapshot.data!;

                // Клієнтська фільтрація для стабільності без індексів
                var rows = allRows.where((data) {
                  
                  // Виключаємо відео з челенджів
                  final title = (data['title'] ?? '').toString();
                  final description = (data['description'] ?? '').toString();
                  if (title == 'Відео створювача' || 
                      title == 'Відео челенджу' ||
                      description == 'Відео челенджу') {
                    return false; // Виключаємо відео з челенджів
                  }
                  
                  if ((_selectedTab == 'my' || widget.showOnlyMyVideos) && currentUser != null) {
                    if ((data['userId'] ?? '') != currentUser.id) return false;
                  }
                  if (_selectedCity.isNotEmpty && _selectedCity != tr('all_cities')) {
                    if ((data['city'] ?? '') != _selectedCity) return false;
                  }
                  if (_selectedCategories.isNotEmpty) {
                    final category = (data['category'] ?? '').toString();
                    if (!_selectedCategories.contains(category)) return false;
                  }
                  return true;
                }).toList();

                // Сортування
                rows.sort((ad, bd) {
                  switch (_selectedSortKey) {
                    case 'rating':
                      final ar = (ad['rating'] ?? 0.0) as num;
                      final br = (bd['rating'] ?? 0.0) as num;
                      return br.compareTo(ar);
                    case 'views':
                      final av = (ad['views'] ?? 0) as num;
                      final bv = (bd['views'] ?? 0) as num;
                      return bv.compareTo(av);
                    case 'new':
                    default:
                      final at = asDateTimeOrNull(ad['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bt = asDateTimeOrNull(bd['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return bt.compareTo(at);
                  }
                });

                if (_selectedTab == 'trending') {
                  rows.sort((a, b) {
                    final ad = a;
                    final bd = b;
                    final alikes = (ad['likes'] ?? 0) as int;
                    final blikes = (bd['likes'] ?? 0) as int;
                    return blikes.compareTo(alikes);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final videoData = rows[index];
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

  Stream<List<Map<String, dynamic>>> _getVideosStream() {
    return _sb
        .from('videos')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows.map(_mapVideoRow).toList());
  }

  Map<String, dynamic> _mapVideoRow(Map<String, dynamic> row) {
    return <String, dynamic>{
      'id': row['id']?.toString() ?? '',
      'title': row['title'],
      'description': row['description'],
      'userId': row['user_id']?.toString() ?? '',
      'videoUrl': row['video_url'],
      'thumbnailUrl': row['thumbnail_url'],
      'createdAt': row['created_at'],
      'category': row['category'] ?? row['category_code'] ?? '',
      'city': row['city'] ?? '',
      'rating': (row['rating'] as num?)?.toDouble() ?? 0.0,
      'likes': (row['likes'] as num?)?.toInt() ?? 0,
      'views': (row['views'] as num?)?.toInt() ?? 0,
      'duration': row['duration'],
    };
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

  Future<void> _playVideo(String videoUrl, String title, String videoId, String userId) async {
    if (videoUrl.isNotEmpty) {
      // Record a view before navigation (best-effort)
      try {
        await _sb.from('video_views').insert({
          'video_id': videoId,
          'viewer_user_id': AppAuth.currentUserId,
        });
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
    final uid = AppAuth.currentUserId;
    if (uid == null) return;
    try {
      final likeDoc = await _sb
          .from('video_likes')
          .select('video_id')
          .eq('video_id', videoId)
          .eq('user_id', uid)
          .maybeSingle();
      final isLiked = likeDoc != null;
      if (isLiked) {
        await _sb
            .from('video_likes')
            .delete()
            .eq('video_id', videoId)
            .eq('user_id', uid);
      } else {
        await _sb.from('video_likes').upsert({
          'video_id': videoId,
          'user_id': uid,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e11b346cb1')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareVideo(String videoId, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('il_08998c4fc9')),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4caf50),
      ),
    );
  }

  Future<void> _requestRatingForVideo(String videoId, String title) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    try {
      final friends =
          await sl<FriendsRepository>().getUserFriends(currentUser.id);
      if (friends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_29a7698463'))),
        );
        return;
      }
      final selected = <String>{};
      await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: Text(tr('invite_friends_rate_video'), style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final f = friends[index];
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
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'), style: const TextStyle(color: Colors.white70))),
              ElevatedButton(
                onPressed: selected.isEmpty ? null : () async {
                  final meDoc = await _sb
                      .from('profiles')
                      .select('display_name,email')
                      .eq('id', currentUser.id)
                      .maybeSingle();
                  final myName = (meDoc?['display_name'] ??
                          meDoc?['email']?.toString().split('@').first ??
                          'Користувач')
                      .toString();
                  await sl<NotificationService>().sendRatingRequest(
                    toUserIds: selected.toList(),
                    fromUserName: myName,
                    videoIds: [videoId],
                  );
                  if (!mounted) return;
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('il_4bb3733e70'))),
                  );
                },
                child: Text(tr('send')),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf')),
          backgroundColor: Colors.red,
        ),
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
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sb
                      .from('video_comments')
                      .stream(primaryKey: ['id'])
                      .eq('video_id', videoId)
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
                    }
                    
                    final comments = snapshot.data!;
                    
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
                        final raw = comments[index];
                        final commentData = <String, dynamic>{
                          'authorName': raw['author_name'] ?? tr('il_b764cdc0ea'),
                          'text': raw['body'] ?? '',
                          'createdAt': raw['created_at'],
                        };
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
    final createdAt = asDateTimeOrNull(commentData['createdAt']);
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : '';

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
      SnackBar(content: Text(tr('il_86646f9499'))),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> videoData) {
    final videoId = videoData['id'];
    final title = videoData['title'] ?? 'Без назви';
    final userId = videoData['userId'] ?? '';
    final videoUrl = videoData['videoUrl'] ?? '';
    final thumbnailUrl = videoData['thumbnailUrl'];
    final rating = (videoData['rating'] ?? 0.0).toDouble();
    final category = videoData['category'] ?? '';

    final durationSeconds = videoData['duration'] is int
        ? videoData['duration'] as int
        : null;

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
          VideoPreviewBox(
            thumbnailUrl: thumbnailUrl?.toString(),
            videoUrl: videoUrl,
            onTap: () => _playVideo(videoUrl, title, videoId, userId),
            topLeft: category.isNotEmpty
                ? _buildChip(
                    label: category,
                    color: Colors.black.withOpacity(0.75),
                  )
                : null,
            topRight: _buildLiveRatingBadge(videoId),
            bottomRight: durationSeconds != null
                ? _buildChip(
                    label: _formatDuration(durationSeconds),
                    color: Colors.black.withOpacity(0.7),
                    fontSize: 11,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  )
                : null,
          ),
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
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _sb
                          .from('video_likes')
                          .stream(primaryKey: ['video_id', 'user_id'])
                          .eq('video_id', videoId),
                      builder: (context, likeSnap) {
                        final likeCount = likeSnap.data?.length ?? 0;
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
                    GestureDetector(
                      onTap: () => _showComments(videoId, title),
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _sb
                            .from('video_comments')
                            .stream(primaryKey: ['id'])
                            .eq('video_id', videoId),
                        builder: (context, commentSnap) {
                          final commentsCount = commentSnap.data?.length ?? 0;
                          return Row(
                            children: [
                              const Icon(Icons.comment, color: Colors.blue, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                commentsCount.toString(),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Spacer(),
                    // Action buttons
                    Row(
                      children: [
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: AppAuth.currentUser == null
                              ? null
                              : _sb
                                  .from('video_likes')
                                  .stream(primaryKey: ['video_id', 'user_id'])
                                  .eq('video_id', videoId)
                                  .map((rows) => rows
                                      .where((r) =>
                                          (r['user_id'] ?? '').toString() ==
                                          AppAuth.currentUserId!)
                                      .toList()),
                          builder: (context, likeSnap) {
                            final isLiked = (likeSnap.data?.isNotEmpty ?? false);
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
                        if (AppAuth.currentUserId == userId)
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
  }

  Widget _buildChip({
    required String label,
    required Color color,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    double fontSize = 12,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget? _buildLiveRatingBadge(String videoId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sb
          .from('video_ratings')
          .stream(primaryKey: ['id'])
          .eq('video_id', videoId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        double sum = 0;
        for (final data in snap.data!) {
          sum += ((data['overall_rating'] as num?) ?? 0).toDouble();
        }
        final avg = snap.data!.isEmpty
            ? 0.0
            : double.parse((sum / snap.data!.length).toStringAsFixed(2));
        if (avg <= 0) return const SizedBox.shrink();
        return _buildChip(
          label: '⭐ ${avg.toStringAsFixed(2)}',
          color: Colors.black.withOpacity(0.7),
        );
      },
    );
  }
}
