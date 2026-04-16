import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/ui/app_button.dart';
import '../../../../shared/ui/app_card.dart';
import '../../../../shared/ui/app_scaffold.dart';
import '../../../../shared/ui/app_top_bar.dart';
import '../../domain/repositories/tournaments_repository.dart';
import '../bloc/tournaments_bloc.dart';
import '../bloc/tournaments_event.dart';
import '../bloc/tournaments_state.dart';
import 'tournament_details_screen.dart';

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          TournamentsBloc(context.read<TournamentsRepository>())
            ..add(const TournamentsStarted()),
      child: const _TournamentsView(),
    );
  }
}

class _TournamentsView extends StatelessWidget {
  const _TournamentsView();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const AppTopBar(title: 'Tournaments'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: AppColors.bgBase,
        onPressed: () => _openCreateTournamentComposer(context),
        icon: const Icon(Icons.add),
        label: const Text('New tournament'),
      ),
      body: BlocBuilder<TournamentsBloc, TournamentsState>(
        builder: (context, state) {
          if (state is TournamentsLoading || state is TournamentsInitial) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            );
          }
          if (state is TournamentsFailure) {
            return Center(
              child: Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          final ready = state as TournamentsReady;
          return ListView(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 100),
            children: [
              _TournamentsOverviewCard(total: ready.items.length),
              const SizedBox(height: AppSpacing.md),
              if (ready.items.isEmpty)
                const AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No tournaments yet. Create your first one.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...ready.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TournamentDetailsScreen(
                                tournamentId: item.id,
                                title: item.name,
                                createdByUserId: item.createdBy,
                              ),
                            ),
                          );
                        },
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${_labelType(item.type)} • ${item.status}',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _labelType(String type) {
    switch (type) {
      case 'KNOCKOUT':
        return 'Knockout';
      case 'LEAGUE':
        return 'League';
      default:
        return 'Friendly';
    }
  }
}

class _TournamentsOverviewCard extends StatelessWidget {
  const _TournamentsOverviewCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tournament hub',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$total total tournaments',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openCreateTournamentComposer(BuildContext context) async {
  final tournamentsBloc = context.read<TournamentsBloc>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => BlocProvider.value(
      value: tournamentsBloc,
      child: const _TournamentComposerSheet(),
    ),
  );
}

class _TournamentComposerSheet extends StatefulWidget {
  const _TournamentComposerSheet();

  @override
  State<_TournamentComposerSheet> createState() =>
      _TournamentComposerSheetState();
}

class _TournamentComposerSheetState extends State<_TournamentComposerSheet> {
  final _name = TextEditingController();
  final _rules = TextEditingController();
  String _type = 'LEAGUE';
  int _maxTeams = 8;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;

  List<int> get _teamOptions {
    if (_type == 'KNOCKOUT') {
      return const [4, 8, 16, 32];
    }
    return const [4, 6, 8, 10, 12, 16, 20];
  }

  @override
  void dispose() {
    _name.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final minDate = _startDate ?? DateTime(now.year, now.month, now.day);
    final initial = _endDate != null && !_endDate!.isBefore(minDate)
        ? _endDate!
        : minDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not set';
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _submitting) return;
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date')),
      );
      return;
    }
    final rulesText = _rules.text.trim();
    setState(() => _submitting = true);
    context.read<TournamentsBloc>().add(
          TournamentCreateRequested(
            name: name,
            type: _type,
            maxTeams: _maxTeams,
            startDate: _startDate,
            endDate: _endDate,
            rules: rulesText.isEmpty
                ? null
                : <String, dynamic>{'notes': rulesText},
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create tournament',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Set format and capacity first. You can configure teams and schedule next.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _name,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Tournament name',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: AppColors.bgElevated,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Format'),
                items: const [
                  DropdownMenuItem(value: 'LEAGUE', child: Text('League')),
                  DropdownMenuItem(value: 'KNOCKOUT', child: Text('Knockout')),
                  DropdownMenuItem(value: 'FRIENDLY', child: Text('Friendly')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _type = v;
                    if (!_teamOptions.contains(_maxTeams)) {
                      _maxTeams = _teamOptions.first;
                    }
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Maximum teams',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _teamOptions
                    .map(
                      (option) => ChoiceChip(
                        selected: _maxTeams == option,
                        onSelected: (_) => setState(() => _maxTeams = option),
                        label: Text('$option'),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.event_available),
                      label: Text('Start: ${_formatDate(_startDate)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event),
                      label: Text('End: ${_formatDate(_endDate)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _rules,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Rules',
                  hintText: 'Optional tournament rules and notes',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _submitting ? 'Creating...' : 'Create tournament',
                onPressed: _submitting ? null : _submit,
                icon: Icons.emoji_events_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
