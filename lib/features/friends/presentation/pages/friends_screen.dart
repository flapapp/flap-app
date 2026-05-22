import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/city_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/friends_repository.dart';
import '../../../../router/app_router.dart';
import '../../data/models/friend_request.dart';
import 'package:flap_app/core/auth/app_auth.dart';

import '../cubit/friends_page_cubit.dart';
import '../cubit/friends_page_state.dart';

@RoutePage()
class FriendsScreen extends StatefulWidget {
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with TickerProviderStateMixin {
  FriendsRepository get _friendsRepo => sl<FriendsRepository>();

  late final FriendsPageCubit _friendsPageCubit;
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _friendsPageCubit = FriendsPageCubit(_friendsRepo);
    _friendsPageCubit.load();
  }

  @override
  void dispose() {
    _friendsPageCubit.close();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _friendsPageCubit,
      child: BlocBuilder<FriendsPageCubit, FriendsPageState>(
        buildWhen: (previous, current) => previous != current,
        builder: (context, pageState) {
          return _buildScaffold(context, pageState);
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, FriendsPageState pageState) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23),
        elevation: 0,
        title: Text(
          '👥 ${tr('friends')}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: _showAddFriendDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4caf50),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.people, size: 20),
              child: Text(
                '${tr('friends')} (${pageState.friends.length})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tab(
              icon: const Icon(Icons.person_add, size: 20),
              child: Text(
                tr('il_65f5f7f821', args: ['${pageState.incomingRequests.length}']),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tab(
              icon: const Icon(Icons.send, size: 20),
              child: Text(
                tr('il_c50f88c7a6', args: ['${pageState.outgoingRequests.length}']),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(pageState),
          _buildIncomingRequestsTab(pageState),
          _buildOutgoingRequestsTab(pageState),
        ],
      ),
    );
  }

  Widget _buildFriendsTab(FriendsPageState pageState) {
    if (pageState.friendsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4caf50)),
      );
    }

    if (pageState.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              tr('friends_empty_title'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('friends_empty_subtitle'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add),
              label: Text(tr('add_friend')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4caf50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pageState.friends.length,
      itemBuilder: (context, index) {
        final friend = pageState.friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  Widget _buildFriendCard(Friend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _viewFriendProfile(friend),
            child: Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF4caf50),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: friend.avatar.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.network(
                          friend.avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildAvatarPlaceholder(friend.name),
                        ),
                      )
                    : _buildAvatarPlaceholder(friend.name),
              ),
              // Online indicator
              if (friend.isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0f0f23), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      friend.ratingStars,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      friend.ratingDisplay,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      friend.positionDisplay,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '📍 ${localizeCity(friend.city)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      friend.onlineStatus,
                      style: TextStyle(
                        color: Color(friend.onlineStatusColor),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1a1a2e),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _viewFriendProfile(friend);
                  break;
                case 'invite':
                  _inviteToMatch(friend);
                  break;
                case 'remove':
                  _confirmRemoveFriend(friend);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(tr('profile'), style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.sports_soccer, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(tr('invite_to_match'), style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(tr('remove_friend'), style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsTab(FriendsPageState pageState) {
    if (pageState.incomingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              tr('friends_incoming_empty_title'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('friends_incoming_empty_hint'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pageState.incomingRequests.length,
      itemBuilder: (context, index) {
        final request = pageState.incomingRequests[index];
        return _buildRequestCard(request, isIncoming: true);
      },
    );
  }

  Widget _buildOutgoingRequestsTab(FriendsPageState pageState) {
    if (pageState.outgoingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.send_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              tr('friends_outgoing_empty_title'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('friends_outgoing_empty_hint'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pageState.outgoingRequests.length,
      itemBuilder: (context, index) {
        final request = pageState.outgoingRequests[index];
        return _buildRequestCard(request, isIncoming: false);
      },
    );
  }

  Widget _buildRequestCard(FriendRequest request, {required bool isIncoming}) {
    final user = isIncoming 
        ? {'name': request.fromUserName, 'avatar': request.fromUserAvatar}
        : {'name': request.toUserName, 'avatar': request.toUserAvatar};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4caf50),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: user['avatar']!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          user['avatar']!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildAvatarPlaceholder(user['name']!),
                        ),
                      )
                    : _buildAvatarPlaceholder(user['name']!),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isIncoming
                          ? tr('friends_subtitle_wants_to_add')
                          : tr('player_invitation_pending_label'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.timeAgo,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${request.message}"',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          
          // Actions
          Row(
            children: [
              if (isIncoming) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respondToRequest(request.id, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(tr('reject')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respondToRequest(request.id, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4caf50),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(tr('accept')),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _cancelRequest(request.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(tr('cancel')),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAddFriendDialog() {
    // Seed test users if none exist
    _ensureTestUsers();
    
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: _friendsPageCubit,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(
            tr('add_friend'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              minHeight: 200,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: tr('il_35b68c1380'),
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4caf50)),
                    ),
                  ),
                  onChanged: (value) async {
                    if (value.length >= 2) {
                      setState(() { _isSearching = true; });
                      final results = await _friendsRepo.searchUsers(value);
                      setState(() {
                        _searchResults = results;
                        _isSearching = false;
                      });
                    } else if (value.isEmpty) {
                      setState(() {
                        _searchResults.clear();
                        _isSearching = false;
                      });
                    } else {
                      setState(() {
                        _isSearching = true;
                        _searchResults.clear();
                      });
                    }
                  },
                  onSubmitted: (value) async {
                    if (value.length >= 2) {
                      setState(() { _isSearching = true; });
                      final results = await _friendsRepo.searchUsers(value);
                      setState(() {
                        _searchResults = results;
                        _isSearching = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  tr(
                    'il_cfa9991764',
                    namedArgs: {
                      'count': '${_searchResults.length}',
                      'searching': '$_isSearching',
                    },
                  ),
                  style: const TextStyle(color: Colors.orange, fontSize: 10),
                ),
                const SizedBox(height: 8),
                if (_isSearching)
                  const CircularProgressIndicator(color: Color(0xFF4caf50))
                else if (_searchResults.isNotEmpty)
                  Expanded(
                    child: BlocBuilder<FriendsPageCubit, FriendsPageState>(
                      buildWhen: (previous, current) => previous != current,
                      builder: (context, pageState) {
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final userId = user['id'].toString();
                            final avatarUrl = user['avatarUrl'] ??
                                user['avatar_url'] ??
                                user['avatar'] ??
                                '';
                            final userName = (user['display_name'] ??
                                    user['displayName'] ??
                                    user['name'] ??
                                    user['email']?.toString().split('@').first ??
                                    'U')
                                .toString();
                            final canAdd = pageState.canSendFriendRequestTo(
                              userId,
                              AppAuth.currentUser?.id,
                            );
                            return ListTile(
                              leading: GestureDetector(
                                onTap: () {
                                  context.router.push(
                                    PlayerProfileRoute(
                                      playerId: userId,
                                      playerName: userName,
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4caf50),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: avatarUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Image.network(
                                            avatarUrl,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildAvatarPlaceholder(userName),
                                          ),
                                        )
                                      : _buildAvatarPlaceholder(userName),
                                ),
                              ),
                              title: GestureDetector(
                                onTap: () {
                                  context.router.push(
                                    PlayerProfileRoute(
                                      playerId: userId,
                                      playerName: userName,
                                    ),
                                  );
                                },
                                child: Text(userName, style: const TextStyle(color: Colors.white)),
                              ),
                              subtitle: Text(
                                tr(
                                  'friends_city_pin',
                                  namedArgs: {
                                    'city': (user['city'] ?? '')
                                            .toString()
                                            .trim()
                                            .isEmpty
                                        ? tr('unknown_city')
                                        : user['city'].toString(),
                                  },
                                ),
                                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.person_add,
                                  color: canAdd ? const Color(0xFF4caf50) : Colors.white38,
                                ),
                                onPressed: canAdd ? () => _sendFriendRequest(userId) : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                else if (!_isSearching && _searchController.text.length >= 2)
                  Text(tr('no_users_found'), style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('cancel'), style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _sendFriendRequest(String userId) async {
    try {
      await _friendsRepo.sendFriendRequest(userId);
      await _friendsPageCubit.refreshAll();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('player_invitation_sent_snackbar')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()}))),
      );
    }
  }

  void _respondToRequest(String requestId, bool accept) async {
    try {
      await _friendsRepo.respondToFriendRequest(requestId, accept);
      await _friendsPageCubit.refreshAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? tr('player_invitation_accepted')
                : tr('player_invitation_declined'),
          ),
          backgroundColor: accept ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()}))),
      );
    }
  }

  void _cancelRequest(String requestId) async {
    try {
      await _friendsRepo.cancelFriendRequest(requestId);
      await _friendsPageCubit.refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('player_invitation_cancelled')),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()}))),
      );
    }
  }

  void _viewFriendProfile(Friend friend) {
    context.router.push(
      PlayerProfileRoute(
        playerId: friend.userId,
        playerName: friend.name,
      ),
    );
  }

  void _inviteToMatch(Friend friend) {
    // Navigate to create match with friend pre-selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('il_4b4bef8539', args: [friend.name]),
        ),
      ),
    );
  }

  void _confirmRemoveFriend(Friend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          tr('friends_remove_dialog_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          tr('il_2bf3c2cda3', args: [friend.name]),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeFriend(friend);
            },
            child: Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _removeFriend(Friend friend) async {
    try {
      await _friendsRepo.removeFriend(friend.userId);
      await _friendsPageCubit.refreshAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_0e0331a717', args: [friend.name]))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()}))),
      );
    }
  }

  Future<void> _ensureTestUsers() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) return;

      // Supabase profiles are tied to auth.users; don't seed fake profile rows here.
      final existingUsers = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .neq('id', currentUser.id)
          .limit(5);
      final otherUsersCount = (existingUsers as List<dynamic>).length;
      if (otherUsersCount < 3) {
        print('[friends] INFO: Not enough users for rich search demo; skipping local test-user seeding.');
      }
    } catch (e) {
      print('[friends] ERROR creating test users: $e');
    }
  }
}
