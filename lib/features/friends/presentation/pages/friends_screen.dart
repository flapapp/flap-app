import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/friends_repository.dart';
import '../../../../router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/friend_request.dart';
import 'dart:async';
import '../../../../utils/i18n.dart';

@RoutePage()
class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with TickerProviderStateMixin {
  FriendsRepository get _friendsRepo => sl<FriendsRepository>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  
  List<Friend> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  bool _loadingFriends = true;
  
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  StreamSubscription<List<FriendRequest>>? _incomingSub;
  StreamSubscription<List<FriendRequest>>? _outgoingSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriends();
    _listenToRequests();
  }

  void _loadFriends() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final friends = await _friendsRepo.getUserFriends(currentUser.uid);
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _loadingFriends = false;
      });
    }
  }

  void _listenToRequests() {
    _incomingSub = _friendsRepo.getIncomingFriendRequests().listen((requests) {
      if (!mounted) return;
      setState(() {
        _incomingRequests = requests;
      });
    });

    _outgoingSub = _friendsRepo.getOutgoingFriendRequests().listen((requests) {
      if (!mounted) return;
      setState(() {
        _outgoingRequests = requests;
      });
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23),
        elevation: 0,
        title: Text(
          '👥 ${I18n.t('friends')}',
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
                '${I18n.t('friends')} (${_friends.length})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tab(
              icon: const Icon(Icons.person_add, size: 20),
              child: Text(
                I18n.inline('Запрошення (${_incomingRequests.length})', 'Invites (${_incomingRequests.length})'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tab(
              icon: const Icon(Icons.send, size: 20),
              child: Text(
                I18n.inline('Надіслані (${_outgoingRequests.length})', 'Sent (${_outgoingRequests.length})'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildIncomingRequestsTab(),
          _buildOutgoingRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_loadingFriends) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4caf50)),
      );
    }

    if (_friends.isEmpty) {
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
              'У вас поки немає друзів'.i18n('You have no friends yet'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Додайте друзів, щоб грати разом!'.i18n('Add friends to play together!'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add),
              label: Text(I18n.t('add_friend')),
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
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
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
                    ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        friend.positionDisplay,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        '📍 ${I18n.localizeCity(friend.city)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        friend.onlineStatus,
                        style: TextStyle(
                          color: Color(friend.onlineStatusColor),
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
                    Text(I18n.t('profile'), style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.sports_soccer, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(I18n.t('invite_to_match'), style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(I18n.t('remove_friend'), style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsTab() {
    if (_incomingRequests.isEmpty) {
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
              'Немає нових запрошень'.i18n('No new requests'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Тут з\'являться запрошення в друзі'.i18n('Friend requests will appear here'),
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
      itemCount: _incomingRequests.length,
      itemBuilder: (context, index) {
        final request = _incomingRequests[index];
        return _buildRequestCard(request, isIncoming: true);
      },
    );
  }

  Widget _buildOutgoingRequestsTab() {
    if (_outgoingRequests.isEmpty) {
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
              'Немає надісланих запрошень'.i18n('No sent requests'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Тут з\'являться ваші запрошення'.i18n('Your invitations will appear here'),
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
      itemCount: _outgoingRequests.length,
      itemBuilder: (context, index) {
        final request = _outgoingRequests[index];
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
                          ? 'Хоче додати вас у друзі'.i18n('Wants to add you as a friend')
                          : 'Запрошення надіслано'.i18n('Invitation sent'),
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
                    child: Text(I18n.t('reject')),
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
                    child: Text(I18n.t('accept')),
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
                    child: Text(I18n.t('cancel')),
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
    // Створюємо тестових користувачів якщо їх немає
    _ensureTestUsers();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(
            I18n.t('add_friend'),
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
                    hintText: I18n.inline('Введіть ім\'я користувача', 'Enter a username'),
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
                  I18n.inline('Debug: ${_searchResults.length} результатів, пошук: $_isSearching',
                      'Debug: ${_searchResults.length} results, searching: $_isSearching'),
                  style: const TextStyle(color: Colors.orange, fontSize: 10),
                ),
                const SizedBox(height: 8),
                if (_isSearching)
                  const CircularProgressIndicator(color: Color(0xFF4caf50))
                else if (_searchResults.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        final avatarUrl = user['avatarUrl'] ?? user['avatar'] ?? '';
                        final userName = user['displayName'] ?? user['name'] ?? user['email']?.split('@')[0] ?? 'U';
                        return ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              context.router.push(
                                PlayerProfileRoute(
                                  playerId: user['id'].toString(),
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
                                        errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(userName),
                                      ),
                                    )
                                  : _buildAvatarPlaceholder(userName),
                            ),
                          ),
                          title: GestureDetector(
                            onTap: () {
                              context.router.push(
                                PlayerProfileRoute(
                                  playerId: user['id'].toString(),
                                  playerName: userName,
                                ),
                              );
                            },
                            child: Text(user['name'] ?? 'Невідомий'.i18n('Unknown'), style: const TextStyle(color: Colors.white)),
                          ),
                          subtitle: Text(
                              I18n.inline('📍 ${user['city'] ?? 'Невідоме місто'}', '📍 ${user['city'] ?? 'Unknown city'}'),
                              style: TextStyle(color: Colors.white.withOpacity(0.7))),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add, color: Color(0xFF4caf50)),
                            onPressed: () => _sendFriendRequest(user['id']),
                          ),
                        );
                      },
                    ),
                  )
                else if (!_isSearching && _searchController.text.length >= 2)
                  Text(I18n.t('no_users_found'), style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      return [];
    }

    try {
      print('🔍 Starting search for: "$query"');
      
      // Спочатку перевіримо чи є користувачі взагалі
      final allUsers = await FirebaseFirestore.instance
          .collection('users')
          .limit(5)
          .get();
      
      print('📊 Total users in database: ${allUsers.docs.length}');
      
      if (allUsers.docs.isEmpty) {
        print('❌ No users found in database!');
        return [];
      }
      
      // Показуємо перших кілька користувачів для діагностики
      for (var doc in allUsers.docs.take(3)) {
        final data = doc.data();
        print('👤 User sample: ${doc.id} -> name: "${data['name']}", displayName: "${data['displayName']}", email: "${data['email']}"');
      }
      
      final results = await _friendsRepo.searchUsers(query.trim());
      print('✅ Search completed. Results: ${results.length}');
      
      if (results.isNotEmpty) {
        print('🎯 First result: ${results.first['name']} / ${results.first['displayName']} / ${results.first['email']}');
      } else {
        print('⚠️ No matching users found for query: "$query"');
      }
      return results;
    } catch (e) {
      print('❌ Search error: $e');
      return [];
    }
  }

  void _sendFriendRequest(String userId) async {
    try {
      await _friendsRepo.sendFriendRequest(userId);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Запрошення надіслано!'.i18n('✅ Invitation sent!')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
      );
    }
  }

  void _respondToRequest(String requestId, bool accept) async {
    try {
      await _friendsRepo.respondToFriendRequest(requestId, accept);
      
      if (accept) {
        _loadFriends(); // Refresh friends list
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? '✅ Запрошення прийнято!'.i18n('✅ Invitation accepted!')
              : '❌ Запрошення відхилено'.i18n('❌ Invitation declined')),
          backgroundColor: accept ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
      );
    }
  }

  void _cancelRequest(String requestId) async {
    try {
      await _friendsRepo.cancelFriendRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Запрошення скасовано'.i18n('✅ Invitation cancelled')),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
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
          I18n.inline('Запрошення на матч для ${friend.name} (буде реалізовано)', 'Match invite for ${friend.name} (coming soon)'),
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
          'Видалити з друзів?'.i18n('Remove from friends?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          I18n.inline('Ви впевнені, що хочете видалити ${friend.name} з друзів?',
              'Are you sure you want to remove ${friend.name} from friends?'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeFriend(friend);
            },
            child: Text(I18n.t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _removeFriend(Friend friend) async {
    try {
      await _friendsRepo.removeFriend(friend.userId);
      _loadFriends(); // Refresh friends list
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('${friend.name} видалено з друзів', '${friend.name} removed from friends'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
      );
    }
  }

  Future<void> _ensureTestUsers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Перевіряємо чи є інші користувачі крім поточного
      final existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .limit(5)
          .get();

      final otherUsers = existingUsers.docs
          .where((doc) => doc.id != currentUser.uid)
          .toList();

      if (otherUsers.length < 3) {
        // Створюємо тестових користувачів
        final batch = FirebaseFirestore.instance.batch();
        
        final testUsers = [
          {
            'name': 'Leo',
            'displayName': 'Leo Messi',
            'firstName': 'Leo',
            'lastName': 'Messi',
            'email': 'leo.messi@example.com',
            'city': 'Kyiv',
            'country': 'Ukraine',
            'position': 'Forward',
            'rating': 4.8,
            'coins': 250,
            'avatarUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'name': 'Vinnie Jr',
            'displayName': 'Vinnie Jr',
            'firstName': 'Vinnie',
            'lastName': 'Jr',
            'email': 'vinnie.jr@example.com',
            'city': 'Lviv',
            'country': 'Ukraine',
            'position': 'Midfielder',
            'rating': 4.2,
            'coins': 180,
            'avatarUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'name': 'Cristiano',
            'displayName': 'Cristiano Ronaldo',
            'firstName': 'Cristiano',
            'lastName': 'Ronaldo',
            'email': 'cristiano@example.com',
            'city': 'Odesa',
            'country': 'Ukraine',
            'position': 'Forward',
            'rating': 4.9,
            'coins': 320,
            'avatarUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'name': 'Neymar',
            'displayName': 'Neymar Jr',
            'firstName': 'Neymar',
            'lastName': 'Jr',
            'email': 'neymar@example.com',
            'city': 'Kharkiv',
            'country': 'Ukraine',
            'position': 'Winger',
            'rating': 4.3,
            'coins': 200,
            'avatarUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
          },
        ];

        for (final userData in testUsers) {
          final docRef = FirebaseFirestore.instance.collection('users').doc();
          batch.set(docRef, userData);
        }

        await batch.commit();
        print('✅ Test users created for friend search');
      }
    } catch (e) {
      print('❌ Error creating test users: $e');
    }
  }
}
