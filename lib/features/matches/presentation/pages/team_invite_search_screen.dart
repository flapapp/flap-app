import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../features/teams/data/models/app_team.dart';
import '../../../../features/teams/domain/repositories/teams_repository.dart';
import '../../../../widgets/team_logo_button.dart';

class TeamInviteSearchScreen extends StatefulWidget {
  const TeamInviteSearchScreen({
    super.key,
    this.initialSelectedTeam,
    this.excludedTeamId,
  });

  final AppTeam? initialSelectedTeam;
  final String? excludedTeamId;

  @override
  State<TeamInviteSearchScreen> createState() => _TeamInviteSearchScreenState();
}

class _TeamInviteSearchScreenState extends State<TeamInviteSearchScreen> {
  final TeamsRepository _teamsRepo = sl<TeamsRepository>();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<AppTeam> _results = <AppTeam>[];
  bool _searching = false;
  AppTeam? _selectedTeam;

  Future<void> _searchTeams() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() => _results = <AppTeam>[]);
      return;
    }

    setState(() => _searching = true);
    try {
      final teams = await _teamsRepo.searchTeams(query, limit: 20);
      if (!mounted) return;
      setState(() {
        _results = teams
            .where((team) => team.id != widget.excludedTeamId)
            .toList(growable: false);
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedTeam = widget.initialSelectedTeam;
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
        title: Text(tr('il_7ec0bce7a1')),
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
                  onPressed: _searchTeams,
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
                  _searchTeams,
                );
              },
              onSubmitted: (_) => _searchTeams(),
            ),
          ),
          if (_selectedTeam != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('il_4d80ab83ac', args: [_selectedTeam!.name]),
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
                      final team = _results[index];
                      final selected = _selectedTeam?.id == team.id;
                      return ListTile(
                        leading: TeamLogoButton(
                          teamId: team.id,
                          teamName: team.name,
                          logoUrl: team.logoUrl,
                          size: 36,
                        ),
                        title: Text(
                          team.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${team.memberIds.length} ${tr('il_afc0d772a2')}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Radio<String>(
                          value: team.id,
                          groupValue: _selectedTeam?.id,
                          activeColor: const Color(0xFF4caf50),
                          onChanged: (_) => setState(() => _selectedTeam = team),
                        ),
                        onTap: () => setState(() => _selectedTeam = team),
                        selected: selected,
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
                  onPressed: _selectedTeam == null
                      ? null
                      : () => Navigator.pop(context, _selectedTeam),
                  icon: const Icon(Icons.check),
                  label: Text(tr('confirm')),
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
