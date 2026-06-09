import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/injection.dart';
import '../widgets/flap/flap_kit.dart';
import '../features/video/presentation/video_feed_sync.dart';
import '../router/app_router.dart';
import '../features/notifications/data/services/notification_service.dart';
import '../features/video/presentation/pages/videos_screen.dart';
import '../features/challenges/presentation/pages/challenges_screen.dart';
import 'cubit/main_header_cubit.dart';
import 'package:flap_app/core/auth/app_auth.dart';

class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool showOnlyMyVideos;
  final bool showOnlyMyChallenges;

  const MainScreen({
    super.key,
    this.initialTabIndex = 0,
    this.showOnlyMyVideos = false,
    this.showOnlyMyChallenges = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late final NotificationService _notificationService;
  final SupabaseClient _sb = Supabase.instance.client;
  late final MainHeaderCubit _mainHeaderCubit;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _notificationService = sl<NotificationService>();
    _mainHeaderCubit = MainHeaderCubit(
      supabase: _sb,
      notificationService: _notificationService,
      userId: AppAuth.currentUserId ?? '',
    )..initialize();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = widget.initialTabIndex;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mainHeaderCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23).withOpacity(0.95),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.video_library,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Flap',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    tr('welcome_brand_line'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<MainHeaderCubit, MainHeaderState>(
            bloc: _mainHeaderCubit,
            builder: (context, state) {
              final userData = state.profileData;
              final unreadCount = state.unreadCount;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildUserChips(userData),
                  _buildProfileButton(userData),
                  Stack(
                    children: [
                      IconButton(
                        tooltip: tr('notifications'),
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            context.router.push(const NotificationsRoute()),
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
                  ),
                ],
              );
            },
          ),
          // Quick Matches button
          IconButton(
            tooltip: tr('il_98abff28a9'),
            icon: const Icon(Icons.sports_soccer, color: Colors.white),
            onPressed: () => context.router.push(MatchesRoute()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF4caf50),
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam, size: 20),
                      const SizedBox(width: 8),
                      Text(tr('videos')),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events, size: 20),
                      const SizedBox(width: 8),
                      Text(tr('challenges')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          VideosScreen(showOnlyMyVideos: widget.showOnlyMyVideos),
          ChallengesScreen(showOnlyMyChallenges: widget.showOnlyMyChallenges),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOptions,
        backgroundColor: const Color(0xFF4caf50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildUserChips(Map<String, dynamic>? userData) {
    if (userData == null) {
      return const SizedBox.shrink();
    }

    final coins = ((userData['coins'] as num?) ?? 0).toInt();
    final rating = ((userData['rating'] as num?) ?? 0.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _showCoinsHistory(coins),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFffc107).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFffc107), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFffc107),
                    size: 16,
                  ),
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
          GestureDetector(
            onTap: () => _showRatingHistory(rating),
            child: Container(
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
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(Map<String, dynamic>? userData) {
    if (userData == null) {
      return IconButton(
        icon: const Icon(Icons.person, color: Colors.white),
        onPressed: () => _showProfile(context),
      );
    }
    final avatarUrl = (userData['avatar_url'] ?? '').toString();
    final userName =
        (userData['display_name'] ??
                userData['email']?.toString().split('@')[0] ??
                tr('il_b512d97e7c'))
            .toString();
    return IconButton(
      onPressed: () => _showProfile(context),
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF4caf50),
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(
                userName.isNotEmpty
                    ? userName[0].toUpperCase()
                    : tr('il_a25513c7e0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }

  void _showCoinsHistory(int currentCoins) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Color(0xFFffc107),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('il_8162d9ed63'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            tr(
                              'il_7bd5596886',
                              namedArgs: {'currentCoins': '$currentCoins'},
                            ),
                            style: const TextStyle(
                              color: Color(0xFFffc107),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

              // Purchase coins button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement coin purchase
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('il_3d6df1a7cd')),
                        backgroundColor: const Color(0xFF4caf50),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: Text(tr('il_d14b405111')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFffc107),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),

              // Transaction history
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('il_de7c340f64'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Transactions list
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sb
                      .from('coin_transactions')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', AppAuth.currentUserId ?? ''),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const FlapLoadingList(
                        itemCount: 6,
                        itemHeight: 64,
                        radius: 14,
                      );
                    }

                    final txDocs = List<Map<String, dynamic>>.from(
                      snapshot.data ?? const <Map<String, dynamic>>[],
                    );
                    txDocs.sort((a, b) {
                      final at = _readDate(a['created_at']);
                      final bt = _readDate(b['created_at']);
                      return bt.compareTo(at);
                    });

                    if (txDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('il_f75dda0d2e'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: txDocs.length,
                      itemBuilder: (context, index) {
                        final transaction = txDocs[index];
                        final amount = transaction['amount'] ?? 0;
                        final description = transaction['description'] ?? '';
                        final timestamp = _readDate(transaction['created_at']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: amount > 0
                                      ? const Color(0xFF4caf50).withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  amount > 0 ? Icons.add : Icons.remove,
                                  color: amount > 0
                                      ? const Color(0xFF4caf50)
                                      : Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatTransactionTime(timestamp),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${amount > 0 ? '+' : ''}$amount',
                                style: TextStyle(
                                  color: amount > 0
                                      ? const Color(0xFF4caf50)
                                      : Colors.red,
                                  fontSize: 16,
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

  void _showRatingHistory(double currentRating) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFF4caf50), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('il_4f7e83106d'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            tr(
                              'il_a763f1866c',
                              args: [currentRating.toStringAsFixed(2)],
                            ),
                            style: const TextStyle(
                              color: Color(0xFF4caf50),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

              // Rating info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4caf50).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        tr('il_931a606b53'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('il_140fc50c0d') +
                            tr('il_ec6a74cc23') +
                            tr('il_2231c771ca') +
                            tr('il_2d817bcff6'),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Rating history list
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sb
                      .from('rating_history')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', AppAuth.currentUserId ?? ''),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const FlapLoadingList(
                        itemCount: 6,
                        itemHeight: 64,
                        radius: 14,
                      );
                    }

                    final docs = List<Map<String, dynamic>>.from(
                      snapshot.data ?? const <Map<String, dynamic>>[],
                    );
                    docs.sort((a, b) {
                      final at = _readDate(a['created_at'] ?? a['timestamp']);
                      final bt = _readDate(b['created_at'] ?? b['timestamp']);
                      return bt.compareTo(at);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timeline,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('il_8070bd0b10'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('il_a1be7a8663'),
                              textAlign: TextAlign.center,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final change = docs[index];
                        final ratingChange = (change['change'] ?? 0.0)
                            .toDouble();
                        final newRating =
                            (change['new_rating'] ?? change['newRating'] ?? 0.0)
                                .toDouble();
                        final oldRating =
                            (change['old_rating'] ?? change['oldRating'] ?? 0.0)
                                .toDouble();
                        final reason = change['reason'] ?? '';
                        final timestamp = _readDate(
                          change['created_at'] ?? change['timestamp'],
                        );
                        final challengeTitle =
                            change['challenge_title'] ??
                            change['challengeTitle'] ??
                            '';
                        final voterName =
                            change['voter_name'] ?? change['voterName'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: ratingChange > 0
                                      ? const Color(0xFF4caf50).withOpacity(0.2)
                                      : ratingChange < 0
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  ratingChange > 0
                                      ? Icons.trending_up
                                      : ratingChange < 0
                                      ? Icons.trending_down
                                      : Icons.trending_flat,
                                  color: ratingChange > 0
                                      ? const Color(0xFF4caf50)
                                      : ratingChange < 0
                                      ? Colors.red
                                      : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatRatingReason(
                                        reason,
                                        challengeTitle,
                                        voterName,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${oldRating.toStringAsFixed(2)} → ${newRating.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTransactionTime(timestamp),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${ratingChange > 0 ? '+' : ''}${ratingChange.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: ratingChange > 0
                                      ? const Color(0xFF4caf50)
                                      : ratingChange < 0
                                      ? Colors.red
                                      : Colors.grey,
                                  fontSize: 16,
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

  String _formatTransactionTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat.yMMMd(context.locale.toLanguageTag()).format(dateTime);
    } else if (difference.inDays > 0) {
      return tr('il_adf8ee5f65', args: ['${difference.inDays}']);
    } else if (difference.inHours > 0) {
      return tr('il_7634d1849f', args: ['${difference.inHours}']);
    } else if (difference.inMinutes > 0) {
      return tr('il_e0b53645d6', args: ['${difference.inMinutes}']);
    } else {
      return tr('il_66f53417d3');
    }
  }

  String _formatRatingReason(
    String reason,
    String challengeTitle,
    String voterName,
  ) {
    switch (reason) {
      case 'challenge_vote':
      case 'video_vote':
      case 'video_rating':
        if (voterName.isNotEmpty && challengeTitle.isNotEmpty) {
          return tr(
            'il_a97735a0aa',
            namedArgs: {
              'voterName': voterName,
              'challengeTitle': challengeTitle,
            },
          );
        }
        if (voterName.isNotEmpty) {
          return tr('il_b4ce1ec898', namedArgs: {'voterName': voterName});
        }
        if (challengeTitle.isNotEmpty) {
          return tr(
            'il_73abcbe250',
            namedArgs: {'challengeTitle': challengeTitle},
          );
        }
        return tr('il_e7a04f3648');
      case 'challenge_win':
        return tr(
          'il_f6317c6873',
          namedArgs: {'challengeTitle': challengeTitle},
        );
      case 'challenge_second':
        return tr(
          'il_90e7c87869',
          namedArgs: {'challengeTitle': challengeTitle},
        );
      case 'challenge_third':
        return tr(
          'il_414a7e49e3',
          namedArgs: {'challengeTitle': challengeTitle},
        );
      case 'manual_recompute':
      case 'manual_recalculation':
      case 'system_recompute':
        return tr('il_b6ce244d3a');
      case 'penalty':
        return tr('il_58659f628a');
      case 'bonus':
        return tr('il_c88734b3ea');
      default:
        return reason.isNotEmpty ? reason : tr('il_bcfd1b4865');
    }
  }

  DateTime _readDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      final dynamic v = value;
      final d = v?.toDate();
      if (d is DateTime) {
        return d;
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                tr('hub_create_content'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Create Video
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam, color: Color(0xFF2196F3)),
                ),
                title: Text(
                  tr('create_video'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  tr('il_8dfa00ec39'),
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await context.router.push(VideoUploadRoute());
                  if (!context.mounted) return;
                  sl<VideoFeedSync>().notifyFeedMayHaveChanged();
                },
              ),

              const SizedBox(height: 8),

              // Create Challenge
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Color(0xFF4caf50),
                  ),
                ),
                title: Text(
                  tr('create_challenge'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  tr('invite_others'),
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.router.push(const ChallengeCreateRoute());
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showProfile(BuildContext context) {
    context.router.push(const ProfileRoute());
  }
}
