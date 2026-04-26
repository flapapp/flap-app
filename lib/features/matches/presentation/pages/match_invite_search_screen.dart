import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../notifications/data/models/notification.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../../widgets/player_avatar_button.dart';

class MatchInviteSearchScreen extends StatefulWidget {
  const MatchInviteSearchScreen({
    super.key,
    this.matchId,
    this.matchTitle,
    this.organizerName,
    this.excludedUserIds = const <String>[],
    this.initialSelectedUserIds = const <String>[],
    this.selectionOnly = false,
  });

  final String? matchId;
  final String? matchTitle;
  final String? organizerName;
  final List<String> excludedUserIds;
  final List<String> initialSelectedUserIds;
  final bool selectionOnly;

  @override
  State<MatchInviteSearchScreen> createState() => _MatchInviteSearchScreenState();
}

class _MatchInviteSearchScreenState extends State<MatchInviteSearchScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  final Set<String> _excluded = <String>{};
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];
  bool _searching = false;
  bool _submitting = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _excluded.addAll(widget.excludedUserIds);
    _selectedIds.addAll(widget.initialSelectedUserIds);
    final me = AppAuth.currentUserId;
    if (me != null) _excluded.add(me);
  }

  Future<void> _searchUsers() async {
    final q = _searchController.text.trim();
    print('🔍 Searching for: "$q"');
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() => _results = <Map<String, dynamic>>[]);
      return;
    }

    setState(() => _searching = true);
    try {
      final escaped = q
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      final pattern = '%$escaped%';

      final byName = await _sb
          .from('profiles')
          .select('id,display_name,email,avatar_url,city,position')
          .ilike('display_name', pattern)
          .limit(30);
      final byEmail = await _sb
          .from('profiles')
          .select('id,display_name,email,avatar_url,city,position')
          .ilike('email', pattern)
          .limit(30);
      final merged = <dynamic>[...byName as List<dynamic>, ...byEmail as List<dynamic>];
      final dedup = <String, Map<String, dynamic>>{};
      print(merged);
      for (final raw in merged) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = (row['id'] ?? '').toString();
        if (id.isEmpty) continue;
        dedup[id] = row;
      }

      if (!mounted) return;
      final mapped = dedup.values
          .where((row) => (row['id']?.toString().isNotEmpty ?? false))
          .where((row) => !_excluded.contains(row['id'].toString()))
          .toList(growable: false);
      print(mapped);
      setState(() => _results = mapped);
    } catch (e) {
      if (!mounted) return;
      print('❌ Error: ${e.toString()}');
      setState(() => _results = <Map<String, dynamic>>[]);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendInvites() async {
    if (_selectedIds.isEmpty || _submitting) return;
    final inviterId = AppAuth.currentUserId;
    if (inviterId == null ||
        widget.matchId == null ||
        widget.matchTitle == null ||
        widget.organizerName == null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      for (final uid in _selectedIds) {
        await _sb.from('match_invites').upsert(
          {
            'match_id': widget.matchId,
            'user_id': uid,
            'invited_by': inviterId,
            'status': 'pending',
          },
          onConflict: 'match_id,user_id',
        );
        await _notificationService.sendNotification(
          AppNotification(
            id: '',
            userId: uid,
            type: NotificationType.matchInvite,
            title: tr('il_bfaa223845'),
            message: bilingual(
              '${widget.organizerName} запросив вас на матч "${widget.matchTitle}"',
              '${widget.organizerName} invited you to the match "${widget.matchTitle}"',
            ),
            data: {
              'matchId': widget.matchId,
              'matchTitle': widget.matchTitle,
              'action': 'open_match',
            },
            createdAt: DateTime.now(),
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bilingual(
              'Запрошення надіслані',
              'Invitations sent',
            ),
          ),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _finishSelection() async {
    if (_selectedIds.isEmpty) {
      Navigator.pop(context, <Map<String, dynamic>>[]);
      return;
    }
    try {
      final rows = await _sb
          .from('profiles')
          .select('id,display_name,email,avatar_url,city')
          .inFilter('id', _selectedIds.toList());
      final users = (rows as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      if (!mounted) return;
      Navigator.pop(context, users);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context, <Map<String, dynamic>>[]);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: Text(tr('il_146ee72e30')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: tr('il_c81e115cc3'),
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: tr('il_b512d97e7c'),
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4caf50)),
                ),
                suffixIcon: IconButton(
                  onPressed: _searchUsers,
                  icon: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, color: Colors.white70),
                ),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  _searchUsers,
                );
              },
              onSubmitted: (_) => _searchUsers(),
            ),
          ),
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  bilingual(
                    'Обрано для запрошення: ${_selectedIds.length}',
                    'Selected to invite: ${_selectedIds.length}',
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      tr('il_9598782e39'),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.white.withValues(alpha: 0.08)),
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final id = user['id'].toString();
                      final name = (user['display_name'] ??
                              user['email']?.toString().split('@').first ??
                              tr('player'))
                          .toString();
                      final avatarUrl = (user['avatar_url'] ?? '').toString();
                      final city = (user['city'] ?? '').toString();
                      final selected = _selectedIds.contains(id);
                      return ListTile(
                        leading: PlayerAvatarButton(
                          userId: id,
                          displayName: name,
                          avatarUrl: avatarUrl,
                          size: 36,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: city.isEmpty
                            ? null
                            : Text(
                                city,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                        trailing: Checkbox(
                          value: selected,
                          activeColor: const Color(0xFF4caf50),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedIds.isEmpty || _submitting
                      ? null
                      : (widget.selectionOnly ? _finishSelection : _sendInvites),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.selectionOnly ? Icons.check : Icons.send),
                  label: Text(widget.selectionOnly ? tr('confirm') : tr('il_1fd9ae1607')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
