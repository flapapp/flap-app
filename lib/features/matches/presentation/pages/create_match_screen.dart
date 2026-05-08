import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
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
  int _numberOfTeams = 2; // 2, 3 or 4 teams
  final Set<String> _selectedInviteFriendIds = <String>{};
  final Map<String, Map<String, dynamic>> _selectedInviteUsers =
      <String, Map<String, dynamic>>{};
  
  List<String> get _levels =>
      [tr('beginner'), tr('intermediate'), tr('advanced'), tr('professional')];
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
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: Text(tr('create_match'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            // Match title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: tr('il_40e6c88126'),
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4caf50)),
                ),
              ),
              style: TextStyle(color: Colors.white),
              validator: (value) {
                if (value?.isEmpty ?? true) return tr('il_23245bd9a6');
                return null;
              },
            ),
            SizedBox(height: 20),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: tr('il_61c1c67c7f'),
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4caf50)),
                ),
              ),
              style: TextStyle(color: Colors.white),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            
            // Date and time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: Color(0xFF4caf50),
                                surface: Color(0xFF1a1a2e),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('il_c218c8b08e'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: Color(0xFF4caf50),
                                surface: Color(0xFF1a1a2e),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setState(() => _selectedTime = time);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('il_f255eef12c'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // Location
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: tr('il_692d4cc700'),
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4caf50)),
                ),
              ),
              style: TextStyle(color: Colors.white),
              validator: (value) {
                if (value?.isEmpty ?? true) return tr('il_de5898b9bb');
                return null;
              },
            ),
            SizedBox(height: 20),
            
            // City and level
            Row(
              children: [
                Expanded(
                  child: CityAutocompleteField(
                    controller: _cityController,
                    label: tr('il_4b59236336'),
                    requiredField: true,
                    style: const TextStyle(color: Colors.white),
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4caf50)),
                    ),
                    prefixIcon: const Icon(Icons.location_city, color: Colors.white70),
                    onSelected: (value) => setState(() => _selectedCity = value.trim()),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedLevel,
                    decoration: InputDecoration(
                      labelText: tr('il_1213d3201a'),
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF4caf50)),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    dropdownColor: Color(0xFF1a1a2e),
                    items: _levels.map((level) => 
                      DropdownMenuItem(value: level, child: Text(level))
                    ).toList(),
                    onChanged: (value) {
                      setState(() => _selectedLevel = value!);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // Player count and price
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedPlayers,
                    decoration: InputDecoration(
                      labelText: tr('il_62a929fea8'),
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF4caf50)),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    dropdownColor: Color(0xFF1a1a2e),
                    items: _playerOptions.map((players) => 
                      DropdownMenuItem(
                        value: players, 
                        child: Text(
                          tr('il_460cbf0720', namedArgs: {'players': '$players'}),
                        ),
                      )
                    ).toList(),
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
                SizedBox(width: 15),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: tr('il_6d595710b8'),
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF4caf50)),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() => _cost = double.tryParse(value) ?? 0.0);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // Settings
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 640;
                final toggles = [
                  _buildSettingToggle(
                    title: tr('il_ace59f5c4f'),
                    subtitle: tr('il_2989176c3a'),
                    value: _autoBalance,
                    onChanged: (value) {
                      setState(() => _autoBalance = value);
                    },
                  ),
                  _buildSettingToggle(
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
                  children: [
                    Expanded(child: toggles[0]),
                    const SizedBox(width: 12),
                    Expanded(child: toggles[1]),
                  ],
                );
              },
            ),
            
            // Number of teams
            if (_autoBalance) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('il_9be39530da'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [2, 3, 4].map((teamOption) {
                        final isSelected = _numberOfTeams == teamOption;
                        return GestureDetector(
                          onTap: () => setState(() => _numberOfTeams = teamOption),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4caf50)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4caf50)
                                    : Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                teamOption.toString(),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(
                tr('il_5084b91728'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                tr('il_a94d1ecc4e'),
                style: const TextStyle(color: Colors.white70),
              ),
              value: _teamMode,
              activeThumbColor: const Color(0xFF4caf50),
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
            if (_teamMode) _buildTeamModeSection(),

            const SizedBox(height: 20),
            if (!_teamMode) ...[
              Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr('il_2614b42d84'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _openInviteSearchPage,
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: Text(
                      tr('il_146ee72e30'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4caf50)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_selectedInviteFriendIds.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: _selectedInviteFriendIds.map((id) {
                      final user = _selectedInviteUsers[id] ?? const <String, dynamic>{};
                      final name = (user['displayName'] ??
                              user['display_name'] ??
                              user['email']?.toString().split('@').first ??
                              tr('player'))
                          .toString();
                      final avatar = (user['avatarUrl'] ?? user['avatar_url'] ?? '').toString();
                      final city = (user['city'] ?? '').toString();
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        leading: PlayerAvatarButton(
                          userId: id,
                          displayName: name,
                          avatarUrl: avatar,
                          size: 34,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: city.isEmpty
                            ? null
                            : Text(
                                localizeCity(city),
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                        trailing: IconButton(
                          tooltip: tr('remove'),
                          icon: const Icon(Icons.close, color: Colors.redAccent),
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
                const SizedBox(height: 10),
              ],
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadMyFriends(),
                builder: (context, snapshot) {
                  final friends = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (friends.isEmpty) {
                    return Text(
                      tr('il_3f6a83aa65'),
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
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
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: friends.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, i) {
                            final f = friends[i];
                            final id = f['id'] as String;
                            final name = (f['displayName'] ??
                                    f['name'] ??
                                    tr('il_b512d97e7c'))
                                .toString();
                            final photoUrl =
                                (f['avatarUrl'] ?? f['photoUrl'] ?? '').toString();
                            final position =
                                (f['position'] ?? f['role'] ?? '').toString();
                            final rating = ((f['rating'] ??
                                        f['averageRating'] ??
                                        0) as num)
                                    .toDouble();
                            final selected =
                                _selectedInviteFriendIds.contains(id);

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              leading: PlayerAvatarButton(
                                userId: id,
                                displayName: name,
                                avatarUrl: photoUrl,
                                size: 36,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  if (position.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        position,
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 12),
                                      ),
                                    ),
                                  if (position.isNotEmpty)
                                    const SizedBox(width: 8),
                                  const Icon(Icons.star,
                                      size: 14, color: Color(0xFFFFD700)),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating > 0 ? rating.toStringAsFixed(1) : '-',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Checkbox(
                                value: selected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedInviteFriendIds.add(id);
                                      _selectedInviteUsers[id] = {
                                        'id': id,
                                        'displayName': name,
                                        'avatarUrl': photoUrl,
                                        'city': '',
                                      };
                                    } else {
                                      _selectedInviteFriendIds.remove(id);
                                      _selectedInviteUsers.remove(id);
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF4caf50),
                                checkColor: Colors.white,
                              ),
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selectedInviteFriendIds.remove(id);
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups, color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr('il_361b9541bf'),
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 20),
            
            // Create button
            ElevatedButton(
              onPressed: _isCreating ? null : _createMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4caf50),
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      tr('create_match'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createMatch() async {
    if (_isCreating) return;
    if (!_formKey.currentState!.validate()) return;
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
    backgroundColor: Colors.red,
  ),
);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Widget _buildSettingToggle({
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
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? const Color(0xFF4caf50) : Colors.white.withOpacity(0.12),
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? const Color(0xFF4caf50) : Colors.white.withOpacity(0.15),
              ),
              child: Icon(
                value ? Icons.check : Icons.circle_outlined,
                color: Colors.white,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF4caf50),
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
      backgroundColor: const Color(0xFF0F1A2B),
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
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: tr('il_c81e115cc3'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4caf50)),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white70),
                        onPressed: () => runSearch(setSheetState),
                      ),
                    ),
                    onSubmitted: (_) => runSearch(setSheetState),
                  ),
                  const SizedBox(height: 16),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(),
                    )
                  else if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        tr('il_9598782e39'),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white12),
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
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              '${team.memberIds.length} ${tr('il_afc0d772a2')}',
                              style: const TextStyle(color: Colors.white54),
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
        child: LinearProgressIndicator(),
      );
    }
    if (_selectedTeam == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('il_6aaa94a1ae'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('il_de51695051'),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTeamSearchSheet(forHost: true),
                icon: const Icon(Icons.search, color: Colors.white),
                label: Text(
                  tr('il_95c42e9726'),
                  style: const TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4caf50)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedTeam!.memberIds.length} ${tr('il_afc0d772a2')}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (!hostIsMine) ...[
                      const SizedBox(height: 4),
                      Text(
                        tr('il_5d5f05a24c'),
                        style: const TextStyle(
                          color: Colors.white54,
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
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          // const SizedBox(height: 10),
          // Align(
          //   alignment: Alignment.centerRight,
          //   child: Wrap(
          //     spacing: 8,
          //     children: [
          //       TextButton.icon(
          //         onPressed: () => _openTeamSearchSheet(forHost: true),
          //         icon: const Icon(Icons.swap_horiz, color: Colors.white70),
          //         label: Text(
          //           tr('il_c0bf75bd78'),
          //           style: const TextStyle(color: Colors.white70),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
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
              style: const TextStyle(
                color: Colors.white,
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
                return ChoiceChip(
                  selected: selected,
                  label: Text(name),
                  onSelected:
                      disabled ? null : (value) => _toggleRosterMember(id),
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                tr('il_42a057437b'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                tr('il_ecbd71fddb'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _openOpponentTeamSearchPage,
                icon: const Icon(Icons.search, color: Colors.white),
                label: Text(
                  _opponentTeam == null
                      ? tr('il_7ec0bce7a1')
                      : tr('il_1f6c4a2d9e'),
                  style: const TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4caf50)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          if (_opponentTeam != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr('il_4d80ab83ac', args: [_opponentTeam!.name]),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${_opponentTeam!.memberIds.length} ${tr('il_afc0d772a2')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white70),
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
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          tr('il_283da721cc'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          tr('il_e985e12c90'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'done'),
            child: Text(tr('il_11a6767d56')),
          ),
          if (allowIndividualInvites)
            ElevatedButton(
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