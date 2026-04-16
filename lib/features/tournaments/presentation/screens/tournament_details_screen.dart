import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_auth_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/feedback/app_snackbar.dart';
import '../../../../shared/ui/app_button.dart';
import '../../../../shared/ui/app_card.dart';
import '../../../teams/domain/repositories/teams_repository.dart';
import '../../domain/entities/tournament_detail.dart';
import '../../domain/entities/tournament_match.dart';
import '../../domain/entities/tournament_team_entry.dart';
import '../../domain/repositories/tournaments_repository.dart';

class _TournamentPageData {
  const _TournamentPageData(this.detail, this.matches);

  final TournamentDetail? detail;
  final List<TournamentMatch> matches;
}

class TournamentDetailsScreen extends StatefulWidget {
  const TournamentDetailsScreen({
    super.key,
    required this.tournamentId,
    required this.title,
    required this.createdByUserId,
  });

  final String tournamentId;
  final String title;
  final String createdByUserId;

  @override
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> {
  late Future<_TournamentPageData> _pageFuture;
  Future<List<_EligibleTeam>>? _eligibleTeamsFuture;

  bool get _isCreator =>
      AppAuthContext.userId != null && AppAuthContext.userId == widget.createdByUserId;

  @override
  void initState() {
    super.initState();
    _pageFuture = _loadPage();
  }

  Future<_TournamentPageData> _loadPage() async {
    final repo = context.read<TournamentsRepository>();
    final detail = await repo.getTournament(widget.tournamentId);
    final matches = await repo.listMatches(widget.tournamentId);
    return _TournamentPageData(detail, matches);
  }

  Future<void> _reload() async {
    _eligibleTeamsFuture = null;
    setState(() {
      _pageFuture = _loadPage();
    });
    await _pageFuture;
  }

  String _teamLabel(TournamentMatch m, {required bool home}) {
    final name = home ? m.homeTeamName : m.awayTeamName;
    final id = home ? m.homeTeamId : m.awayTeamId;
    if (name != null && name.isNotEmpty) return name;
    if (id.length > 8) return '${id.substring(0, 8)}…';
    return id;
  }

  Future<void> _openScheduleSheet() async {
    final repo = context.read<TournamentsRepository>();
    List<TournamentTeamEntry> teams;
    try {
      teams = await repo.listTournamentTeams(widget.tournamentId);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, message: e.toString());
      return;
    }
    if (!mounted) return;
    if (teams.length < 2) {
      AppSnackbar.show(
        context,
        message: 'Add at least two approved teams to the tournament before scheduling matches.',
      );
      return;
    }

    String? homeId = teams.first.teamId;
    String? awayId = teams.length > 1 ? teams[1].teamId : null;
    var matchDate = DateTime.now().add(const Duration(days: 1));
    matchDate = DateTime(
      matchDate.year,
      matchDate.month,
      matchDate.day,
      18,
      0,
    );
    final venueController = TextEditingController();
    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.bgBase,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                Widget teamDropdown({
                  required String label,
                  required String? value,
                  required ValueChanged<String?> onChanged,
                }) {
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
                      ),
                    ),
                    dropdownColor: AppColors.bgElevated,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: teams
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t.teamId,
                            child: Text(t.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: onChanged,
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Schedule match',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      teamDropdown(
                        label: 'Home team',
                        value: homeId,
                        onChanged: (v) => setModalState(() => homeId = v),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      teamDropdown(
                        label: 'Away team',
                        value: awayId,
                        onChanged: (v) => setModalState(() => awayId = v),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Date & time',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(matchDate.toLocal()),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(Icons.event, color: AppColors.accentPrimary),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: matchDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (d == null || !context.mounted) return;
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(matchDate),
                          );
                          if (t == null) return;
                          setModalState(() {
                            matchDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                          });
                        },
                      ),
                      TextField(
                        controller: venueController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Venue (optional)',
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Create match',
                        icon: Icons.sports_soccer,
                        onPressed: () {
                          if (homeId == null || awayId == null || homeId == awayId) {
                            AppSnackbar.show(
                              context,
                              message: 'Pick two different teams.',
                            );
                            return;
                          }
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );

      if (ok != true || !mounted) return;
      if (homeId == null || awayId == null || homeId == awayId) return;

      await repo.createTournamentMatch(
        tournamentId: widget.tournamentId,
        homeTeamId: homeId!,
        awayTeamId: awayId!,
        matchDate: matchDate,
        venue: venueController.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, message: 'Match scheduled.');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, message: e.toString());
    } finally {
      venueController.dispose();
    }
  }

  Future<List<_EligibleTeam>> _loadEligibleTeamsForJoin() async {
    final uid = AppAuthContext.userId;
    if (uid == null) return const [];
    final teamsRepo = context.read<TeamsRepository>();
    final tourRepo = context.read<TournamentsRepository>();
    final myTeams = await teamsRepo.fetchUserTeams(uid);
    final alreadyIn = await tourRepo.listTournamentTeams(widget.tournamentId);
    final inIds = alreadyIn.map((e) => e.teamId).toSet();
    final out = <_EligibleTeam>[];
    for (final t in myTeams) {
      final canAdmin = t.captainId == uid || t.viceCaptainIds.contains(uid);
      if (!canAdmin) continue;
      if (inIds.contains(t.id)) continue;
      out.add(_EligibleTeam(t.id, t.name));
    }
    return out;
  }

  Future<void> _submitJoinRequest(String teamId) async {
    try {
      await context.read<TournamentsRepository>().requestToJoinTournament(
            tournamentId: widget.tournamentId,
            teamId: teamId,
          );
      if (!mounted) return;
      AppSnackbar.show(context, message: 'Join request sent. The organizer will review it.');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, message: e.toString());
    }
  }

  Widget _buildInfoCard(TournamentDetail? d) {
    final detail = d;
    if (detail == null) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      );
    }
    final fmt = DateFormat.yMMMd();
    final rulesText = _rulesSummary(detail.rules);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${detail.type} • ${detail.status}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (detail.startDate != null || detail.endDate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                if (detail.startDate != null) 'Starts: ${fmt.format(detail.startDate!.toLocal())}',
                if (detail.endDate != null) 'Ends: ${fmt.format(detail.endDate!.toLocal())}',
              ].join('  ·  '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          if (detail.maxTeams != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Max teams: ${detail.maxTeams}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          if (rulesText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              rulesText,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  String _rulesSummary(Map<String, dynamic>? rules) {
    if (rules == null || rules.isEmpty) return '';
    final buf = StringBuffer();
    for (final e in rules.entries) {
      final v = e.value;
      if (v == null) continue;
      buf.writeln('${e.key}: $v');
    }
    return buf.toString().trim();
  }

  Widget _buildJoinCard() {
    final uid = AppAuthContext.userId;
    if (uid == null) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Sign in to request joining this tournament with your team.',
          style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.9)),
        ),
      );
    }
    if (_isCreator) return const SizedBox.shrink();

    _eligibleTeamsFuture ??= _loadEligibleTeamsForJoin();
    return FutureBuilder<List<_EligibleTeam>>(
      future: _eligibleTeamsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            ),
          );
        }
        final eligible = snap.data ?? const [];
        if (eligible.isEmpty) {
          return AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: const Text(
              'No eligible teams to join with. You must be captain or admin of a team that is not already in this tournament.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          );
        }
        String? selectedId = eligible.first.id;
        return StatefulBuilder(
          builder: (context, setSt) {
            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Join tournament',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: selectedId,
                    decoration: InputDecoration(
                      labelText: 'Team',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
                      ),
                    ),
                    dropdownColor: AppColors.bgElevated,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: eligible
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.id,
                            child: Text(e.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => selectedId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Send join request',
                    icon: Icons.send_rounded,
                    onPressed: selectedId == null
                        ? null
                        : () => _submitJoinRequest(selectedId!),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.bgBase,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: _isCreator
          ? FloatingActionButton.extended(
              onPressed: _openScheduleSheet,
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: AppColors.bgBase,
              icon: const Icon(Icons.add),
              label: const Text('Schedule match'),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.accentPrimary,
        onRefresh: _reload,
        child: FutureBuilder<_TournamentPageData>(
          future: _pageFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentPrimary),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    snap.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            final data = snap.data!;
            final items = data.matches;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(child: _buildInfoCard(data.detail)),
                ),
                if (!_isCreator)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(child: _buildJoinCard()),
                  ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Fixtures',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No matches scheduled yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      100,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final m = items[index];
                          final date = m.matchDate == null
                              ? 'TBD'
                              : DateFormat('yyyy-MM-dd HH:mm').format(m.matchDate!.toLocal());
                          final home = _teamLabel(m, home: true);
                          final away = _teamLabel(m, home: false);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Card(
                              color: AppColors.bgElevated,
                              child: ListTile(
                                title: Text(
                                  '$home  vs  $away',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '$date • ${m.status}',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                                trailing: Text(
                                  '${m.homeScore} - ${m.awayScore}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EligibleTeam {
  const _EligibleTeam(this.id, this.name);

  final String id;
  final String name;
}
