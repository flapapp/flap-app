import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/media/flap_cached_image.dart';
import 'package:flap_app/features/team_creation/domain/entities/player_position.dart';
import 'package:flap_app/features/team_creation/domain/utils/profile_position_invite_filter.dart';
import 'package:flap_app/features/team_creation/presentation/bloc/team_creation_bloc.dart';
import 'package:flap_app/features/team_creation/presentation/bloc/team_creation_event.dart';
import 'package:flap_app/features/team_creation/presentation/bloc/team_creation_state.dart';
import 'package:flap_app/features/team_creation/presentation/models/pending_club_invite.dart';
import 'package:flap_app/features/teams/domain/repositories/teams_repository.dart';
import 'package:flap_app/utils/i18n.dart';

/// Squad step: search FLAP profiles by name and optional position; queue invites.
class SquadInviteSearchPanel extends StatefulWidget {
  const SquadInviteSearchPanel({
    super.key,
    required this.accent,
    required this.currentUserId,
  });

  final Color accent;
  final String currentUserId;

  @override
  State<SquadInviteSearchPanel> createState() => _SquadInviteSearchPanelState();
}

class _SquadInviteSearchPanelState extends State<SquadInviteSearchPanel> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  PlayerPosition? _positionFilter;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), _runSearch);
  }

  Future<void> _runSearch() async {
    if (!mounted) return;
    final q = _searchCtrl.text;
    final positions = profileDbValuesForInviteFilter(_positionFilter);
    if (q.trim().isEmpty && (positions == null || positions.isEmpty)) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = context.read<TeamsRepository>();
      final rows = await repo.searchPlayers(
        q,
        limit: 24,
        profilePositionsAnyOf: positions,
      );
      if (!mounted) return;
      final filtered = rows
          .where((r) => (r['id'] ?? '').toString() != widget.currentUserId)
          .take(20)
          .toList();
      setState(() {
        _results = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  void _onFilterChanged(PlayerPosition? next) {
    setState(() => _positionFilter = next);
    _scheduleSearch();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamCreationBloc, TeamCreationState>(
      buildWhen: (a, b) => a.pendingInvites != b.pendingInvites,
      builder: (context, state) {
        final pendingIds = {
          for (final p in state.pendingInvites) p.userId,
        };
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.outgoing_mail, color: widget.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      I18n.inline(
                        'Запросити гравців у клуб',
                        'Invite players to the club',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                I18n.inline(
                  'Запрошення надішлються після створення клубу.',
                  'Invites are sent after you create the club.',
                ),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Text(
                I18n.inline('Фільтр за амплуа', 'Filter by position'),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: I18n.inline('Усі', 'All'),
                      selected: _positionFilter == null,
                      accent: widget.accent,
                      onTap: () => _onFilterChanged(null),
                    ),
                    const SizedBox(width: 8),
                    for (final p in PlayerPosition.values) ...[
                      _FilterChip(
                        label: p.label,
                        selected: _positionFilter == p,
                        accent: widget.accent,
                        onTap: () => _onFilterChanged(p),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => _scheduleSearch(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: I18n.inline(
                    'Пошук за іменем або email',
                    'Search by name or email',
                  ),
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: widget.accent),
                  ),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (state.pendingInvites.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  I18n.inline('Обрані запрошення', 'Selected invites'),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: state.pendingInvites
                      .map(
                        (e) => InputChip(
                          label: Text(
                            e.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          deleteIconColor: Colors.white70,
                          backgroundColor:
                              widget.accent.withValues(alpha: 0.25),
                          onDeleted: () => context.read<TeamCreationBloc>().add(
                                TeamCreationPendingInviteRemoved(e.userId),
                              ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final row = _results[i];
                      final id = row['id'] as String;
                      final name = row['displayName'] as String? ?? '';
                      final avatar = row['avatarUrl'] as String? ?? '';
                      final pos = row['profilePosition'] as String? ?? '';
                      final invited = pendingIds.contains(id);
                      return Container(
                        width: 200,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: invited
                                ? widget.accent.withValues(alpha: 0.6)
                                : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white12,
                              child: ClipOval(
                                child: avatar.isNotEmpty
                                    ? FlapCachedImage(
                                        imageUrl: avatar,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(Icons.person,
                                        color: widget.accent, size: 26),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (pos.isNotEmpty)
                                    Text(
                                      pos,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: I18n.inline('Запросити', 'Invite'),
                              onPressed: invited
                                  ? null
                                  : () {
                                      context.read<TeamCreationBloc>().add(
                                            TeamCreationPendingInviteAdded(
                                              PendingClubInvite(
                                                userId: id,
                                                displayName: name,
                                              ),
                                            ),
                                          );
                                    },
                              icon: Icon(
                                invited ? Icons.check_circle : Icons.send_outlined,
                                color: invited ? widget.accent : Colors.white70,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected ? accent.withValues(alpha: 0.35) : Colors.white10,
            border: Border.all(
              color: selected ? accent : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
