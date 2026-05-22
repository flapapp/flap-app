import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../../router/app_router.dart';
import '../../../friends/domain/repositories/friends_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../widgets/user_chip.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../../widgets/video_preview_box.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import '../../../../core/supabase/supabase_date.dart';
import '../../../../core/supabase/public_video_feed.dart';
import '../../../../constants/video_categories.dart';

@RoutePage()
class VideosScreen extends StatefulWidget {
  final bool showOnlyMyVideos;
  const VideosScreen({super.key, this.showOnlyMyVideos = false});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  final Map<String, Map<String, String>> _commentUserProfileCache =
      <String, Map<String, String>>{};
  final Set<String> _commentUserProfileLoading = <String>{};
  String _selectedCity = '';
  final Set<String> _selectedCategories = <String>{};
  String _selectedRating = '';
  String _selectedTab = 'all'; // all, trending, my
  String _selectedSortKey = 'new'; // new, rating
  bool _trendingUsesViewsSort = true;
  String? _cachedListKey;
  Future<List<Map<String, dynamic>>>? _cachedListFuture;

  void _invalidateVideoListCache() {
    _cachedListKey = null;
    _cachedListFuture = null;
  }

  void _applyVideoFilterChange(VoidCallback update) {
    setState(() {
      update();
      _invalidateVideoListCache();
    });
  }

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

  List<String> get _ratings => [tr('all_ratings'), '4.0+', '3.0+', '2.0+'];

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
                        onTap: () => _applyVideoFilterChange(() {
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4caf50)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF4caf50)
                                  : Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                category,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (isSelected) const SizedBox(width: 6),
                              if (isSelected)
                                const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
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
                    Expanded(
                      flex: 1,
                      child: _buildDropdown(
                        '🏙️',
                        _selectedCity,
                        _cities,
                        (value) => _applyVideoFilterChange(() {
                          _selectedCity =
                              value == tr('all_cities') ? '' : value;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildDropdown(
                        '⭐',
                        _selectedRating,
                        _ratings,
                        (value) => _applyVideoFilterChange(() {
                          _selectedRating =
                              value == tr('all_ratings') ? '' : value;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedSortKey,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF1a1a2e),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          icon: const Icon(Icons.sort, color: Colors.white70),
                          items: [
                                {'key': 'new', 'label': tr('new')},
                                {'key': 'rating', 'label': tr('rating')},
                              ]
                              .map(
                                (m) => DropdownMenuItem<String>(
                                  value: m['key'] as String,
                                  child: Text(m['label'] as String),
                                ),
                              )
                              .toList(),
                            onChanged: (v) => _applyVideoFilterChange(() {
                              _selectedSortKey = v ?? 'new';
                              if (_selectedTab == 'trending') {
                                _trendingUsesViewsSort = false;
                              }
                            }),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Videos list (filter/sort in Postgres via [get_videos_feed])
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey<String>(_feedStateKey),
              future: _memoizedVideoList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    return _buildVideoCard(rows[index]);
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

  String get _feedStateKey => [
    _selectedTab,
    widget.showOnlyMyVideos,
    _selectedCity,
    _selectedCategories.join(','),
    _selectedRating,
    _selectedTab == 'trending' && _trendingUsesViewsSort
        ? 'views'
        : _selectedSortKey,
  ].join('|');

  double? _minRatingParam() {
    if (_selectedRating.isEmpty) {
      return null;
    }
    if (_selectedRating == tr('all_ratings')) {
      return null;
    }
    final p = double.tryParse(_selectedRating.replaceAll('+', ''));
    if (p == null || p <= 0) {
      return null;
    }
    return p;
  }

  List<String> _categoryCodes() {
    if (_selectedCategories.isEmpty) {
      return <String>[];
    }
    final all = tr('all_categories');
    return _selectedCategories
        .where((c) => c != all)
        .map((c) => normalizeVideoCategoryValue(c))
        .toList();
  }

  VideoFeedSort _sortForScreen() {
    if (_selectedTab == 'trending' && _trendingUsesViewsSort) {
      return VideoFeedSort.viewsDesc;
    }
    switch (_selectedSortKey) {
      case 'rating':
        return VideoFeedSort.ratingDesc;
      case 'new':
      default:
        return VideoFeedSort.newest;
    }
  }

  VideoFeedParams _buildFeedParams() {
    final uid = AppAuth.currentUser;
    final onlyMe =
        (widget.showOnlyMyVideos || _selectedTab == 'my') && uid != null
        ? uid.id
        : null;
    return VideoFeedParams(
      onlyUserId: onlyMe,
      categoryCodes: _categoryCodes(),
      minAvgRating: _minRatingParam(),
      cityKey: videoFeedCityKey(
        _selectedCity,
        allCitiesValue: tr('all_cities'),
      ),
      excludeChallengeRelated: true,
      sort: _sortForScreen(),
      limit: 100,
    );
  }

  Future<List<Map<String, dynamic>>> _memoizedVideoList() {
    final k = _feedStateKey;
    if (_cachedListKey == k && _cachedListFuture != null) {
      return _cachedListFuture!;
    }
    _cachedListKey = k;
    return _cachedListFuture = getVideosFromDatabase(_sb, _buildFeedParams());
  }

  Widget _buildTab(String text, String value) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _applyVideoFilterChange(() {
          _selectedTab = value;
          if (value == 'trending') {
            _trendingUsesViewsSort = true;
          }
        }),
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

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
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
            _selectedTab == 'my'
                ? tr('videos_empty_my_uploads')
                : tr('videos_empty_all'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTab == 'my' ? tr('il_6aefcf68aa') : tr('il_f144c43943'),
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

  Future<void> _playVideo(
    String videoUrl,
    String title,
    String videoId,
    String userId,
  ) async {
    if (videoUrl.isNotEmpty) {
      // Record a view before navigation (best-effort)
      try {
        await _sb.from('video_views').insert({
          'video_id': videoId,
          'viewer_user_id': AppAuth.currentUserId,
        });
      } catch (_) {}

      context.router.push(
        VideoPlayerRoute(
          videoUrl: videoUrl,
          title: title,
          authorName: '',
          videoId: videoId,
        ),
      );
    }
  }

  Future<void> _toggleLike(String videoId, bool isCurrentlyLiked) async {
    final uid = AppAuth.currentUserId;
    if (uid == null) return;
    try {
      if (isCurrentlyLiked) {
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
          content: Text(tr('il_e11b346cb1', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareVideo(String videoId, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('il_08998c4fc9', namedArgs: {'title': title})),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4caf50),
      ),
    );
  }

  Future<void> _requestRatingForVideo(String videoId, String title) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    try {
      final friends = await sl<FriendsRepository>().getUserFriends(
        currentUser.id,
      );
      if (friends.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('il_29a7698463'))));
        return;
      }
      final selected = <String>{};
      await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: Text(
              tr('invite_friends_rate_video'),
              style: const TextStyle(color: Colors.white),
            ),
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
                      if (val == true) {
                        selected.add(friendId);
                      } else {
                        selected.remove(friendId);
                      }
                    }),
                    title: Text(
                      friendName,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  tr('cancel'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        final meDoc = await _sb
                            .from('profiles')
                            .select('display_name,email')
                            .eq('id', currentUser.id)
                            .maybeSingle();
                        final myName =
                            (meDoc?['display_name'] ??
                                    meDoc?['email']
                                        ?.toString()
                                        .split('@')
                                        .first ??
                                    tr('il_b512d97e7c'))
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
          content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
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
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
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
                          tr(
                            'videos_comments_title',
                            namedArgs: {'title': title},
                          ),
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
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4caf50),
                          ),
                        );
                      }

                      final comments = snapshot.data!;

                      if (comments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.comment_outlined,
                                size: 64,
                                color: Colors.white54,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                tr('il_6b25808365'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                tr('il_comment_empty_cta'),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
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
                            'userId': (raw['user_id'] ?? '').toString(),
                            'authorName':
                                raw['author_name'] ?? tr('il_b764cdc0ea'),
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
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: tr('il_23c5f33170'),
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4caf50),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
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
                            icon: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _prefetchCommentUserProfile(String userId) async {
    if (userId.isEmpty ||
        _commentUserProfileCache.containsKey(userId) ||
        _commentUserProfileLoading.contains(userId)) {
      return;
    }
    _commentUserProfileLoading.add(userId);
    try {
      final data =
          await _sb
              .from('profiles')
              .select('display_name, avatar_url, email')
              .eq('id', userId)
              .maybeSingle() ??
          const <String, dynamic>{};
      final name =
          (data['display_name'] ??
                  data['email']?.toString().split('@').first ??
                  tr('il_b764cdc0ea'))
              .toString()
              .trim();
      final avatarUrl = (data['avatar_url'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _commentUserProfileCache[userId] = <String, String>{
          'name': name.isNotEmpty ? name : tr('il_b764cdc0ea'),
          'avatarUrl': avatarUrl,
        };
      });
    } catch (_) {
      // Ignore comment profile prefetch failures.
    } finally {
      _commentUserProfileLoading.remove(userId);
    }
  }

  Widget _buildCommentItem(Map<String, dynamic> commentData) {
    final userId = (commentData['userId'] ?? '').toString();
    final cachedProfile = userId.isNotEmpty
        ? _commentUserProfileCache[userId]
        : null;
    final authorName =
        (cachedProfile?['name'] ??
                commentData['authorName'] ??
                tr('il_b764cdc0ea'))
            .toString();
    final authorAvatarUrl = (cachedProfile?['avatarUrl'] ?? '').toString();
    if (userId.isNotEmpty && cachedProfile == null) {
      _prefetchCommentUserProfile(userId);
    }
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
                backgroundImage: authorAvatarUrl.isNotEmpty
                    ? NetworkImage(authorAvatarUrl)
                    : null,
                child: authorAvatarUrl.isEmpty
                    ? Text(
                        authorName.isNotEmpty
                            ? authorName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            authorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (timeAgo.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
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
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return tr(
        'relative_minutes_ago',
        namedArgs: {'n': '${difference.inMinutes}'},
      );
    } else if (difference.inHours < 24) {
      return tr(
        'relative_hours_ago',
        namedArgs: {'n': '${difference.inHours}'},
      );
    } else if (difference.inDays < 7) {
      return tr(
        'relative_days_ago',
        namedArgs: {'n': '${difference.inDays}'},
      );
    } else {
      return tr(
        'relative_weeks_ago',
        namedArgs: {'n': '${(difference.inDays / 7).floor()}'},
      );
    }
  }

  void _addComment(String videoId) {
    // TODO: Implement add comment
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('il_86646f9499'))));
  }

  Widget _buildVideoCard(Map<String, dynamic> videoData) {
    final videoId = videoData['id'];
    final title = videoData['title'] ?? tr('il_f59ab8d133');
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                    Expanded(child: UserChip(userId: userId, showName: true)),
                    if (rating > 0)
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFF4caf50),
                            size: 16,
                          ),
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
                            const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              likeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
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
                              const Icon(
                                Icons.comment,
                                color: Colors.blue,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                commentsCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
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
                                    .map(
                                      (rows) => rows
                                          .where(
                                            (r) =>
                                                (r['user_id'] ?? '')
                                                    .toString() ==
                                                AppAuth.currentUserId!,
                                          )
                                          .toList(),
                                    ),
                          builder: (context, likeSnap) {
                            final isLiked =
                                (likeSnap.data?.isNotEmpty ?? false);
                            return IconButton(
                              onPressed: () => _toggleLike(videoId, isLiked),
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.white70,
                                size: 20,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () => _shareVideo(videoId, title),
                          icon: const Icon(
                            Icons.share,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                        if (AppAuth.currentUserId == userId)
                          IconButton(
                            tooltip: tr('videos_request_rating_tooltip'),
                            onPressed: () =>
                                _requestRatingForVideo(videoId, title),
                            icon: const Icon(
                              Icons.notifications_active,
                              color: Colors.white70,
                              size: 20,
                            ),
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
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),
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
          label: tr(
            'video_avg_rating_label',
            namedArgs: {'rating': avg.toStringAsFixed(2)},
          ),
          color: Colors.black.withOpacity(0.7),
        );
      },
    );
  }
}
