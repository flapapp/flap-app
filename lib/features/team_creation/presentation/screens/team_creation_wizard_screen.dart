import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flap_app/features/team_creation/domain/entities/player.dart';
import 'package:flap_app/features/team_creation/domain/entities/player_position.dart';
import 'package:flap_app/features/team_creation/presentation/bloc/team_creation_bloc.dart';
import 'package:flap_app/features/team_creation/presentation/bloc/team_creation_event.dart';
import 'package:flap_app/features/team_creation/presentation/bloc/team_creation_state.dart';
import 'package:flap_app/features/team_creation/presentation/widgets/squad_invite_search_panel.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/city_autocomplete_field.dart';

InputDecoration _squadAddDialogDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF36D399)),
    ),
  );
}

class TeamCreationWizardScreen extends StatefulWidget {
  const TeamCreationWizardScreen({
    super.key,
    required this.existingTeams,
    required this.currentUserId,
  });

  final int existingTeams;
  final String currentUserId;

  @override
  State<TeamCreationWizardScreen> createState() =>
      _TeamCreationWizardScreenState();
}

class _TeamCreationWizardScreenState extends State<TeamCreationWizardScreen> {
  final _pageCtrl = PageController();
  final _nameCtrl = TextEditingController();
  final _shortCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _manifestoCtrl = TextEditingController();
  final _identityForm = GlobalKey<FormState>();
  bool _isPublic = true;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _shortCtrl.dispose();
    _yearCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _manifestoCtrl.dispose();
    super.dispose();
  }

  String _mapError(String? code) {
    if (code == null) return '';
    switch (code) {
      case 'short_name_len':
        return I18n.inline(
          'Коротка назва — до 5 символів',
          'Short name: max 5 characters',
        );
      case 'name_short':
        return I18n.inline(
          'Назва клубу — мінімум 3 символи',
          'Club name needs at least 3 characters',
        );
      case 'add_player_invalid':
        return I18n.inline(
          'Перевірте дані гравця (ім’я, номер, вік)',
          'Check player details (name, number, age)',
        );
      case 'squad_too_small':
        return I18n.inline(
          'Некоректний розмір складу',
          'Invalid squad size',
        );
      case 'squad_too_large':
        return I18n.inline('Занадто великий склад', 'Squad is too large');
      case 'duplicate_jersey':
        return I18n.inline(
          'Дубль номера на формі',
          'Duplicate jersey number',
        );
      default:
        return code;
    }
  }

  void _syncPage(int step) {
    if (_pageCtrl.hasClients) {
      _pageCtrl.animateToPage(
        step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF36D399);
    final limitReached = widget.existingTeams >= 3;

    return BlocConsumer<TeamCreationBloc, TeamCreationState>(
      listenWhen: (a, b) =>
          a.status != b.status ||
          a.errorMessage != b.errorMessage ||
          a.stepIndex != b.stepIndex ||
          a.maxStepVisited != b.maxStepVisited,
      listener: (context, state) {
        if (state.status == TeamCreationStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                I18n.inline('Клуб створено!', 'Club created!'),
              ),
              backgroundColor: accent,
            ),
          );
          Navigator.of(context).pop();
          return;
        }
        if (state.status == TeamCreationStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_mapError(state.errorMessage)),
              backgroundColor: Colors.redAccent,
            ),
          );
          context.read<TeamCreationBloc>().add(const TeamCreationClearError());
        }
        _syncPage(state.stepIndex);
      },
      builder: (context, state) {
        final busy = state.status == TeamCreationStatus.loading;
        void goBackOneStep() {
          if (busy) return;
          if (state.stepIndex > 0) {
            context.read<TeamCreationBloc>().add(
                  TeamCreationWizardStepChanged(state.stepIndex - 1),
                );
          } else {
            Navigator.of(context).maybePop();
          }
        }

        void goForwardOneStep() {
          if (busy) return;
          if (state.stepIndex < state.maxStepVisited) {
            context.read<TeamCreationBloc>().add(
                  TeamCreationWizardStepChanged(state.stepIndex + 1),
                );
          }
        }

        return PopScope(
          canPop: state.stepIndex == 0 || busy,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (!busy && state.stepIndex > 0) {
              context.read<TeamCreationBloc>().add(
                    TeamCreationWizardStepChanged(state.stepIndex - 1),
                  );
            }
          },
          child: Scaffold(
          backgroundColor: const Color(0xFF05080F),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: Colors.white,
              onPressed: busy ? null : goBackOneStep,
            ),
            title: Text(I18n.inline('Новий клуб', 'New club')),
            actions: [
              if (!busy &&
                  !limitReached &&
                  state.stepIndex < state.maxStepVisited)
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  color: Colors.white,
                  tooltip: I18n.inline('Наступний крок', 'Next step'),
                  onPressed: goForwardOneStep,
                ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF05080F), Color(0xFF071A26)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _ProgressHeader(
                    step: state.stepIndex,
                    maxStepVisited: state.maxStepVisited,
                    accent: accent,
                    navEnabled: !limitReached && !busy,
                    onStepSelected: (i) {
                      if (busy || limitReached) return;
                      if (i <= state.maxStepVisited) {
                        context.read<TeamCreationBloc>().add(
                              TeamCreationWizardStepChanged(i),
                            );
                      }
                    },
                  ),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: limitReached || busy,
                      child: Opacity(
                        opacity: limitReached ? 0.5 : 1,
                        child: PageView(
                          controller: _pageCtrl,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _IdentityPage(
                              formKey: _identityForm,
                              nameCtrl: _nameCtrl,
                              shortCtrl: _shortCtrl,
                              yearCtrl: _yearCtrl,
                              countryCtrl: _countryCtrl,
                              cityCtrl: _cityCtrl,
                              manifestoCtrl: _manifestoCtrl,
                              accent: accent,
                              limitReached: limitReached,
                              onContinue: () {
                                if (!_identityForm.currentState!.validate()) {
                                  return;
                                }
                                int? y;
                                final ys = _yearCtrl.text.trim();
                                if (ys.isNotEmpty) {
                                  y = int.tryParse(ys);
                                  if (y == null ||
                                      y < 1800 ||
                                      y > DateTime.now().year) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          I18n.inline(
                                            'Некоректний рік заснування',
                                            'Invalid founding year',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }
                                context.read<TeamCreationBloc>().add(
                                      TeamCreationSubmitClubIdentity(
                                        teamName: _nameCtrl.text,
                                        shortName: _shortCtrl.text,
                                        foundedYear: y,
                                        country: _countryCtrl.text,
                                        city: _cityCtrl.text,
                                        manifesto: _manifestoCtrl.text,
                                      ),
                                    );
                              },
                            ),
                            _BrandingPage(
                              accent: accent,
                              initialPrimary: state.primaryHex,
                              initialSecondary: state.secondaryHex,
                              onContinue: (primary, secondary, bytes) {
                                context.read<TeamCreationBloc>().add(
                                      TeamCreationSubmitBranding(
                                        primaryHex: primary,
                                        secondaryHex: secondary,
                                        logoBytes: bytes,
                                      ),
                                    );
                              },
                              onSkip: () {
                                context.read<TeamCreationBloc>().add(
                                      const TeamCreationSubmitBranding(),
                                    );
                              },
                            ),
                            _SquadPage(
                              accent: accent,
                              currentUserId: widget.currentUserId,
                              squad: state.squad,
                              status: state.status,
                              onGenerate: () => context
                                  .read<TeamCreationBloc>()
                                  .add(const TeamCreationGenerateSquadRequested()),
                              onRemove: (jersey) => context
                                  .read<TeamCreationBloc>()
                                  .add(TeamCreationRemovePlayerRequested(jersey)),
                              onAdd: (p) => context
                                  .read<TeamCreationBloc>()
                                  .add(TeamCreationAddPlayerRequested(p)),
                              onNext: () {
                                context.read<TeamCreationBloc>().add(
                                      const TeamCreationWizardStepChanged(3),
                                    );
                              },
                            ),
                            _ReviewPage(
                              accent: accent,
                              state: state,
                              isPublic: _isPublic,
                              onPublicChanged: (v) =>
                                  setState(() => _isPublic = v),
                              onSubmit: () {
                                context.read<TeamCreationBloc>().add(
                                      TeamCreationSubmitTeam(
                                        isPublic: _isPublic,
                                      ),
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (busy)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: accent,
                      backgroundColor: Colors.white12,
                    ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.step,
    required this.maxStepVisited,
    required this.accent,
    required this.navEnabled,
    required this.onStepSelected,
  });

  final int step;
  final int maxStepVisited;
  final Color accent;
  final bool navEnabled;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    final labels = [
      I18n.inline('Клуб', 'Club'),
      I18n.inline('Стиль', 'Style'),
      I18n.inline('Склад', 'Squad'),
      I18n.inline('Перевірка', 'Review'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: List.generate(4, (i) {
          final active = i <= step;
          final reachable = i <= maxStepVisited;
          final tappable = navEnabled && reachable;
          final barColor = !reachable
              ? Colors.white.withValues(alpha: 0.12)
              : (active ? accent : Colors.white24);
          final labelColor = !reachable
              ? Colors.white.withValues(alpha: 0.22)
              : (active ? Colors.white : Colors.white38);

          final content = Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: active ? 1 : 0.15,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: barColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
              child: tappable
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onStepSelected(i),
                        borderRadius: BorderRadius.circular(8),
                        splashColor: accent.withValues(alpha: 0.25),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: content,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: content,
                    ),
            ),
          );
        }),
      ),
    );
  }
}

class _IdentityPage extends StatelessWidget {
  const _IdentityPage({
    required this.formKey,
    required this.nameCtrl,
    required this.shortCtrl,
    required this.yearCtrl,
    required this.countryCtrl,
    required this.cityCtrl,
    required this.manifestoCtrl,
    required this.accent,
    required this.limitReached,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController shortCtrl;
  final TextEditingController yearCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController manifestoCtrl;
  final Color accent;
  final bool limitReached;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (limitReached) _LimitCard(accent: accent),
            if (limitReached) const SizedBox(height: 16),
            Text(
              I18n.inline('Ідентичність клубу', 'Club identity'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              I18n.inline(
                'Офіційна назва, локація та голос бренду.',
                'Official name, location, and your club voice.',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _Field(
              controller: nameCtrl,
              label: I18n.inline('Назва клубу', 'Club name'),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return I18n.inline('Мінімум 3 символи', 'At least 3 characters');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _Field(
              controller: shortCtrl,
              label: I18n.inline('Коротка назва (до 5)', 'Short name (max 5)'),
              maxLength: 5,
              validator: (v) {
                if (v != null && v.trim().length > 5) {
                  return I18n.inline('Максимум 5', 'Max 5 characters');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _Field(
              controller: yearCtrl,
              label: I18n.inline('Рік заснування (опційно)', 'Founded year (optional)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            _Field(
              controller: countryCtrl,
              label: I18n.inline('Країна', 'Country'),
            ),
            const SizedBox(height: 14),
            CityAutocompleteField(
              controller: cityCtrl,
              label: I18n.inline('Місто (опційно)', 'City (optional)'),
              requiredField: false,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              labelStyle: const TextStyle(color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accent),
              ),
              prefixIcon: const Icon(Icons.location_city, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            _Field(
              controller: manifestoCtrl,
              label: I18n.inline('Маніфест / опис', 'Manifesto / description'),
              maxLines: 3,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: limitReached ? null : onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: const Color(0xFF041013),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  I18n.inline('Далі: брендинг', 'Next: branding'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              I18n.inline(
                'Максимум 3 клуби на гравця.',
                'You can own up to 3 clubs.',
              ),
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandingPage extends StatefulWidget {
  const _BrandingPage({
    required this.accent,
    required this.onContinue,
    required this.onSkip,
    this.initialPrimary,
    this.initialSecondary,
  });

  final Color accent;
  final String? initialPrimary;
  final String? initialSecondary;
  final void Function(String? primary, String? secondary, Uint8List? logo)
      onContinue;
  final VoidCallback onSkip;

  @override
  State<_BrandingPage> createState() => _BrandingPageState();
}

class _BrandingPageState extends State<_BrandingPage> {
  static const _presets = [
    '#36D399',
    '#5B8DEF',
    '#FF6B35',
    '#FBBF24',
    '#A855F7',
    '#F43F5E',
    '#22D3EE',
    '#E5E7EB',
  ];

  String? _primary;
  String? _secondary;
  Uint8List? _logo;

  @override
  void initState() {
    super.initState();
    _primary = widget.initialPrimary ?? _presets[0];
    _secondary = widget.initialSecondary ?? _presets[1];
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _logo = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.inline('Кольори та емблема', 'Colors & crest'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.inline(
              'Опційно — можна пропустити й додати пізніше.',
              'Optional — you can skip and refine later.',
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Text(
            I18n.inline('Основний колір', 'Primary color'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets
                .map(
                  (hex) => _ColorDot(
                    hex: hex,
                    selected: _primary == hex,
                    onTap: () => setState(() => _primary = hex),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          Text(
            I18n.inline('Другий колір', 'Secondary color'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets
                .map(
                  (hex) => _ColorDot(
                    hex: hex,
                    selected: _secondary == hex,
                    onTap: () => setState(() => _secondary = hex),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  backgroundImage: _logo != null ? MemoryImage(_logo!) : null,
                  child: _logo == null
                      ? Icon(Icons.shield_moon_outlined,
                          size: 40, color: widget.accent)
                      : null,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.upload, color: Colors.white),
                  label: Text(
                    I18n.inline('Завантажити емблему', 'Upload crest'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onSkip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(I18n.inline('Пропустити', 'Skip')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () =>
                      widget.onContinue(_primary, _secondary, _logo),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: const Color(0xFF041013),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    I18n.inline('Далі: склад', 'Next: squad'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  Color _parse() {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _parse(),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _parse().withValues(alpha: 0.55),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _SquadPage extends StatelessWidget {
  const _SquadPage({
    required this.accent,
    required this.currentUserId,
    required this.squad,
    required this.status,
    required this.onGenerate,
    required this.onRemove,
    required this.onAdd,
    required this.onNext,
  });

  final Color accent;
  final String currentUserId;
  final List<Player> squad;
  final TeamCreationStatus status;
  final VoidCallback onGenerate;
  final void Function(int jersey) onRemove;
  final void Function(Player p) onAdd;
  final VoidCallback onNext;

  Future<void> _openAddDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final jerseyCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final natCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final posNotifier = ValueNotifier(PlayerPosition.mf);

    try {
      await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1522),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ValueListenableBuilder<PlayerPosition>(
          valueListenable: posNotifier,
          builder: (ctx, pos, _) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      I18n.inline('Новий гравець', 'New player'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          _squadAddDialogDecoration(I18n.inline('Ім’я', 'Name')),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? I18n.inline('Обов’язково', 'Required')
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      I18n.inline('Амплуа', 'Position'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PlayerPosition.values.map((p) {
                        final sel = pos == p;
                        return ChoiceChip(
                          label: Text(p.label),
                          selected: sel,
                          onSelected: (_) => posNotifier.value = p,
                          selectedColor: accent.withValues(alpha: 0.45),
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: jerseyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _squadAddDialogDecoration(
                          I18n.inline('Номер', 'Number')),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 99) {
                          return I18n.inline('1–99', '1–99');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _squadAddDialogDecoration(
                          I18n.inline('Вік (опційно)', 'Age (optional)')),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: natCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _squadAddDialogDecoration(
                          I18n.inline('Національність', 'Nationality')),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final age = int.tryParse(ageCtrl.text.trim());
                          onAdd(
                            Player(
                              name: nameCtrl.text.trim(),
                              position: posNotifier.value,
                              jerseyNumber: int.parse(jerseyCtrl.text.trim()),
                              age: age,
                              nationality: natCtrl.text.trim().isEmpty
                                  ? null
                                  : natCtrl.text.trim(),
                            ),
                          );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: const Color(0xFF041013),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(I18n.inline('Додати', 'Add')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    } finally {
      posNotifier.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyBanner = status == TeamCreationStatus.squadReady;
    return Column(
      children: [
        if (readyBanner)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    I18n.inline(
                      'Склад згенеровано — можна редагувати.',
                      'Squad generated — tweak as you like.',
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.casino, color: Colors.white70, size: 18),
                  label: Text(
                    I18n.inline('Авто-склад', 'Auto squad'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openAddDialog(context),
                  icon: const Icon(Icons.person_add_alt_1,
                      color: Colors.white70, size: 18),
                  label: Text(
                    I18n.inline('Вручну', 'Manual'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SquadInviteSearchPanel(
            accent: accent,
            currentUserId: currentUserId,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: squad.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          I18n.inline(
                            'Згенеруйте або додайте гравців — або залиште порожнім.',
                            'Generate or add players — or leave empty.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          I18n.inline(
                            'Натисніть «Далі», щоб пропустити цей крок.',
                            'Tap Next below to skip this step.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: squad.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = squad[i];
                    return Dismissible(
                      key: ValueKey('${p.jerseyNumber}-${p.name}'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => onRemove(p.jerseyNumber),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.withValues(alpha: 0.35),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: accent.withValues(alpha: 0.25),
                              child: Text(
                                '${p.jerseyNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${p.position.label} · ${p.age ?? '—'} · ${p.nationality ?? '—'}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: const Color(0xFF041013),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                squad.isEmpty
                    ? I18n.inline(
                        'Далі: перевірка (без складу)',
                        'Next: review (no squad)',
                      )
                    : I18n.inline('Далі: перевірка', 'Next: review'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({
    required this.accent,
    required this.state,
    required this.isPublic,
    required this.onPublicChanged,
    required this.onSubmit,
  });

  final Color accent;
  final TeamCreationState state;
  final bool isPublic;
  final ValueChanged<bool> onPublicChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.inline('Підсумок', 'Summary'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryCard(
            title: state.teamName,
            subtitle:
                '${state.shortName.isEmpty ? '—' : state.shortName} · ${state.city.isEmpty ? I18n.inline('без міста', 'no city') : state.city}',
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: I18n.inline('Склад', 'Squad'),
            subtitle: state.squad.isEmpty
                ? I18n.inline(
                    'Порожньо — можна наповнити пізніше',
                    'Empty — you can add players later',
                  )
                : '${state.squad.length} ${I18n.inline('гравців', 'players')}',
          ),
          const SizedBox(height: 20),
          SwitchListTile.adaptive(
            value: isPublic,
            onChanged: onPublicChanged,
            activeTrackColor: accent.withValues(alpha: 0.35),
            activeThumbColor: accent,
            title: Text(
              I18n.inline('Публічний клуб', 'Public club'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              I18n.inline(
                'Буде видно в пошуку та хабі клубів',
                'Visible in search and the clubs hub',
              ),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: const Color(0xFF041013),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                I18n.inline('Створити клуб', 'Create club'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF36D399)),
        ),
      ),
      validator: validator,
    );
  }
}
