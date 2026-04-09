import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/models/friend_request.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/features/friends/domain/repositories/friends_repository.dart';
import 'package:flap_app/features/friends/presentation/bloc/friends_bloc.dart';
import 'package:flap_app/features/friends/presentation/bloc/friends_event.dart';
import 'package:flap_app/features/friends/presentation/bloc/friends_state.dart';

@RoutePage()
class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FriendsBloc(context.read<FriendsRepository>())..add(const FriendsStarted()),
      child: BlocConsumer<FriendsBloc, FriendsState>(
        listenWhen: (prev, curr) {
          if (curr is! FriendsReady) return false;
          if (prev is! FriendsReady) return true;
          return prev.errorMessage != curr.errorMessage ||
              prev.successMessage != curr.successMessage;
        },
        listener: (context, state) {
          if (state is! FriendsReady) return;
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
            context.read<FriendsBloc>().add(const FriendsClearMessages());
            return;
          }
          if (state.successMessage != null) {
            final msg = state.successMessage!;
            if (msg == 'invitation_sent') {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Запрошення надіслано!'.i18n('✅ Invitation sent!')),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (msg == 'invitation_accepted') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Запрошення прийнято!'.i18n('✅ Invitation accepted!')),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (msg == 'invitation_declined') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Запрошення відхилено'.i18n('❌ Invitation declined')),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (msg == 'invitation_cancelled') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Запрошення скасовано'.i18n('✅ Invitation cancelled')),
                  backgroundColor: Colors.orange,
                ),
              );
            } else if (msg.startsWith('removed:')) {
              final name = msg.substring('removed:'.length);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    I18n.inline('$name видалено з друзів', '$name removed from friends'),
                  ),
                ),
              );
            }
            context.read<FriendsBloc>().add(const FriendsClearMessages());
          }
        },
        builder: (context, state) {
          if (state is FriendsInitial) {
            return const Scaffold(
              backgroundColor: Color(0xFF0f0f23),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF4caf50)),
              ),
            );
          }
          if (state is! FriendsReady) {
            return const Scaffold(
              backgroundColor: Color(0xFF0f0f23),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF4caf50)),
              ),
            );
          }
          final ready = state;
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
                  onPressed: () => _showAddFriendDialog(context),
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
                      '${I18n.t('friends')} (${ready.friends.length})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tab(
                    icon: const Icon(Icons.person_add, size: 20),
                    child: Text(
                      I18n.inline(
                        'Запрошення (${ready.incoming.length})',
                        'Invites (${ready.incoming.length})',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tab(
                    icon: const Icon(Icons.send, size: 20),
                    child: Text(
                      I18n.inline(
                        'Надіслані (${ready.outgoing.length})',
                        'Sent (${ready.outgoing.length})',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(context, ready),
                _buildIncomingRequestsTab(context, ready),
                _buildOutgoingRequestsTab(context, ready),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, FriendsReady ready) {
    if (ready.loadingFriends) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4caf50)),
      );
    }

    if (ready.friends.isEmpty) {
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
              onPressed: () => _showAddFriendDialog(context),
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
      itemCount: ready.friends.length,
      itemBuilder: (context, index) {
        final friend = ready.friends[index];
        return _buildFriendCard(context, friend);
      },
    );
  }

  Widget _buildFriendCard(BuildContext context, Friend friend) {
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
            onTap: () => _viewFriendProfile(context, friend),
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
                  _viewFriendProfile(context, friend);
                  break;
                case 'invite':
                  _inviteToMatch(context, friend);
                  break;
                case 'remove':
                  _confirmRemoveFriend(context, friend);
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

  Widget _buildIncomingRequestsTab(BuildContext context, FriendsReady ready) {
    if (ready.incoming.isEmpty) {
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
      itemCount: ready.incoming.length,
      itemBuilder: (context, index) {
        final request = ready.incoming[index];
        return _buildRequestCard(context, request, isIncoming: true);
      },
    );
  }

  Widget _buildOutgoingRequestsTab(BuildContext context, FriendsReady ready) {
    if (ready.outgoing.isEmpty) {
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
      itemCount: ready.outgoing.length,
      itemBuilder: (context, index) {
        final request = ready.outgoing[index];
        return _buildRequestCard(context, request, isIncoming: false);
      },
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    FriendRequest request, {
    required bool isIncoming,
  }) {
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
                    onPressed: () => _respondToRequest(context, request.id, false),
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
                    onPressed: () => _respondToRequest(context, request.id, true),
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
                    onPressed: () => _cancelRequest(context, request.id),
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

  void _showAddFriendDialog(BuildContext screenContext) {
    _searchController.clear();
    screenContext.read<FriendsBloc>().add(const FriendsSearchRequested(''));

    showDialog<void>(
      context: screenContext,
      builder: (dialogContext) => BlocProvider.value(
        value: screenContext.read<FriendsBloc>(),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(
            I18n.t('add_friend'),
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.9,
            height: MediaQuery.of(dialogContext).size.height * 0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  onChanged: (value) {
                    screenContext.read<FriendsBloc>().add(FriendsSearchRequested(value));
                  },
                  onSubmitted: (value) {
                    screenContext.read<FriendsBloc>().add(FriendsSearchRequested(value));
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BlocBuilder<FriendsBloc, FriendsState>(
                    builder: (context, state) {
                      if (state is! FriendsReady) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                        );
                      }
                      if (state.searchLoading) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                        );
                      }
                      if (state.searchResults.isNotEmpty) {
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: state.searchResults.length,
                          itemBuilder: (context, index) {
                            final user = state.searchResults[index];
                            final avatarUrl = user['avatarUrl'] ?? user['avatar'] ?? '';
                            final userName = user['displayName'] ??
                                user['name'] ??
                                user['email']?.split('@')[0] ??
                                'U';
                            return ListTile(
                              leading: GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    dialogContext,
                                    '/player-profile',
                                    arguments: {
                                      'playerId': user['id'],
                                      'playerName': userName,
                                    },
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4caf50),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: avatarUrl.toString().isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Image.network(
                                            avatarUrl.toString(),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildAvatarPlaceholder(userName.toString()),
                                          ),
                                        )
                                      : _buildAvatarPlaceholder(userName.toString()),
                                ),
                              ),
                              title: GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    dialogContext,
                                    '/player-profile',
                                    arguments: {
                                      'playerId': user['id'],
                                      'playerName': userName,
                                    },
                                  );
                                },
                                child: Text(
                                  user['name']?.toString() ?? 'Невідомий'.i18n('Unknown'),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              subtitle: Text(
                                I18n.inline(
                                  '📍 ${user['city'] ?? 'Невідоме місто'}',
                                  '📍 ${user['city'] ?? 'Unknown city'}',
                                ),
                                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_add, color: Color(0xFF4caf50)),
                                onPressed: () => _sendFriendRequest(screenContext, user['id'].toString()),
                              ),
                            );
                          },
                        );
                      }
                      if (_searchController.text.trim().length >= 2) {
                        return Text(
                          I18n.t('no_users_found'),
                          style: const TextStyle(color: Colors.white70),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  void _sendFriendRequest(BuildContext screenContext, String userId) {
    screenContext.read<FriendsBloc>().add(FriendsSendFriendRequest(userId));
  }

  void _respondToRequest(BuildContext context, String requestId, bool accept) {
    context.read<FriendsBloc>().add(FriendsRespondToRequest(requestId, accept));
  }

  void _cancelRequest(BuildContext context, String requestId) {
    context.read<FriendsBloc>().add(FriendsCancelRequest(requestId));
  }

  void _viewFriendProfile(BuildContext context, Friend friend) {
    Navigator.pushNamed(
      context,
      '/player-profile',
      arguments: {'playerId': friend.userId, 'playerName': friend.name},
    );
  }

  void _inviteToMatch(BuildContext context, Friend friend) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          I18n.inline(
            'Запрошення на матч для ${friend.name} (буде реалізовано)',
            'Match invite for ${friend.name} (coming soon)',
          ),
        ),
      ),
    );
  }

  void _confirmRemoveFriend(BuildContext context, Friend friend) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          'Видалити з друзів?'.i18n('Remove from friends?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          I18n.inline(
            'Ви впевнені, що хочете видалити ${friend.name} з друзів?',
            'Are you sure you want to remove ${friend.name} from friends?',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _removeFriend(context, friend);
            },
            child: Text(I18n.t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _removeFriend(BuildContext context, Friend friend) {
    context.read<FriendsBloc>().add(
          FriendsRemoveFriend(friendUserId: friend.userId, friendName: friend.name),
        );
  }
}
