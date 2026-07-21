import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import '../../../subscriptions/presentation/premium_gate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/match.dart';
import '../../application/create_match_command.dart';
import '../../application/create_match_use_case.dart';
import '../../../teams/data/models/app_team.dart';
import 'match_invite_search_screen.dart';
import 'team_invite_search_screen.dart';
import '../../../../core/di/injection.dart';
import '../../../../features/teams/domain/repositories/teams_repository.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/team_logo_button.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import '../../../../theme/flap_tokens.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/city_localization.dart';

@RoutePage()
class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  CreateMatchScreenState createState() => CreateMatchScreenState();
}

class CreateMatchScreenState extends State<CreateMatchScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedCity = tr('kyiv');
  String _selectedLevel = tr('intermediate');
  int _selectedPlayers = 10;
  double _cost = 0.0;
  bool _autoBalance = true;
  bool _isPrivate = false;
  final Set<String> _selectedInviteFriendIds = <String>{};
  final Map<String, Map<String, dynamic>> _selectedInviteUsers =
      <String, Map<String, dynamic>>{};

  List<String> get _levels =>
      [tr('beginner'), tr('intermediate'), tr('advanced'), tr('professional')];

  static const List<IconData> _levelIcons = <IconData>[
    Icons.eco_rounded,
    Icons.trending_up_rounded,
    Icons.local_fire_department_rounded,
    Icons.military_tech_rounded,
  ];

  final List<int> _playerOptions = [4, 6, 8, 10, 12, 14, 16, 18, 20, 22];
  final ScrollController _friendsScrollController = ScrollController();

  TeamsRepository get _teamsRepo => sl<TeamsRepository>();

  CreateMatchUseCase get _createMatchUseCase => sl<CreateMatchUseCase>();

  bool _isCreating = false;
  bool _teamMode = false;
  bool _loadingTeams = true;
  List<AppTeam> _myTeams = [];
  AppTeam? _selectedTeam;
  List<String> _selectedRoster = [];
  Map<String, String> _teamMemberNames = {};
  AppTeam? _opponentTeam;

  @override
  void initState() {
    super.initState();
    _cityController.text = _selectedCity;
    _loadMyTeams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlapColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: SafeArea(
          child: Column(
            children: [
              _appBar(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      // Match title
                      _label(tr('il_40e6c88126')),
                      _inputField(
                        controller: _titleController,
                        hint: tr('il_40e6c88126'),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return tr('il_23245bd9a6');
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Description
                      _label(tr('il_61c1c67c7f')),
                      _inputField(
                        controller: _descriptionController,
                        hint: tr('il_61c1c67c7f'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 18),

                      // Date and time
                      Row(
                        children: [
                          Expanded(
                            child: _pickerTile(
                              icon: Icons.calendar_today_rounded,
                              caption: tr('il_c218c8b08e'),
                              value:
                                  '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _pickerTile(
                              icon: Icons.access_time_rounded,
                              caption: tr('il_f255eef12c'),
                              value:
                                  '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Location
                      _label(tr('il_692d4cc700')),
                      _inputField(
                        controller: _locationController,
                        hint: tr('il_692d4cc700'),
                        icon: Icons.place_rounded,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return tr('il_de5898b9bb');
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // City
                      _label(tr('il_4b59236336')),
                      _cityField(),
                      const SizedBox(height: 18),

                      // Skill level
                      _label(tr('il_1213d3201a')),
                      _levelChips(),
                      const SizedBox(height: 18),

                      // Player count and price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label(tr('il_62a929fea8')),
                                _playersDropdown(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label(tr('il_6d595710b8')),
                                _inputField(
                                  hint: '0',
                                  icon: Icons.payments_rounded,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() =>
                                        _cost = double.tryParse(value) ?? 0.0);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Settings
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 640;
                          final toggles = [
                            _buildSettingToggle(
                              icon: Icons.balance_rounded,
                              title: tr('il_ace59f5c4f'),
                              subtitle: tr('il_2989176c3a'),
                              value: _autoBalance,
                              onChanged: (value) {
                                setState(() => _autoBalance = value);
                              },
                            ),
                            _buildSettingToggle(
                              icon: Icons.lock_rounded,
                              title: tr('il_aaffbee0e1'),
                              subtitle: tr('il_b7dc15d102'),
                              value: _isPrivate,
                              onChanged: (value) {
                                setState(() => _isPrivate = value);
                              },
                            ),
                          ];
                          if (isNarrow) {
                            return Column(
                              children: [
                                toggles[0],
                                const SizedBox(height: 12),
                                toggles[1],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: toggles[0]),
                              const SizedBox(width: 12),
                              Expanded(child: toggles[1]),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),
                      _teamModeSwitch(),
                      if (_teamMode) _buildTeamModeSection(),

                      const SizedBox(height: 20),
                      if (!_teamMode) ...[
                        Row(
                          children: [
                            const Icon(Icons.person_add_alt_1_rounded,
                                color: FlapColors.greenBright, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              tr('il_2614b42d84'),
                              style: FlapText.sora(
                                color: FlapColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            _ghostButton(
                              icon: Icons.search_rounded,
                              label: tr('il_146ee72e30'),
                              onTap: _openInviteSearchPage,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_selectedInviteFriendIds.isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: FlapColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: FlapColors.border),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: _selectedInviteFriendIds.map((id) {
                                final user = _selectedInviteUsers[id] ??
                                    const <String, dynamic>{};
                                final name = (user['displayName'] ??
                                        user['display_name'] ??
                                        user['email']
                                            ?.toString()
                                            .split('@')
                                            .first ??
                                        tr('player'))
                                    .toString();
                                final avatar = (user['avatarUrl'] ??
                                        user['avatar_url'] ??
                                        '')
                                    .toString();
                                final city =
                                    (user['city'] ?? '').toString();
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  leading: PlayerAvatarButton(
                                    userId: id,
                                    displayName: name,
                                    avatarUrl: avatar,
                                    size: 34,
                                  ),
                                  title: Text(
                                    name,
                                    style: FlapText.sora(
                                      color: FlapColors.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: city.isEmpty
                                      ? null
                                      : Text(
                                          localizeCity(city),
                                          style: FlapText.sora(
                                              color: FlapColors.muted,
                                              fontSize: 12),
                                        ),
                                  trailing: IconButton(
                                    tooltip: tr('remove'),
                                    icon: const Icon(Icons.close_rounded,
                                        color: FlapColors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _selectedInviteFriendIds.remove(id);
                                        _selectedInviteUsers.remove(id);
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadMyFriends(),
                          builder: (context, snapshot) {
                            final friends =
                                snapshot.data ?? const <Map<String, dynamic>>[];
                            if (friends.isEmpty) {
                              return Text(
                                tr('il_3f6a83aa65'),
                                style: FlapText.sora(
                                    color: FlapColors.muted, fontSize: 13),
                              );
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: FlapColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: FlapColors.border),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: SizedBox(
                                height: 240,
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  controller: _friendsScrollController,
                                  child: ListView.separated(
                                    controller: _friendsScrollController,
                                    primary: false,
                                    shrinkWrap: true,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: friends.length,
                                    separatorBuilder: (_, __) => const Divider(
                                      height: 1,
                                      color: FlapColors.border,
                                    ),
                                    itemBuilder: (context, i) {
                                      final f = friends[i];
                                      final id = f['id'] as String;
                                      final name = (f['displayName'] ??
                                              f['name'] ??
                                              tr('il_b512d97e7c'))
                                          .toString();
                                      final photoUrl = (f['avatarUrl'] ??
                                              f['photoUrl'] ??
                                              '')
                                          .toString();
                                      final position = (f['position'] ??
                                              f['role'] ??
                                              '')
                                          .toString();
                                      final rating = ((f['rating'] ??
                                                  f['averageRating'] ??
                                                  0) as num)
                                              .toDouble();
                                      final selected = _selectedInviteFriendIds
                                          .contains(id);

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8),
                                        leading: PlayerAvatarButton(
                                          userId: id,
                                          displayName: name,
                                          avatarUrl: photoUrl,
                                          size: 36,
                                        ),
                                        title: Text(
                                          name,
                                          style: FlapText.sora(
                                              color: FlapColors.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Row(
                                          children: [
                                            if (position.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: FlapColors.surface2,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  position,
                                                  style: FlapText.sora(
                                                      color: FlapColors.muted,
                                                      fontSize: 12),
                                                ),
                                              ),
                                            if (position.isNotEmpty)
                                              const SizedBox(width: 8),
                                            const Icon(Icons.star_rounded,
                                                size: 14,
                                                color: FlapColors.gold),
                                            const SizedBox(width: 2),
                                            Text(
                                              rating > 0
                                                  ? rating.toStringAsFixed(2)
                                                  : '-',
                                              style: FlapText.sora(
                                                  color: FlapColors.muted,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        trailing: Checkbox(
                                          value: selected,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedInviteFriendIds
                                                    .add(id);
                                                _selectedInviteUsers[id] = {
                                                  'id': id,
                                                  'displayName': name,
                                                  'avatarUrl': photoUrl,
                                                  'city': '',
                                                };
                                              } else {
                                                _selectedInviteFriendIds
                                                    .remove(id);
                                                _selectedInviteUsers
                                                    .remove(id);
                                              }
                                            });
                                          },
                                          activeColor: FlapColors.green,
                                          checkColor: FlapColors.onGreen,
                                          side: const BorderSide(
                                              color: FlapColors.borderStrong),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            if (selected) {
                                              _selectedInviteFriendIds
                                                  .remove(id);
                                              _selectedInviteUsers.remove(id);
                                            } else {
                                              _selectedInviteFriendIds.add(id);
                                              _selectedInviteUsers[id] = {
                                                'id': id,
                                                'displayName': name,
                                                'avatarUrl': photoUrl,
                                                'city': '',
                                              };
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: FlapColors.surface,
                            borderRadius: BorderRadius.circular(FlapRadii.tile),
                            border: Border.all(color: FlapColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.groups_rounded,
                                  color: FlapColors.muted, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr('il_361b9541bf'),
                                  style: FlapText.sora(
                                      color: FlapColors.muted, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Create button
                      _primaryButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Chrome / styled builders ------------------------------------------

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: FlapColors.surface2,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: FlapColors.border),
              ),
              child: const Icon(Icons.chevron_left,
                  color: FlapColors.text, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('create_match'),
              style: FlapText.sora(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: FlapColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: FlapText.sora(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: FlapColors.muted,
        ),
      ),
    );
  }

  Widget _inputField({
    TextEditingController? controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FlapColors.surface2,
        borderRadius: BorderRadius.circular(FlapRadii.field),
        border: Border.all(color: FlapColors.border),
      ),
      child: TextFormField(
        controller: controller,
        style: FlapText.sora(color: FlapColors.text, fontSize: 15),
        cursorColor: FlapColors.greenBright,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: FlapText.sora(color: FlapColors.muted, fontSize: 15),
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: FlapColors.muted, size: 19),
          border: InputBorder.none,
          errorStyle: FlapText.sora(color: FlapColors.red, fontSize: 11.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String caption,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(FlapRadii.field),
          border: Border.all(color: FlapColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: FlapColors.muted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: FlapText.sora(
                        color: FlapColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: FlapText.sora(
                      color: FlapColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityField() {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(FlapRadii.field),
      borderSide: const BorderSide(color: FlapColors.border),
    );
    return CityAutocompleteField(
      controller: _cityController,
      label: tr('il_4b59236336'),
      requiredField: true,
      filled: true,
      fillColor: FlapColors.surface2,
      style: FlapText.sora(color: FlapColors.text, fontSize: 15),
      labelStyle: FlapText.sora(color: FlapColors.muted, fontSize: 15),
      border: outline,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FlapRadii.field),
        borderSide: const BorderSide(color: FlapColors.greenBright, width: 1.4),
      ),
      prefixIcon: const Icon(Icons.location_city_rounded,
          color: FlapColors.muted, size: 20),
      onSelected: (value) => setState(() => _selectedCity = value.trim()),
    );
  }

  Widget _levelChips() {
    final levels = _levels;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(levels.length, (i) {
        final level = levels[i];
        final active = _selectedLevel == level;
        return GestureDetector(
          onTap: () => setState(() => _selectedLevel = level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? FlapColors.green.withOpacity(0.16)
                  : FlapColors.surface,
              borderRadius: BorderRadius.circular(FlapRadii.chip),
              border: Border.all(
                color: active
                    ? FlapColors.green.withOpacity(0.55)
                    : FlapColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _levelIcons[i],
                  size: 16,
                  color: active ? FlapColors.greenBright : FlapColors.muted,
                ),
                const SizedBox(width: 7),
                Text(
                  level,
                  style: FlapText.sora(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? FlapColors.greenBright : FlapColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _playersDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FlapColors.surface2,
        borderRadius: BorderRadius.circular(FlapRadii.field),
        border: Border.all(color: FlapColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedPlayers,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, color: FlapColors.muted),
          style: FlapText.sora(color: FlapColors.text, fontSize: 15),
          dropdownColor: FlapColors.card,
          borderRadius: BorderRadius.circular(FlapRadii.tile),
          items: _playerOptions
              .map((players) => DropdownMenuItem(
                    value: players,
                    child: Text(
                      tr('il_460cbf0720', namedArgs: {'players': '$players'}),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedPlayers = value!;
              if (_teamMode) {
                _ensureRosterLimit();
              }
            });
          },
        ),
      ),
    );
  }

  Widget _teamModeSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(FlapRadii.tile),
        border: Border.all(color: FlapColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          tr('il_5084b91728'),
          style: FlapText.sora(
            color: FlapColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          tr('il_a94d1ecc4e'),
          style: FlapText.sora(color: FlapColors.muted, fontSize: 12),
        ),
        value: _teamMode,
        activeThumbColor: FlapColors.green,
        activeTrackColor: FlapColors.green.withOpacity(0.4),
        onChanged: (value) {
          setState(() {
            _teamMode = value;
            if (value) {
              _autoBalance = false;
              _selectedInviteFriendIds.clear();
              _selectedInviteUsers.clear();
              if (_selectedTeam == null && _myTeams.isNotEmpty) {
                _selectedTeam = _myTeams.first;
                _selectedRoster = _selectedTeam!.memberIds
                    .take((_selectedPlayers / 2).ceil())
                    .toList();
              }
              _ensureRosterLimit();
            } else {
              _opponentTeam = null;
            }
          });
        },
      ),
    );
  }

  Widget _ghostButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(FlapRadii.chip),
          border: Border.all(color: FlapColors.green.withOpacity(0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FlapColors.greenBright, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: FlapText.sora(
                color: FlapColors.greenBright,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    return GestureDetector(
      onTap: _isCreating ? null : _createMatch,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: FlapColors.primaryButton,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: FlapColors.green.withOpacity(0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isCreating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: FlapColors.onGreen,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('create_match'),
                    style: FlapText.sora(
                      color: FlapColors.onGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: FlapColors.onGreen, size: 19),
                ],
              ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: FlapColors.green,
              onPrimary: FlapColors.onGreen,
              surface: FlapColors.card,
              onSurface: FlapColors.text,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: FlapColors.card),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: FlapColors.green,
              onPrimary: FlapColors.onGreen,
              surface: FlapColors.card,
              onSurface: FlapColors.text,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: FlapColors.card,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _createMatch() async {
    if (_isCreating) return;
    if (!_formKey.currentState!.validate()) return;
    if (!await PremiumGate.ensure(context)) return;
    setState(() => _isCreating = true);

    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) return;

      _selectedCity = _cityController.text.trim();
      if (_selectedCity.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_0683014b0c'))),
        );
        return;
      }
      final result = await _createMatchUseCase.execute(
        CreateMatchCommand(
          currentUserId: currentUser.id,
          currentUserEmail: currentUser.email,
          title: _titleController.text,
          description: _descriptionController.text,
          date: _selectedDate,
          timeLabel:
              '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
          location: _locationController.text,
          city: _selectedCity,
          maxPlayers: _selectedPlayers,
          level: _getMatchLevel(_selectedLevel),
          cost: _cost,
          autoBalance: _autoBalance,
          isPrivate: _isPrivate,
          teamMode: _teamMode,
          selectedInviteFriendIds: _teamMode
              ? const <String>[]
              : _selectedInviteFriendIds.toList(),
          selectedRoster: List<String>.from(_selectedRoster),
          selectedTeam: _selectedTeam,
          opponentTeam: _opponentTeam,
        ),
      );

      if (!mounted) return;
      await _showMatchCreatedDialog(
        result.matchId,
        _titleController.text.trim(),
        result.organizerName,
        allowIndividualInvites: !_teamMode,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_a25ff440b8', namedArgs: {'e': e.toString()}),
          ),
          backgroundColor: FlapColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Widget _buildSettingToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? FlapColors.green.withOpacity(0.1)
              : FlapColors.surface,
          borderRadius: BorderRadius.circular(FlapRadii.tile),
          border: Border.all(
            color: value ? FlapColors.green.withOpacity(0.55) : FlapColors.border,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? FlapColors.green : FlapColors.surface2,
              ),
              child: Icon(
                value ? Icons.check_rounded : icon,
                color: value ? FlapColors.onGreen : FlapColors.muted,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FlapText.sora(
                      color: FlapColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: FlapText.sora(
                      color: FlapColors.muted,
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
  }

  Future<void> _openTeamSearchSheet({required bool forHost}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlapColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final controller = TextEditingController();
        List<AppTeam> results = [];
        bool loading = false;

        Future<void> runSearch(StateSetter setSheetState) async {
          final query = controller.text.trim();
          if (query.isEmpty) return;
          setSheetState(() => loading = true);
          try {
            final found = await _teamsRepo.searchTeams(query, limit: 15);
            setSheetState(() => results = found);
          } finally {
            setSheetState(() => loading = false);
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: FlapColors.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  TextField(
                    controller: controller,
                    style: FlapText.sora(color: FlapColors.text),
                    cursorColor: FlapColors.greenBright,
                    decoration: InputDecoration(
                      labelText: tr('il_c81e115cc3'),
                      labelStyle: FlapText.sora(color: FlapColors.muted),
                      filled: true,
                      fillColor: FlapColors.surface2,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FlapColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FlapColors.greenBright),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search_rounded,
                            color: FlapColors.muted),
                        onPressed: () => runSearch(setSheetState),
                      ),
                    ),
                    onSubmitted: (_) => runSearch(setSheetState),
                  ),
                  const SizedBox(height: 16),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(color: FlapColors.green),
                    )
                  else if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        tr('il_9598782e39'),
                        style: FlapText.sora(color: FlapColors.muted),
                      ),
                    )
                  else
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: FlapColors.border),
                        itemBuilder: (_, index) {
                          final team = results[index];
                          return ListTile(
                            leading: TeamLogoButton(
                              teamId: team.id,
                              teamName: team.name,
                              logoUrl: team.logoUrl,
                              size: 36,
                            ),
                            title: Text(team.name,
                                style: FlapText.sora(color: FlapColors.text)),
                            subtitle: Text(
                              '${team.memberIds.length} ${tr('il_afc0d772a2')}',
                              style: FlapText.sora(color: FlapColors.muted),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              if (forHost) {
                                _onSelectTeam(team);
                              } else {
                                setState(() => _opponentTeam = team);
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTeamModeSection() {
    if (_loadingTeams) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(
          color: FlapColors.green,
          backgroundColor: FlapColors.surface2,
        ),
      );
    }
    if (_selectedTeam == null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlapColors.surface,
          borderRadius: BorderRadius.circular(FlapRadii.tile),
          border: Border.all(color: FlapColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('il_6aaa94a1ae'),
              style: FlapText.sora(
                color: FlapColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('il_de51695051'),
              style: FlapText.sora(color: FlapColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => _openTeamSearchSheet(forHost: true),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: FlapColors.surface2,
                    borderRadius: BorderRadius.circular(FlapRadii.field),
                    border: Border.all(color: FlapColors.green.withOpacity(0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_rounded,
                          color: FlapColors.greenBright, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        tr('il_95c42e9726'),
                        style: FlapText.sora(
                          color: FlapColors.greenBright,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final rosterLimit = (_selectedPlayers / 2).ceil();
    final myId = AppAuth.currentUserId;
    final hostIsMine =
        myId != null && _selectedTeam!.memberIds.contains(myId);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(FlapRadii.tile),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeamLogoButton(
                teamId: _selectedTeam!.id,
                teamName: _selectedTeam!.name,
                logoUrl: _selectedTeam!.logoUrl,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedTeam!.name,
                      style: FlapText.sora(
                        color: FlapColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedTeam!.memberIds.length} ${tr('il_afc0d772a2')}',
                      style: FlapText.sora(color: FlapColors.muted),
                    ),
                    if (!hostIsMine) ...[
                      const SizedBox(height: 4),
                      Text(
                        tr('il_5d5f05a24c'),
                        style: FlapText.sora(
                          color: FlapColors.muted2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('remove'),
                onPressed: () {
                  setState(() {
                    _selectedTeam = null;
                    _selectedRoster.clear();
                    _teamMemberNames.clear();
                  });
                },
                icon: const Icon(Icons.close_rounded, color: FlapColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hostIsMine) ...[
            Text(
              tr(
                'il_39635064a3',
                args: [
                  '${_selectedRoster.length}',
                  '$rosterLimit',
                ],
              ),
              style: FlapText.sora(
                color: FlapColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTeam!.memberIds.map((id) {
                final name = _teamMemberNames[id] ?? tr('player');
                final selected = _selectedRoster.contains(id);
                final disabled =
                    !selected && _selectedRoster.length >= rosterLimit;
                return GestureDetector(
                  onTap: disabled ? null : () => _toggleRosterMember(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? FlapColors.green.withOpacity(0.16)
                          : FlapColors.surface2,
                      borderRadius: BorderRadius.circular(FlapRadii.chip),
                      border: Border.all(
                        color: selected
                            ? FlapColors.green.withOpacity(0.55)
                            : FlapColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check_rounded,
                              size: 14, color: FlapColors.greenBright),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          name,
                          style: FlapText.sora(
                            fontSize: 13,
                            color: disabled
                                ? FlapColors.muted2
                                : selected
                                    ? FlapColors.greenBright
                                    : FlapColors.text,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlapColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FlapColors.border),
              ),
              child: Text(
                tr('il_42a057437b'),
                style: FlapText.sora(color: FlapColors.muted, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                tr('il_ecbd71fddb'),
                style: FlapText.sora(
                  color: FlapColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _ghostButton(
                icon: Icons.search_rounded,
                label: _opponentTeam == null
                    ? tr('il_7ec0bce7a1')
                    : tr('il_1f6c4a2d9e'),
                onTap: _openOpponentTeamSearchPage,
              ),
            ],
          ),
          if (_opponentTeam != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr('il_4d80ab83ac', args: [_opponentTeam!.name]),
                style: FlapText.sora(color: FlapColors.text),
              ),
              subtitle: Text(
                '${_opponentTeam!.memberIds.length} ${tr('il_afc0d772a2')}',
                style: FlapText.sora(color: FlapColors.muted, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.clear_rounded, color: FlapColors.muted),
                onPressed: () => setState(() => _opponentTeam = null),
              ),
            ),
        ],
      ),
    );
  }

  MatchLevel _getMatchLevel(String level) {
    if (level == tr('beginner')) return MatchLevel.beginner;
    if (level == tr('intermediate')) return MatchLevel.intermediate;
    if (level == tr('advanced')) return MatchLevel.advanced;
    if (level == tr('professional')) return MatchLevel.professional;
    return MatchLevel.intermediate;
  }

  Future<List<Map<String, dynamic>>> _loadMyFriends() async {
    try {
      final me = AppAuth.currentUser;
      if (me == null) return [];
      final rows = await _sb
          .from('friendships')
          .select('friend_user_id')
          .eq('user_id', me.id);
      final ids = (rows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['friend_user_id'].toString())
          .where((id) => id.isNotEmpty)
          .take(50)
          .toList();
      if (ids.isEmpty) return [];
      final profiles = await _sb
          .from('profiles')
          .select('id, display_name, avatar_url, city')
          .inFilter('id', ids);
      final result = (profiles as List<dynamic>)
          .map((raw) {
            final data = raw as Map<String, dynamic>;
            return <String, dynamic>{
              'id': data['id'],
              'displayName': data['display_name'],
              'avatarUrl': data['avatar_url'],
              'city': data['city'],
            };
          })
          .toList();
      result.sort((a, b) => (a['displayName'] ?? a['name'] ?? '')
          .toString()
          .compareTo((b['displayName'] ?? b['name'] ?? '').toString()));
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> _openInviteSearchPage() async {
    final selected = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) => MatchInviteSearchScreen(
          selectionOnly: true,
          initialSelectedUserIds: _selectedInviteFriendIds.toList(),
          excludedUserIds: const <String>[],
        ),
      ),
    );
    if (!mounted || selected == null) return;

    setState(() {
      _selectedInviteFriendIds
        ..clear()
        ..addAll(selected
            .map((e) => (e['id'] ?? '').toString())
            .where((id) => id.isNotEmpty));
      _selectedInviteUsers
        ..clear()
        ..addEntries(
          selected.map((e) {
            final id = (e['id'] ?? '').toString();
            return MapEntry(id, <String, dynamic>{
              'id': id,
              'displayName': e['display_name'],
              'avatarUrl': e['avatar_url'],
              'city': e['city'],
              'email': e['email'],
            });
          }).where((entry) => entry.key.isNotEmpty),
        );
    });
  }

  Future<void> _loadMyTeams() async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    try {
      final teams = await _teamsRepo.fetchUserTeams(currentUser.id);
      AppTeam? team = teams.isNotEmpty ? teams.first : null;
      Map<String, String> names = {};
      if (team != null) {
        names = await _fetchMemberNames(team.memberIds);
      }
      if (!mounted) return;
      setState(() {
        _myTeams = teams;
        _selectedTeam = team;
        _teamMemberNames = names;
        _selectedRoster = team != null
            ? team.memberIds.take((_selectedPlayers / 2).ceil()).toList()
            : [];
        _loadingTeams = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTeams = false);
    }
  }

  Future<void> _openOpponentTeamSearchPage() async {
    final selected = await Navigator.of(context).push<AppTeam>(
      MaterialPageRoute(
        builder: (_) => TeamInviteSearchScreen(
          initialSelectedTeam: _opponentTeam,
          excludedTeamId: _selectedTeam?.id,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _opponentTeam = selected);
  }

  Future<void> _showMatchCreatedDialog(
    String matchId,
    String matchTitle,
    String organizerName, {
    required bool allowIndividualInvites,
  }) async {
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlapColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlapRadii.card),
        ),
        title: Text(
          tr('il_283da721cc'),
          style: FlapText.sora(
              color: FlapColors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          tr('il_e985e12c90'),
          style: FlapText.sora(color: FlapColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'done'),
            child: Text(
              tr('il_11a6767d56'),
              style: FlapText.sora(color: FlapColors.muted),
            ),
          ),
          if (allowIndividualInvites)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FlapColors.green,
                foregroundColor: FlapColors.onGreen,
              ),
              onPressed: () => Navigator.pop(context, 'invite'),
              child: Text(tr('il_146ee72e30')),
            ),
        ],
      ),
    );

    if (action == 'invite') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MatchInviteSearchScreen(
            matchId: matchId,
            matchTitle: matchTitle,
            organizerName: organizerName,
          ),
        ),
      );
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_49c3255be3')),
        ),
      );
    }
  }

  Future<Map<String, String>> _fetchMemberNames(List<String> ids) async {
    if (ids.isEmpty) return <String, String>{};
    final map = <String, String>{};
    try {
      final rows = await _sb
          .from('profiles')
          .select('id,display_name,email')
          .inFilter('id', ids);
      for (final row in rows) {
        final id = (row['id'] ?? '').toString();
        if (id.isEmpty) continue;
        map[id] = (row['display_name'] ??
                row['email']?.toString().split('@').first ??
                tr('player'))
            .toString();
      }
    } catch (_) {}
    for (final id in ids) {
      map.putIfAbsent(id, () => tr('player'));
    }
    return map;
  }

  void _onSelectTeam(AppTeam? team) async {
    if (team == null) return;
    setState(() => _loadingTeams = true);
    final names = await _fetchMemberNames(team.memberIds);
    final myId = AppAuth.currentUserId;
    final isMine = myId != null && team.memberIds.contains(myId);
    final limit = (_selectedPlayers / 2).ceil();
    if (!mounted) return;
    setState(() {
      _selectedTeam = team;
      _teamMemberNames = names;
      _selectedRoster =
          isMine ? team.memberIds.take(limit).toList() : <String>[];
      _loadingTeams = false;
    });
  }

  void _toggleRosterMember(String id) {
    final limit = (_selectedPlayers / 2).ceil();
    setState(() {
      if (_selectedRoster.contains(id)) {
        _selectedRoster.remove(id);
      } else if (_selectedRoster.length < limit) {
        _selectedRoster.add(id);
      }
    });
  }

  void _ensureRosterLimit() {
    final limit = (_selectedPlayers / 2).ceil();
    if (_selectedRoster.length > limit) {
      _selectedRoster = _selectedRoster.take(limit).toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _friendsScrollController.dispose();
    super.dispose();
  }
}
