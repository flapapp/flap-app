import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import '../../../subscriptions/presentation/premium_gate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/city_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
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

class _FriendsScreenState extends State<FriendsScreen>
    with TickerProviderStateMixin {
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
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
      backgroundColor: FlapColors.bg,
      appBar: AppBar(
        backgroundColor: FlapColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 66,
        leadingWidth: 60,
        titleSpacing: 0,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _glassIconButton(
                Icons.chevron_left, () => Navigator.pop(context)),
          ),
        ),
        title: Text(
          tr('friends'),
          style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _glassIconButton(
                Icons.person_add_alt_1_rounded, _showAddFriendDialog,
                size: 18),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: _buildSegTabs(pageState),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsTab(pageState),
                  _buildIncomingRequestsTab(pageState),
                  _buildOutgoingRequestsTab(pageState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton(IconData icon, VoidCallback onTap,
      {double size = 19}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: FlapColors.border),
        ),
        child: Icon(icon, color: FlapColors.text, size: size),
      ),
    );
  }

  // ── Segmented tabs ──────────────────────────────────────────────────────

  Widget _buildSegTabs(FriendsPageState pageState) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        children: [
          _segButton('${tr('friends')} (${pageState.friends.length})', 0),
          _segButton(
              tr('il_65f5f7f821', args: ['${pageState.incomingRequests.length}']),
              1),
          _segButton(
              tr('il_c50f88c7a6', args: ['${pageState.outgoingRequests.length}']),
              2),
        ],
      ),
    );
  }

  Widget _segButton(String label, int index) {
    final active = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? FlapColors.green.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? FlapColors.green.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? FlapColors.greenBright : FlapColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  // ── Friends tab ─────────────────────────────────────────────────────────

  Widget _buildFriendsTab(FriendsPageState pageState) {
    if (pageState.friendsLoading) {
      return const FlapLoadingList(
        itemCount: 7,
        itemHeight: 84,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
        gap: 12,
        radius: 18,
      );
    }

    if (pageState.friends.isEmpty) {
      return _emptyState(
        icon: Icons.group_outlined,
        title: tr('friends_empty_title'),
        subtitle: tr('friends_empty_subtitle'),
        action: _emptyAction(
            Icons.person_add_alt_1_rounded, tr('add_friend'),
            _showAddFriendDialog),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: pageState.friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _buildFriendCard(pageState.friends[index]),
    );
  }

  Widget _buildFriendCard(Friend friend) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _viewFriendProfile(friend),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlapColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlapColors.border),
          ),
          child: Row(
            children: [
              _avatar(friend.avatar, friend.name,
                  size: 52, online: friend.isOnline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          FlapText.sora(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: FlapColors.gold, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          friend.ratingDisplay,
                          style: FlapText.sora(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: FlapColors.gold),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            friend.positionDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FlapText.sora(
                                fontSize: 12.5, color: FlapColors.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            color: FlapColors.muted2, size: 12),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            localizeCity(friend.city),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FlapText.sora(
                                fontSize: 11.5, color: FlapColors.muted2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Color(friend.onlineStatusColor),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          friend.onlineStatus,
                          style: FlapText.sora(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(friend.onlineStatusColor)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _friendMenu(friend),
            ],
          ),
        ),
      ),
    );
  }

  Widget _friendMenu(Friend friend) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: FlapColors.muted),
      color: FlapColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: FlapColors.borderStrong),
      ),
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
        _menuItem('profile', Icons.person_outline, tr('profile')),
        _menuItem('invite', Icons.sports_soccer_rounded, tr('invite_to_match')),
        _menuItem('remove', Icons.person_remove_alt_1_outlined,
            tr('remove_friend'),
            danger: true),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label,
      {bool danger = false}) {
    final color = danger ? FlapColors.red : FlapColors.text;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: danger ? FlapColors.red : FlapColors.muted, size: 19),
          const SizedBox(width: 10),
          Text(label, style: FlapText.sora(fontSize: 13.5, color: color)),
        ],
      ),
    );
  }

  // ── Request tabs ────────────────────────────────────────────────────────

  Widget _buildIncomingRequestsTab(FriendsPageState pageState) {
    if (pageState.incomingRequests.isEmpty) {
      return _emptyState(
        icon: Icons.inbox_outlined,
        title: tr('friends_incoming_empty_title'),
        subtitle: tr('friends_incoming_empty_hint'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: pageState.incomingRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _buildRequestCard(pageState.incomingRequests[index], isIncoming: true),
    );
  }

  Widget _buildOutgoingRequestsTab(FriendsPageState pageState) {
    if (pageState.outgoingRequests.isEmpty) {
      return _emptyState(
        icon: Icons.send_outlined,
        title: tr('friends_outgoing_empty_title'),
        subtitle: tr('friends_outgoing_empty_hint'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: pageState.outgoingRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildRequestCard(
          pageState.outgoingRequests[index],
          isIncoming: false),
    );
  }

  Widget _buildRequestCard(FriendRequest request, {required bool isIncoming}) {
    final name = isIncoming ? request.fromUserName : request.toUserName;
    final avatar = isIncoming ? request.fromUserAvatar : request.toUserAvatar;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _avatar(avatar, name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          FlapText.sora(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isIncoming
                          ? tr('friends_subtitle_wants_to_add')
                          : tr('player_invitation_pending_label'),
                      style: FlapText.sora(
                          fontSize: 12.5, color: FlapColors.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.timeAgo,
                      style: FlapText.sora(
                          fontSize: 11.5, color: FlapColors.muted2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlapColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FlapColors.border),
              ),
              child: Text(
                '"${request.message}"',
                style: FlapText.sora(
                        fontSize: 13, color: const Color(0xFFC2CAC4))
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isIncoming)
            Row(
              children: [
                Expanded(
                  child: _outlinedButton(
                    label: tr('reject'),
                    color: FlapColors.red,
                    onTap: () => _respondToRequest(request.id, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _gradientButton(
                    label: tr('accept'),
                    onTap: () => _respondToRequest(request.id, true),
                  ),
                ),
              ],
            )
          else
            _outlinedButton(
              label: tr('cancel'),
              color: FlapColors.muted,
              onTap: () => _cancelRequest(request.id),
            ),
        ],
      ),
    );
  }

  // ── Shared pieces ───────────────────────────────────────────────────────

  Widget _avatar(String url, String name,
      {required double size, bool online = false}) {
    final inner = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FlapColors.card2,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: FlapColors.green.withValues(alpha: 0.4)),
      ),
      child: url.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAvatarPlaceholder(name),
              ),
            )
          : _buildAvatarPlaceholder(name),
    );
    if (!online) return inner;
    return Stack(
      children: [
        inner,
        Positioned(
          bottom: 1,
          right: 1,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: FlapColors.greenBright,
              shape: BoxShape.circle,
              border: Border.all(color: FlapColors.bg, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: FlapText.cond(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: FlapColors.greenBright),
      ),
    );
  }

  Widget _gradientButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: FlapColors.primaryButton,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: FlapText.sora(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FlapColors.onGreen),
        ),
      ),
    );
  }

  Widget _outlinedButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: FlapText.sora(
              fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FlapColors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(30),
                border:
                    Border.all(color: FlapColors.green.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 44, color: FlapColors.greenBright),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: FlapText.sora(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
            ),
            if (action != null) ...[
              const SizedBox(height: 22),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          gradient: FlapColors.primaryButton,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FlapColors.onGreen, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: FlapText.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FlapColors.onGreen),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add friend dialog ───────────────────────────────────────────────────

  void _showAddFriendDialog() {
    // Seed test users if none exist
    _ensureTestUsers();

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: _friendsPageCubit,
        child: StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: FlapColors.card,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: FlapColors.borderStrong),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                minHeight: 220,
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        tr('add_friend'),
                        style: FlapText.sora(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: FlapColors.surface2,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: FlapColors.border),
                          ),
                          child: const Icon(Icons.close,
                              color: FlapColors.muted, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    style: FlapText.sora(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: tr('il_35b68c1380'),
                      hintStyle:
                          FlapText.sora(fontSize: 14, color: FlapColors.muted),
                      prefixIcon: const Icon(Icons.search,
                          color: FlapColors.muted, size: 20),
                      filled: true,
                      fillColor: FlapColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: FlapColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: FlapColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: FlapColors.green),
                      ),
                    ),
                    onChanged: (value) async {
                      if (value.length >= 2) {
                        setState(() {
                          _isSearching = true;
                        });
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
                        setState(() {
                          _isSearching = true;
                        });
                        final results = await _friendsRepo.searchUsers(value);
                        setState(() {
                          _searchResults = results;
                          _isSearching = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child:
                          CircularProgressIndicator(color: FlapColors.green),
                    )
                  else if (_searchResults.isNotEmpty)
                    Expanded(
                      child: BlocBuilder<FriendsPageCubit, FriendsPageState>(
                        buildWhen: (previous, current) => previous != current,
                        builder: (context, pageState) {
                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              final userId = user['id'].toString();
                              final avatarUrl = (user['avatarUrl'] ??
                                      user['avatar_url'] ??
                                      user['avatar'] ??
                                      '')
                                  .toString();
                              final userName = (user['display_name'] ??
                                      user['displayName'] ??
                                      user['name'] ??
                                      user['email']
                                          ?.toString()
                                          .split('@')
                                          .first ??
                                      'U')
                                  .toString();
                              final canAdd = pageState.canSendFriendRequestTo(
                                userId,
                                AppAuth.currentUser?.id,
                              );
                              final cityRaw =
                                  (user['city'] ?? '').toString().trim();
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: FlapColors.surface,
                                  borderRadius: BorderRadius.circular(13),
                                  border:
                                      Border.all(color: FlapColors.border),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => context.router.push(
                                        PlayerProfileRoute(
                                          playerId: userId,
                                          playerName: userName,
                                        ),
                                      ),
                                      child:
                                          _avatar(avatarUrl, userName, size: 40),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => context.router.push(
                                          PlayerProfileRoute(
                                            playerId: userId,
                                            playerName: userName,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: FlapText.sora(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              tr('friends_city_pin',
                                                  namedArgs: {
                                                    'city': cityRaw.isEmpty
                                                        ? tr('unknown_city')
                                                        : cityRaw,
                                                  }),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: FlapText.sora(
                                                  fontSize: 11.5,
                                                  color: FlapColors.muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: canAdd
                                          ? () => _sendFriendRequest(userId)
                                          : null,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: canAdd
                                              ? FlapColors.green
                                                  .withValues(alpha: 0.16)
                                              : FlapColors.surface2,
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          border: Border.all(
                                            color: canAdd
                                                ? FlapColors.green
                                                    .withValues(alpha: 0.4)
                                                : FlapColors.border,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: canAdd
                                              ? FlapColors.greenBright
                                              : FlapColors.muted2,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    )
                  else if (!_isSearching &&
                      _searchController.text.length >= 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(tr('no_users_found'),
                          style: FlapText.sora(
                              fontSize: 13.5, color: FlapColors.muted)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendFriendRequest(String userId) async {
    if (!await PremiumGate.ensure(context)) return;
    try {
      await _friendsRepo.sendFriendRequest(userId);
      await _friendsPageCubit.refreshAll();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('player_invitation_sent_snackbar')),
          backgroundColor: FlapColors.green,
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
          backgroundColor: accept ? FlapColors.green : FlapColors.red,
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
          backgroundColor: FlapColors.amber,
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
        backgroundColor: FlapColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FlapColors.borderStrong),
        ),
        title: Text(
          tr('friends_remove_dialog_title'),
          style: FlapText.sora(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          tr('il_2bf3c2cda3', args: [friend.name]),
          style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel'),
                style: FlapText.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FlapColors.muted)),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              _removeFriend(friend);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: FlapColors.red.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: FlapColors.red.withValues(alpha: 0.5)),
              ),
              child: Text(tr('delete'),
                  style: FlapText.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FlapColors.red)),
            ),
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
