import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_player_screen.dart';
import '../constants/video_categories.dart';
import '../models/challenge.dart';
import '../widgets/rating_display.dart';
import '../widgets/video_preview_box.dart';
import '../services/notification_service.dart';
import '../services/rating_service.dart';
import '../utils/i18n.dart';
import '../widgets/player_avatar_button.dart';
import '../widgets/mode_speed_dial.dart';

class VideoMainScreen extends StatefulWidget {
  @override
  _VideoMainScreenState createState() => _VideoMainScreenState();
}

class _VideoMainScreenState extends State<VideoMainScreen> {
  final NotificationService _notificationService = NotificationService();
  final RatingService _ratingService = RatingService();
  String _selectedCity = '';
  String _selectedCategory = '';
  String _selectedRating = '';
  String _selectedTab = 'all'; // all, challenges, trending
  bool _showOnlyMyVideos = false;
  bool _showOnlyMyChallenges = false;
  final Map<String, double> _videoRatingCache = {};
  final Set<String> _videoRatingLoading = {};
  final Map<String, int> _commentCountCache = {};
  final Set<String> _commentCountLoading = {};
  final Map<String, _CachedUserProfile> _userProfileCache = {};
  final Set<String> _loadingUserProfiles = {};
  final Map<String, _CachedChallengeMeta> _challengeMetaCache = {};
  final Set<String> _challengeMetaLoading = {};
  final Set<String> _challengeMetaDenied = {};
  late Stream<QuerySnapshot> _videosStream;
  bool _didInitFromRouteArgs = false;
  

  List<String> get _cities => [
    I18n.t('all_cities'),
    I18n.t('kyiv'),
    I18n.t('lviv'),
    I18n.t('odesa'),
    I18n.t('kharkiv'),
    I18n.t('dnipro'),
  ];

  List<String> get _ratings => [
    I18n.inline('Всі рейтинги', 'All ratings'),
    '4.0+',
    '4.5+',
  ];

  String _selectedCategoryLabel() {
    if (_selectedCategory.isEmpty) {
      return I18n.inline('Всі категорії', 'All categories');
    }
    return videoCategoryById(_selectedCategory)?.label() ??
        videoCategoryLabel(_selectedCategory);
  }

int _compareVideoDocs(
  QueryDocumentSnapshot<Object?> a,
  QueryDocumentSnapshot<Object?> b,
) {
  final dataA = a.data() as Map<String, dynamic>? ?? const {};
  final dataB = b.data() as Map<String, dynamic>? ?? const {};
    if (_selectedTab == 'trending' && !_showOnlyMyVideos) {
      final viewsA = (dataA['views'] ?? 0) as num;
      final viewsB = (dataB['views'] ?? 0) as num;
      final cmp = viewsB.compareTo(viewsA);
      if (cmp != 0) return cmp;
    }
    final tsA =
        (dataA['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    final tsB =
        (dataB['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    return tsB.compareTo(tsA);
  }

  @override
  void initState() {
    super.initState();
    _videosStream = _createVideosStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitFromRouteArgs) return;
    _didInitFromRouteArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map &&
        (args['myContent'] == 'videos' || args['myContent'] == 'challenges')) {
      _showOnlyMyVideos = args['myContent'] == 'videos';
      _showOnlyMyChallenges = args['myContent'] == 'challenges';
      _selectedTab = _showOnlyMyChallenges ? 'challenges' : 'all';
      _videosStream = _createVideosStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23), // Темний фон як у HTML MVP
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23).withValues(alpha: 0.95),
        elevation: 0,
        title: InkWell(
          onTap: () => Navigator.pushNamed(context, '/mode'),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/logo/flap_logo.jpg',
                    fit: BoxFit.cover, width: 28, height: 28),
              ),
              const SizedBox(width: 8),
            ],
          ),
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
            if (!_showOnlyMyVideos && !_showOnlyMyChallenges)
  Container(
    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
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
            if (_selectedTab != 'challenges' && !_showOnlyMyVideos && !_showOnlyMyChallenges)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    // Швидкі категорії (як у HTML MVP)
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: quickVideoCategories()
                            .map(
                              (category) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selected: _selectedCategory == category.id,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategory =
                                          selected ? category.id : '';
                                    });
                                  },
                                  label: Text(category.label()),
                                  selectedColor: const Color(0xFF4caf50),
                                  labelStyle: TextStyle(
                                    color: _selectedCategory == category.id
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // City and Category filters
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown(
                            _cities,
                            _selectedCity.isEmpty
                                ? I18n.t('all_cities')
                                : _selectedCity,
                            (value) {
                              setState(() {
                                _selectedCity = value == I18n.t('all_cities') ? '' : value;
                              });
                            },
                            '🏙️',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCategoryFilterDropdown(),
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
      floatingActionButton: ModeSpeedDial(
        shortcuts: [
          ModeDialAction(
            icon: Icons.sports_soccer,
            tooltip: I18n.t('matches'),
            onTap: () => Navigator.pushNamed(context, '/matches'),
          ),
          ModeDialAction(
            icon: Icons.groups_outlined,
            tooltip: I18n.t('teams'),
            onTap: () => Navigator.pushNamed(context, '/teams'),
          ),
        ],
        onCreate: _showVideoCreateSheet,
        createTooltip: I18n.inline('Додати контент', 'Create content'),
        createGradient: const [Color(0xFFFF6B35), Color(0xFFFF8A65)],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showVideoCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: Colors.white),
              title: Text(I18n.t('upload_video'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/video-upload');
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined,
                  color: Colors.white),
              title: Text(I18n.t('create_challenge'),
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/challenge-create');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoChip(
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: chip,
    );
  }

  Widget _buildCategoryLabel(String label, Color color, {VoidCallback? onTap}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: pill,
    );
  }

  Color _videoCategoryColor(String category) => videoCategoryColor(category);

  bool _isUnknownLabel(String value) {
    final normalized = value.toLowerCase().trim();
    return normalized.isEmpty ||
        normalized == 'невідомо' ||
        normalized == 'unknown';
  }

  Color _challengeTypeColor(String type) {
    switch (parseChallengeType(type)) {
      case ChallengeType.goal:
        return const Color(0xFFFF7043);
      case ChallengeType.shotPower:
        return const Color(0xFFD84315);
      case ChallengeType.pass:
        return const Color(0xFF66BB6A);
      case ChallengeType.longPass:
        return const Color(0xFF26C6DA);
      case ChallengeType.dribbling:
        return const Color(0xFFAB47BC);
      case ChallengeType.tackle:
        return const Color(0xFF8D6E63);
      case ChallengeType.penalty:
        return const Color(0xFFFFC107);
      case ChallengeType.save:
        return const Color(0xFF42A5F5);
      case ChallengeType.wall:
        return const Color(0xFF455A64);
      case ChallengeType.strategy:
        return const Color(0xFF26A69A);
      case ChallengeType.trick:
        return const Color(0xFFFFCA28);
      case ChallengeType.other:
        return const Color(0xFF78909C);
    }
  }

  String _challengeTypeLabel(String type) {
    switch (parseChallengeType(type)) {
      case ChallengeType.goal:
        return I18n.inline('Гол', 'Goal');
      case ChallengeType.shotPower:
        return I18n.inline('Сила удару', 'Shot power');
      case ChallengeType.pass:
        return I18n.inline('Пас', 'Pass');
      case ChallengeType.longPass:
        return I18n.inline('Довгий пас', 'Long pass');
      case ChallengeType.dribbling:
        return I18n.inline('Дриблінг', 'Dribbling');
      case ChallengeType.tackle:
        return I18n.inline('Підкат', 'Tackle');
      case ChallengeType.penalty:
        return I18n.inline('Пенальті', 'Penalty');
      case ChallengeType.save:
        return I18n.inline('Сейв', 'Save');
      case ChallengeType.wall:
        return I18n.inline('Стіна / стандарт', 'Wall / set-piece');
      case ChallengeType.strategy:
        return I18n.inline('Стратегія', 'Strategy');
      case ChallengeType.trick:
        return I18n.inline('Трюк', 'Trick');
      case ChallengeType.other:
        return I18n.inline('Інше', 'Other');
    }
  }

  Widget _buildRatingBadge(String? ratingText) {
    final hasRating = ratingText != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
          const SizedBox(width: 4),
          Text(
            ratingText ?? I18n.inline('Немає', 'No rating'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: hasRating ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _prefetchVideoRating(String videoId) async {
    if (_videoRatingCache.containsKey(videoId) ||
        _videoRatingLoading.contains(videoId)) {
      return;
    }
    _videoRatingLoading.add(videoId);
    try {
      final votesSnap = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('votes')
          .get();
      double sum = 0.0;
      for (final doc in votesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        sum += (data['rating'] ?? 0.0).toDouble();
      }
      final avg = votesSnap.docs.isEmpty
          ? 0.0
          : double.parse((sum / votesSnap.docs.length).toStringAsFixed(2));
      if (mounted) {
        setState(() {
          _videoRatingCache[videoId] = avg;
        });
      }
    } catch (_) {
      // ignore
    } finally {
      _videoRatingLoading.remove(videoId);
    }
  }

  void _prefetchCommentCount(String videoId) async {
    if (_commentCountCache.containsKey(videoId) ||
        _commentCountLoading.contains(videoId)) {
      return;
    }
    _commentCountLoading.add(videoId);
    try {
      final aggregate = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .count()
          .get();
      final count = aggregate.count ?? 0;
      if (mounted) {
        setState(() {
          _commentCountCache[videoId] = count;
        });
      }
    } catch (_) {
      // ignore
    } finally {
      _commentCountLoading.remove(videoId);
    }
  }

  void _prefetchUserProfile(String userId) async {
    if (userId.isEmpty ||
        _userProfileCache.containsKey(userId) ||
        _loadingUserProfiles.contains(userId)) {
      return;
    }
    _loadingUserProfiles.add(userId);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data() ?? const <String, dynamic>{};
      final resolvedName = (data['displayName'] ??
              data['name'] ??
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim())
          .toString()
          .trim();
      final avatar = (data['avatarUrl'] ?? data['avatar'] ?? '').toString();
      final profileCity = (data['city'] ?? '').toString();
      if (mounted) {
        setState(() {
          _userProfileCache[userId] = _CachedUserProfile(
            name: resolvedName.isNotEmpty
                ? resolvedName
                : I18n.inline('Користувач', 'User'),
            avatarUrl: avatar,
            city: profileCity,
          );
        });
      }
    } catch (_) {
      // ignore
    } finally {
      _loadingUserProfiles.remove(userId);
    }
  }

  void _prefetchChallengeMetaForVideo(String videoId) async {
    if (_challengeMetaCache.containsKey(videoId) ||
        _challengeMetaLoading.contains(videoId) ||
        _challengeMetaDenied.contains(videoId)) {
      return;
    }
    _challengeMetaLoading.add(videoId);
    try {
      final submissions = await FirebaseFirestore.instance
          .collectionGroup('submissions')
          .where('videoId', isEqualTo: videoId)
          .limit(1)
          .get();
      if (submissions.docs.isEmpty) return;
      final doc = submissions.docs.first;
      final challengeRef = doc.reference.parent.parent;
      if (challengeRef == null) return;
      final challengeSnap = await challengeRef.get();
      if (!challengeSnap.exists) return;
      final challengeData =
          challengeSnap.data() as Map<String, dynamic>? ?? const {};
      final title = (challengeData['title'] ?? '').toString();
      final challengeId = challengeRef.id;
      if (mounted) {
        setState(() {
          _challengeMetaCache[videoId] = _CachedChallengeMeta(
            challengeId: challengeId,
            title: title,
          );
        });
      }
    } on FirebaseException catch (e) {
  if (e.code == 'permission-denied') {
    _challengeMetaDenied.add(videoId);
    // блокуємо повторні запити для цього videoId, щоб не було "спаму" у логах
    _challengeMetaCache[videoId] = const _CachedChallengeMeta(
      challengeId: '',
      title: '',
    );
    return;
  }
  debugPrint('Error prefetching challenge meta for video $videoId: $e');
} catch (e) {
  debugPrint('Error prefetching challenge meta for video $videoId: $e');
} finally {
      _challengeMetaLoading.remove(videoId);
    }
  }

  Future<void> _showRateVideoSheet({
    required String videoId,
    required String videoTitle,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline(
              'Увійдіть, щоб оцінювати відео', 'Sign in to rate videos')),
        ),
      );
      return;
    }

    try {
      final existingVote = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('votes')
          .doc(currentUser.uid)
          .get();
      if (existingVote.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline(
                'Ви вже оцінили це відео', 'You already rated this video')),
          ),
        );
        return;
      }
    } catch (_) {}

    double overall = 3.0;
    double technical = 3.0;
    double creativity = 3.0;
    double difficulty = 3.0;
    double quality = 3.0;
    bool advanced = false;
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          Widget sliderTile(
            String label,
            double value,
            ValueChanged<double> onChanged,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: value,
                  min: 0,
                  max: 5,
                  divisions: 50,
                  label: value.toStringAsFixed(1),
                  activeColor: const Color(0xFFFFC107),
                  onChanged: onChanged,
                ),
              ],
            );
          }

          Future<void> submitVote() async {
            if (submitting) return;
            setModalState(() => submitting = true);
            final criteria = advanced
                ? <String, double>{
                    'technical': technical,
                    'creativity': creativity,
                    'difficulty': difficulty,
                    'quality': quality,
                  }
                : <String, double>{
                    'technical': overall,
                    'creativity': overall,
                    'difficulty': overall,
                    'quality': overall,
                  };
            try {
              final success = await _ratingService.rateVideo(
                videoId: videoId,
                ratedBy: currentUser.uid,
                criteria: criteria,
              );
              if (!mounted) return;
              if (success) {
                Navigator.pop(sheetContext);
                setState(() {
                  _videoRatingCache.remove(videoId);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(I18n.inline(
                        'Оцінку збережено', 'Rating submitted')),
                  ),
                );
                _prefetchVideoRating(videoId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(I18n.inline(
                        'Не вдалося зберегти оцінку', 'Unable to save rating')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    I18n.inline('Помилка: $e', 'Error: $e'),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            } finally {
              if (mounted) {
                setModalState(() => submitting = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    I18n.inline('Оцініть відео', 'Rate video'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    videoTitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => advanced = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !advanced
                                    ? const Color(0xFF4caf50)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                I18n.inline('Простий', 'Simple'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !advanced
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: !advanced
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => advanced = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: advanced
                                    ? const Color(0xFF4caf50)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                I18n.inline('Розширений', 'Advanced'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: advanced
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: advanced
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (advanced) ...[
                    sliderTile(I18n.inline('Техніка', 'Technical'), technical,
                        (v) => setModalState(() => technical = v)),
                    sliderTile(
                        I18n.inline('Креативність', 'Creativity'),
                        creativity,
                        (v) => setModalState(() => creativity = v)),
                    sliderTile(
                        I18n.inline('Складність', 'Difficulty'),
                        difficulty,
                        (v) => setModalState(() => difficulty = v)),
                    sliderTile(
                        I18n.inline('Якість відео', 'Video quality'),
                        quality,
                        (v) => setModalState(() => quality = v)),
                  ] else ...[
                    sliderTile(
                      I18n.inline('Загальна оцінка', 'Overall rating'),
                      overall,
                      (v) => setModalState(() => overall = v),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: submitting ? null : submitVote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        disabledBackgroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        submitting
                            ? I18n.inline('Надсилаємо...', 'Submitting...')
                            : I18n.inline('Оцінити відео', 'Submit rating'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab(String title, String tab) {
    final isActive = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
      onTap: () {
        if (_selectedTab == tab) return;
        setState(() {
          _selectedTab = tab;
          if (tab != 'challenges') {
            _videosStream = _createVideosStream();
          }
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
                color: const Color(0xFF4caf50).withValues(alpha: 0.4),
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
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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

  Widget _buildCategoryFilterDropdown() {
    final items = [
      DropdownMenuItem<String>(
        value: '',
        child: Text(
          I18n.inline('Всі категорії', 'All categories'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      ...kVideoCategories.map(
        (category) => DropdownMenuItem<String>(
          value: category.id,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.label(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (category.description().isNotEmpty)
                Text(
                  category.description(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: items,
          onChanged: (String? newValue) {
            setState(() {
              _selectedCategory = newValue ?? '';
            });
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
  if (_showOnlyMyVideos) {
    return _buildMyVideosList();
  }
  if (_showOnlyMyChallenges) {
    return _buildChallengesList();
  }

  switch (_selectedTab) {
    case 'challenges':
      return _buildChallengesList();
    case 'trending':
      return _buildTrendingVideos();
    default:
      return _buildVideosList();
  }
}

  Widget _buildVideosList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _videosStream,
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
                    color: Colors.white.withValues(alpha: 0.8),
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
          
          // Фільтр рейтингу
          if (_selectedRating.isNotEmpty) {
            final minRating = double.parse(_selectedRating.replaceAll('+', ''));
            final ratingRaw = _videoRatingCache[d.id] ??
                data['rating'] ??
                data['averageRating'] ??
                data['voteAverage'] ??
                0.0;
            final r = ratingRaw is num
                ? ratingRaw.toDouble()
                : double.tryParse(ratingRaw.toString()) ?? 0.0;
            if (r < minRating) return false;
          }
          
          // Фільтр категорії
          if (_selectedCategory.isNotEmpty) {
            final categoryValue = (data['category'] ?? '').toString();
            final normalized = normalizeVideoCategoryValue(categoryValue);
            if (normalized != _selectedCategory) return false;
          }
          
          // Фільтр міста
          if (_selectedCity.isNotEmpty) {
            final city = data['city'] ?? '';
            if (city != _selectedCity) return false;
          }
          
          return true;
        }).toList()
          ..sort(_compareVideoDocs);

        return ListView.builder(
          key: PageStorageKey<String>(
            'videos-list-$_selectedTab-${_showOnlyMyVideos ? "mine" : "all"}',
          ),
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

  Stream<QuerySnapshot> _createVideosStream() {
    Query query = FirebaseFirestore.instance.collection('videos');
    final filteringOwnVideos = _showOnlyMyVideos;
    
    if (filteringOwnVideos) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) query = query.where('userId', isEqualTo: uid);
    }
    
    // Remove city and category filters from Firestore query to avoid composite index issues
    // These will be applied on the client side in _buildVideosList()
    
    // Apply tab filters
    if (!filteringOwnVideos) {
      switch (_selectedTab) {
        case 'trending':
          query = query.orderBy('views', descending: true);
          break;
        default:
          query = query.orderBy('createdAt', descending: true);
      }
    } else {
      // Sorting for personal feed handled client-side to avoid composite indexes
    }
    
    return query.snapshots();
  }

  Widget _buildVideoCard(Map<String, dynamic> data, String videoId) {
    final title = (data['title'] ?? I18n.inline('Без назви', 'No title')).toString();
    final description = (data['description'] ?? '').toString();
    final rawCategory = (data['category'] ?? '').toString();
    final categoryLabel = rawCategory.isEmpty
        ? I18n.inline('Без категорії', 'No category')
        : videoCategoryLabel(rawCategory);
    final ratingRaw = data['rating'] ?? data['averageRating'] ?? data['voteAverage'] ?? 0.0;
    final double rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw.toString()) ?? 0.0;
    final views = (data['views'] ?? 0) as num;
    final likes = (data['likes'] ?? 0) as num;
    final commentsValue = (data['comments'] ?? data['commentCount'] ?? 0) as num;
    double displayRating = rating;
    final cachedRating = _videoRatingCache[videoId];
    if (displayRating <= 0 && cachedRating != null) {
      displayRating = cachedRating;
    } else if (displayRating <= 0 &&
        !_videoRatingLoading.contains(videoId)) {
      _prefetchVideoRating(videoId);
    }

    int displayComments = commentsValue.toInt();
    final cachedComments = _commentCountCache[videoId];
    if (cachedComments != null) {
      displayComments = cachedComments;
    } else if (!_commentCountLoading.contains(videoId)) {
      _prefetchCommentCount(videoId);
    }

    String authorDisplayName = (data['authorName'] ??
            data['displayName'] ??
            data['userName'] ??
            I18n.inline('Невідомо', 'Unknown'))
        .toString();
    final authorId = data['userId'] as String?;
    String? authorAvatar;
    _CachedUserProfile? cachedProfile;
    if (authorId != null && authorId.isNotEmpty) {
      cachedProfile = _userProfileCache[authorId];
      if (cachedProfile != null) {
        authorDisplayName = cachedProfile.name;
        authorAvatar = cachedProfile.avatarUrl;
      } else {
        _prefetchUserProfile(authorId);
      }
    }
    final rawCity = (data['city'] ?? '').toString();
    String locationLabel = rawCity.trim();
    if (locationLabel.isEmpty || _isUnknownLabel(locationLabel)) {
      final fallbackCity = cachedProfile?.city?.trim() ?? '';
      locationLabel = fallbackCity.isNotEmpty
          ? fallbackCity
          : I18n.inline('Невідомо', 'Unknown');
    }
    final createdAt = data['createdAt'] as Timestamp?;
    final isLiked = data['isLikedByCurrentUser'] == true;
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final thumbnailUrl = data['thumbnailUrl']?.toString();
    final durationSeconds = data['duration'] is int ? data['duration'] as int : null;
    final categoryColor = _videoCategoryColor(rawCategory);
    String resolvedChallengeId = (data['challengeId'] ?? '').toString();
    String resolvedChallengeTitle = (data['challengeTitle'] ?? '').toString();
    final bool isChallengeVideo = resolvedChallengeId.isNotEmpty ||
        title == 'Відео челенджу' ||
        description == 'Відео челенджу' ||
        (data['isChallengeVideo'] == true);
    final bool hasChallengeInfo = isChallengeVideo || resolvedChallengeTitle.isNotEmpty;

    if (hasChallengeInfo && resolvedChallengeId.isEmpty) {
      final cachedMeta = _challengeMetaCache[videoId];
      if (cachedMeta != null) {
        resolvedChallengeId = cachedMeta.challengeId;
        if (resolvedChallengeTitle.isEmpty) {
          resolvedChallengeTitle = cachedMeta.title;
        }
      } else if (!_challengeMetaLoading.contains(videoId) &&
          !_challengeMetaDenied.contains(videoId)) {
        _prefetchChallengeMetaForVideo(videoId);
      }
    }

    final bool hasChallengeLink = resolvedChallengeId.isNotEmpty;
    final String challengeLabel = resolvedChallengeTitle.isNotEmpty
        ? resolvedChallengeTitle
        : I18n.inline('Челендж', 'Challenge');
    final Color challengeColor = const Color(0xFFFFC107);

    final badges = <Widget>[];
    if (hasChallengeInfo) {
      badges.add(
        _buildVideoChip(
          challengeLabel,
          challengeColor,
          onTap: hasChallengeLink
              ? () => _openChallenge(
                    resolvedChallengeId,
                    challengeLabel,
                  )
              : null,
        ),
      );
      badges.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _buildVideoChip(categoryLabel, categoryColor),
        ),
      );
    } else {
      badges.add(_buildVideoChip(categoryLabel, categoryColor));
    }

    final safeTitle = (hasChallengeInfo && challengeLabel.isNotEmpty)
        ? challengeLabel
        : (title.isEmpty ? I18n.inline('Без назви', 'Untitled') : title);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoPreviewBox(
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            borderRadius: 20,
            onTap: () => _openVideo(
              videoId: videoId,
              videoUrl: videoUrl,
              title: safeTitle,
              authorName: authorDisplayName,
            ),
            topLeft: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: badges,
            ),
            topRight: _buildRatingBadge(
              displayRating > 0 ? displayRating.toStringAsFixed(2) : null,
            ),
            bottomRight: _buildMetaPill(
              durationSeconds != null
                  ? _formatDuration(durationSeconds)
                  : (views > 0
                      ? I18n.inline('$views переглядів', '$views views')
                      : I18n.inline('Новинка', 'New')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildCategoryLabel(
                      hasChallengeInfo ? challengeLabel : categoryLabel,
                      hasChallengeInfo ? challengeColor : categoryColor,
                      onTap: hasChallengeInfo && hasChallengeLink
                          ? () => _openChallenge(
                            resolvedChallengeId,
                                challengeLabel,
                              )
                          : null,
                    ),
                    const Spacer(),
                    _videoInfoChip(
                      icon: Icons.remove_red_eye,
                      label: views.toString(),
                    ),
                    const SizedBox(width: 6),
                    _videoInfoChip(
                      icon: Icons.chat_bubble_outline,
                      label: displayComments.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  safeTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    PlayerAvatarButton(
                      userId: authorId ?? '',
                      displayName: authorDisplayName,
                      avatarUrl: authorAvatar,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (authorId != null) {
                            Navigator.pushNamed(
                              context,
                              '/player-profile',
                              arguments: {
                                'playerId': authorId,
                                'playerName': authorDisplayName,
                              },
                            );
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorDisplayName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$locationLabel • ${_formatDate(createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (authorId != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: CompactRatingDisplay(userId: authorId, size: 16),
                      ),
                  ],
                ),
                if (resolvedChallengeId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _openChallenge(resolvedChallengeId, challengeLabel),
                    icon: const Icon(Icons.emoji_events_outlined, color: Colors.white70),
                    label: Text(
                      I18n.inline('До челенджу', 'Open challenge'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _iconCircleButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      tooltip: I18n.inline('Подобається', 'Like'),
                      iconColor: isLiked ? Colors.redAccent : Colors.white,
                      background: isLiked ? Colors.redAccent.withOpacity(0.15) : Colors.white10,
                      onPressed: () => _toggleLike(videoId, isLiked),
                      trailing: likes.toString(),
                    ),
                    const SizedBox(width: 8),
                    _iconCircleButton(
                      icon: Icons.chat_bubble_outline,
                      tooltip: I18n.t('comments'),
                      onPressed: () => _showComments(videoId, safeTitle),
                      trailing: displayComments.toString(),
                    ),
                    const SizedBox(width: 8),
                    _iconCircleButton(
                      icon: Icons.share,
                      tooltip: I18n.inline('Поділитися', 'Share'),
                      onPressed: () => _shareVideo(videoId, safeTitle),
                    ),
                    const Spacer(),
                    _iconCircleButton(
                      icon: Icons.play_arrow_rounded,
                      tooltip: I18n.inline('Дивитися', 'Watch'),
                      background: const Color(0xFF4caf50),
                      onPressed: () => _openVideo(
                        videoId: videoId,
                        videoUrl: videoUrl,
                        title: safeTitle,
                        authorName: authorDisplayName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _iconCircleButton(
                      icon: Icons.star_rate_rounded,
                      tooltip: I18n.inline('Проголосувати', 'Vote'),
                      background: const Color(0xFFFFC107),
                      onPressed: () => _showRateVideoSheet(
                        videoId: videoId,
                        videoTitle: safeTitle,
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

  Widget _buildChallengeTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.black87, size: 14),
          const SizedBox(width: 4),
          Text(
            I18n.inline('Челендж', 'Challenge'),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color background = Colors.white12,
    Color iconColor = Colors.white,
    String? tooltip,
    String? trailing,
  }) {
    final content = Container(
      padding: trailing != null
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            Text(
              trailing!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    final button = InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onPressed,
      child: content,
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }

  Future<void> _openVideo({
    required String videoId,
    required String videoUrl,
    required String title,
    required String authorName,
    bool autoRate = false,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .update({'views': FieldValue.increment(1)});
    } catch (_) {}
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
          authorName: authorName,
          videoId: videoId,
          autoOpenRating: autoRate,
        ),
      ),
    );
    if (result is Map && result['ratingUpdated'] == true) {
      setState(() {
        _videoRatingCache.remove(videoId);
      });
      _prefetchVideoRating(videoId);
    }
  }

  Future<void> _openChallenge(String challengeId, String title) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();
      if (!doc.exists) {
        throw Exception('Challenge not found');
      }
      final challenge = Challenge.fromFirestore(doc);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/challenge-details',
        arguments: challenge,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Не вдалося відкрити челендж: $e',
              'Unable to open challenge: $e',
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return I18n.inline('Нещодавно', 'Recently');
    
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return I18n.inline(
        '${difference.inDays} дн. тому',
        '${difference.inDays} d ago',
      );
    } else if (difference.inHours > 0) {
      return I18n.inline(
        '${difference.inHours} год. тому',
        '${difference.inHours} h ago',
      );
    } else if (difference.inMinutes > 0) {
      return I18n.inline(
        '${difference.inMinutes} хв. тому',
        '${difference.inMinutes} min ago',
      );
    } else {
      return I18n.inline('Щойно', 'Just now');
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
                        color: Colors.white.withValues(alpha: 0.8),
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
        Query q = FirebaseFirestore.instance.collection('challenges');
        if (_showOnlyMyChallenges) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            q = q.where('creatorId', isEqualTo: uid);
          }
          q = q.limit(20);
        } else {
          q = q.orderBy('createdAt', descending: true).limit(20);
        }
        return q.snapshots();
      })(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              I18n.inline('Помилка: ${snapshot.error}', 'Error: ${snapshot.error}'),
            ),
          );
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
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                    I18n.inline('Поки що немає челенджів', 'No challenges yet'),
                    style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                    I18n.inline(
                      'Створіть перший челендж або дочекайтеся нових!',
                      'Create your first challenge or wait for new ones!',
                    ),
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
                  child: Text(
                    I18n.inline('Створити челендж', 'Create challenge'),
                    style: const TextStyle(color: Colors.white),
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
    final type = (challenge['type'] ?? 'goal').toString();
    final accent = _challengeTypeColor(type);
    final currentParticipants = challenge['currentParticipants'] ?? 0;
    final maxParticipants = challenge['maxParticipants'] ?? 50;
    final prizePool = (challenge['prizePool'] ?? 0.0).toDouble();
    final entryFee = challenge['entryFee'] ?? 10;
    final duration = challenge['duration'] ?? 7;
    final creatorId = (challenge['creatorId'] ?? '').toString();
    final creatorName = (challenge['creatorName'] ??
            I18n.inline('Невідомо', 'Unknown'))
        .toString();
    final creatorVideoUrl =
        (challenge['creatorVideoUrl'] ?? '').toString();
    final creatorThumbnailUrl =
        (challenge['creatorThumbnailUrl'] ?? challenge['thumbnailUrl'] ?? '')
            .toString();
    final participants =
        List<String>.from(challenge['participants'] ?? const []);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accent.withValues(alpha: 0.8)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
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
                  challenge['title'] ?? I18n.inline('Без назви', 'Untitled'),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
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
                const SizedBox(height: 6),
                _buildCategoryLabel(_challengeTypeLabel(type), accent),
                const SizedBox(height: 8),
                Text(
                  challenge['description'] ??
                      I18n.inline('Без опису', 'No description'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
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
                    _buildUserAvatarChip(
                      userId: creatorId,
                      name: creatorName,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creatorName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            I18n.inline('Автор челенджу', 'Challenge author'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.access_time, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$duration ${I18n.inline('днів', 'days')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (creatorVideoUrl.isNotEmpty || creatorThumbnailUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VideoPreviewBox(
                videoUrl: creatorVideoUrl.isNotEmpty ? creatorVideoUrl : null,
                thumbnailUrl: creatorThumbnailUrl.isNotEmpty
                    ? creatorThumbnailUrl
                    : null,
                borderRadius: 18,
                onTap: creatorVideoUrl.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(
                              videoUrl: creatorVideoUrl,
                              title: challenge['title'] ??
                                  I18n.inline('Відео челенджу', 'Challenge video'),
                              authorName: creatorName,
                              videoId: challengeId,
                            ),
                          ),
                        );
                      },
                topLeft: _buildMetaPill(
                  I18n.inline('Відео організатора', 'Organizer video'),
                ),
              ),
            ),
          ],

          // Інформація про челендж
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
            child: Column(
              children: [
                Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                          Text(
                            '${I18n.inline('Прогрес', 'Progress')}: '
                            '$currentParticipants/$maxParticipants',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${((currentParticipants / maxParticipants) * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                    ),
                  ],
                ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: currentParticipants / maxParticipants,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
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
                        label: I18n.inline('Учасники', 'Participants'),
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.attach_money,
                        value: '$entryFee',
                        label: I18n.inline('Вхід', 'Entry'),
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.emoji_events,
                        value: '${prizePool.toInt()}',
                        label: I18n.inline('Приз', 'Prize'),
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
                              color: const Color(0xFF2196F3).withValues(alpha: 0.3),
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
                          label: Text(
                            I18n.inline('Переглянути', 'View'),
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
                              color: const Color(0xFF4caf50).withValues(alpha: 0.4),
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
                          label: Text(
                            I18n.inline('Участь', 'Join'),
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
                if (participants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildParticipantsRow(participants),
                ],
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
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
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsRow(List<String> ids) {
    final preview = ids.take(5).toList();
    final remaining = ids.length - preview.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_2, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              I18n.inline('Учасники', 'Participants'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ...preview.map(
              (id) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildUserAvatarChip(
                  userId: id,
                  size: 34,
                ),
              ),
            ),
            if (remaining > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserAvatarChip({
    required String userId,
    String? name,
    double size = 36,
  }) {
    if (userId.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white.withOpacity(0.1),
        child: const Icon(Icons.person, color: Colors.white70),
      );
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final resolvedName = (data?['displayName'] ??
                data?['name'] ??
                data?['authorName'] ??
                name ??
                I18n.inline('Гравець', 'Player'))
            .toString();
        final avatarUrl =
            (data?['avatarUrl'] ?? data?['avatar'] ?? '').toString();
        return PlayerAvatarButton(
          userId: userId,
          displayName: resolvedName,
          avatarUrl: avatarUrl,
          size: size,
        );
      },
    );
  }

  Widget _videoInfoChip({
    required IconData icon,
    required String label,
    bool highlight = false,
  }) {
    final color =
        highlight ? const Color(0xFFFFD54F) : Colors.white.withOpacity(0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? color.withOpacity(0.25)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight ? color.withOpacity(0.6) : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: highlight ? Colors.white : Colors.white70,
              fontSize: 11,
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
          return Center(
            child: Text(
              I18n.inline('Помилка: ${snapshot.error}', 'Error: ${snapshot.error}'),
            ),
          );
                  }

        final videos = snapshot.data?.docs ?? [];

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  I18n.inline('У вас поки що немає відео', 'You have no videos yet'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18n.inline('Завантажте своє перше відео!', 'Upload your first video!'),
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
                  child: Text(
                    I18n.inline('Завантажити відео', 'Upload video'),
                    style: const TextStyle(color: Colors.white),
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
      stream: _videosStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              I18n.inline('Помилка: ${snapshot.error}', 'Error: ${snapshot.error}'),
            ),
          );
        }

        final videos = snapshot.data?.docs ?? [];

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  I18n.inline('Поки що немає трендових відео', 'No trending videos yet'),
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
          key: const PageStorageKey<String>('trending-videos-list'),
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
          I18n.inline('Приєднатися до челенджу', 'Join challenge'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              I18n.inline(
                'Ви приєднуєтеся до челенджу "${challenge['title']}"',
                'You are joining the challenge "${challenge['title']}"',
              ),
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              I18n.inline(
                'Ставка входу: ${challenge['entryFee'] ?? 0} монет',
                'Entry fee: ${challenge['entryFee'] ?? 0} coins',
              ),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              I18n.t('cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
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
                  SnackBar(content: Text(I18n.inline('Помилка приєднання: $e', 'Join error: $e'))),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4caf50)),
            child: Text(
              I18n.inline('Завантажити відео', 'Upload video'),
              style: const TextStyle(color: Colors.white),
            ),
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
      type: parseChallengeType(challengeData['type'] as String?),
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
        SnackBar(content: Text(I18n.inline('Помилка лайку: $e', 'Like error: $e')), backgroundColor: Colors.red),
      );
    }
  }

  void _showComments(String videoId, String videoTitle) {
    final commentController = TextEditingController();
    final safeTitle = videoTitle.trim().isEmpty
        ? I18n.inline('відео', 'video')
        : videoTitle;
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
                color: Colors.white.withValues(alpha: 0.5),
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
                      'Коментарі до "$safeTitle"',
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
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Поки що немає коментарів',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Будьте першим, хто залишить коментар!',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
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
                      final userId = (comment['userId'] ?? '').toString();
                      final commentText =
                          (comment['comment'] ?? comment['text'] ?? '').toString();
                      final timestamp = comment['createdAt'] as Timestamp?;

                      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: userId.isEmpty
                            ? null
                            : FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnapshot) {
                          final userData = userSnapshot.data?.data() ?? const <String, dynamic>{};
                          final authorName = (userData['displayName'] ??
                                  userData['name'] ??
                                  userData['authorName'] ??
                                  'Користувач')
                              .toString();
                          final avatarUrl =
                              (userData['avatarUrl'] ?? userData['photoUrl'] ?? '').toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PlayerAvatarButton(
                                  userId: userId,
                                  displayName: authorName,
                                  avatarUrl: avatarUrl,
                                  size: 38,
                                  backgroundColor: const Color(0xFF4caf50),
                                  borderColor: Colors.white.withValues(alpha: 0.25),
                                  borderWidth: 1,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (userId.isEmpty) return;
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
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        commentText,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (timestamp != null)
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
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
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Написати коментар...',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (text) {
                          final value = text.trim();
                          if (value.isNotEmpty) {
                            _addComment(videoId, value);
                            commentController.clear();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      final value = commentController.text.trim();
                      if (value.isEmpty) return;
                      _addComment(videoId, value);
                      commentController.clear();
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
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
      return I18n.inline(
        '${difference.inDays} днів тому',
        '${difference.inDays} d ago',
      );
    } else if (difference.inHours > 0) {
      return I18n.inline(
        '${difference.inHours} годин тому',
        '${difference.inHours} h ago',
      );
    } else if (difference.inMinutes > 0) {
      return I18n.inline(
        '${difference.inMinutes} хвилин тому',
        '${difference.inMinutes} min ago',
      );
    } else {
      return I18n.inline('Щойно', 'Just now');
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

      _commentCountCache.remove(videoId);
      _prefetchCommentCount(videoId);

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
              InkWell(
                onTap: () => _showCoinsHistory(coins),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFffc107).withValues(alpha: 0.2),
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
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showRatingHistory(userData),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withValues(alpha: 0.2),
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
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCoinsHistory(int currentCoins) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFFFD700)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(I18n.inline('Мої монети', 'My coins'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            I18n.inline('Баланс: $currentCoins', 'Balance: $currentCoins'),
                            style: const TextStyle(color: Color(0xFFFFD700)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('userId', isEqualTo: uid)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          I18n.inline(
                            'Не вдалося завантажити історію монет',
                            'Unable to load coin history',
                          ),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                    }
                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final ad = a.data() as Map<String, dynamic>;
                        final bd = b.data() as Map<String, dynamic>;
                        final at = ad['timestamp'] as Timestamp?;
                        final bt = bd['timestamp'] as Timestamp?;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          I18n.inline('Поки немає транзакцій', 'No transactions yet'),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final amount = (data['amount'] ?? 0) as num;
                        final description = (data['description'] ?? '').toString();
                        final ts = data['timestamp'] as Timestamp?;
                        final timestampText = ts != null
                            ? _formatTimestamp(ts)
                            : I18n.inline('Нещодавно', 'Recently');
                        final isPositive = amount >= 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isPositive
                                      ? const Color(0xFF4caf50).withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  isPositive ? Icons.add : Icons.remove,
                                  color: isPositive ? const Color(0xFF4caf50) : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(description,
                                        style: const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.w600)),
                                    Text(
                                      timestampText,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isPositive ? '+' : ''}${amount.toString()}',
                                style: TextStyle(
                                  color: isPositive ? const Color(0xFF4caf50) : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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

  void _showRatingHistory(Map<String, dynamic> userData) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final currentRating = ((userData['rating'] ?? 0.0) as num).toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            I18n.inline('Історія рейтингу', 'Rating history'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            I18n.inline(
                              'Поточний рейтинг: ${currentRating.toStringAsFixed(2)}',
                              'Current rating: ${currentRating.toStringAsFixed(2)}',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF4caf50),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rating_history')
                      .where('userId', isEqualTo: uid)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          I18n.inline(
                            'Не вдалося завантажити історію рейтингу',
                            'Unable to load rating history',
                          ),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                      );
                    }

                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final ad = a.data() as Map<String, dynamic>;
                        final bd = b.data() as Map<String, dynamic>;
                        final at = ad['timestamp'] as Timestamp?;
                        final bt = bd['timestamp'] as Timestamp?;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          I18n.inline(
                            'Поки немає історії рейтингу',
                            'No rating history yet',
                          ),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final entry = docs[index].data() as Map<String, dynamic>;
                        final delta = (entry['change'] ?? 0.0).toDouble();
                        final oldRating = (entry['oldRating'] ?? 0.0).toDouble();
                        final newRating = (entry['newRating'] ?? 0.0).toDouble();
                        final reason = (entry['reason'] ?? '').toString();
                        final challengeTitle =
                            (entry['challengeTitle'] ?? '').toString();
                        final voterName = (entry['voterName'] ?? '').toString();
                        final timestamp = entry['timestamp'] as Timestamp?;
                        final deltaSign = delta >= 0 ? '+' : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    delta >= 0 ? Icons.trending_up : Icons.trending_down,
                                    color: delta >= 0
                                        ? const Color(0xFF4caf50)
                                        : Colors.redAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$deltaSign${delta.toStringAsFixed(2)} → '
                                    '${newRating.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatRatingHistoryReason(
                                  reason,
                                  challengeTitle,
                                  voterName,
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${oldRating.toStringAsFixed(2)} → '
                                '${newRating.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              if (timestamp != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
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

  String _formatRatingHistoryReason(
    String reason,
    String challengeTitle,
    String voterName,
  ) {
    switch (reason) {
      case 'challenge_vote':
      case 'video_vote':
      case 'video_rating':
        if (voterName.isNotEmpty && challengeTitle.isNotEmpty) {
          return I18n.inline(
            '$voterName оцінив ваше відео "$challengeTitle"',
            '$voterName rated your video "$challengeTitle"',
          );
        }
        if (voterName.isNotEmpty) {
          return I18n.inline(
            '$voterName оцінив ваше відео',
            '$voterName rated your video',
          );
        }
        if (challengeTitle.isNotEmpty) {
          return I18n.inline(
            'Отримано оцінку за відео "$challengeTitle"',
            'Received a rating for video "$challengeTitle"',
          );
        }
        return I18n.inline(
          'Отримано оцінку за відео',
          'Received a video rating',
        );
      case 'challenge_win':
        return I18n.inline(
          'Перемога в челенджі "$challengeTitle"',
          'Challenge win "$challengeTitle"',
        );
      case 'challenge_second':
        return I18n.inline(
          '2-е місце в челенджі "$challengeTitle"',
          '2nd place in challenge "$challengeTitle"',
        );
      case 'challenge_third':
        return I18n.inline(
          '3-є місце в челенджі "$challengeTitle"',
          '3rd place in challenge "$challengeTitle"',
        );
      case 'manual_recompute':
      case 'manual_recalculation':
      case 'system_recompute':
        return I18n.inline(
          'Перерахунок рейтингу системою',
          'System rating recalculation',
        );
      case 'penalty':
        return I18n.inline(
          'Штраф за порушення правил',
          'Penalty for rule violation',
        );
      case 'bonus':
        return I18n.inline('Бонус за активність', 'Activity bonus');
      default:
        return reason.isNotEmpty
            ? reason
            : I18n.inline('Зміна рейтингу', 'Rating change');
    }
  }
}

class _CachedUserProfile {
  final String name;
  final String avatarUrl;
  final String city;

  const _CachedUserProfile({
    required this.name,
    required this.avatarUrl,
    required this.city,
  });
}

class _CachedChallengeMeta {
  final String challengeId;
  final String title;

  const _CachedChallengeMeta({
    required this.challengeId,
    required this.title,
  });
}

