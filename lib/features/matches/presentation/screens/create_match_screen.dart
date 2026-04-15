import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/features/auth/domain/entities/user_profile_snapshot.dart';
import 'package:flap_app/features/friends/domain/repositories/friends_repository.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flap_app/models/match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/features/matches/domain/repositories/matches_repository.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/features/teams/domain/repositories/teams_repository.dart';
import 'package:flap_app/models/notification.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'package:flap_app/widgets/team_logo_button.dart';
import 'package:flap_app/widgets/city_autocomplete_field.dart';
import 'package:flap_app/core/app_auth_context.dart';

@RoutePage()
class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  CreateMatchScreenState createState() => CreateMatchScreenState();
}

class CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedCity = I18n.t('kyiv');
  String _selectedLevel = I18n.inline('Середній', 'Intermediate');
  int _selectedPlayers = 10;
  double _cost = 0.0;
  bool _autoBalance = true;
  bool _isPrivate = false;
  int _numberOfTeams = 2; // 2, 3 or 4 teams
  final Set<String> _selectedInviteFriendIds = <String>{};
  
  List<String> get _cities => [I18n.t('kyiv'), I18n.t('kharkiv'), I18n.t('odesa'), I18n.t('dnipro'), I18n.t('lviv')];
  List<String> get _levels => [I18n.t('beginner'), I18n.inline('Середній', 'Intermediate'), I18n.inline('Високий', 'Advanced'), I18n.t('professional')];
  final List<int> _playerOptions = [4, 6, 8, 10, 12, 14, 16, 18, 20, 22];
  final ScrollController _friendsScrollController = ScrollController();
  bool _isCreating = false;
  bool _teamMode = false;
  bool _loadingTeams = true;
  List<AppTeam> _myTeams = [];
  AppTeam? _selectedTeam;
  List<String> _selectedRoster = [];
  Map<String, String> _teamMemberNames = {};
  AppTeam? _opponentTeam;
  final TextEditingController _opponentSearchCtrl = TextEditingController();
  List<AppTeam> _opponentResults = [];
  bool _opponentSearching = false;

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
        title: Text(I18n.t('create_match'), style: const TextStyle(color: Colors.white)),
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
            // Назва матчу
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: I18n.inline('Назва матчу *', 'Match name *'),
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
                if (value?.isEmpty ?? true) return I18n.inline('Введіть назву матчу', 'Enter match name');
                return null;
              },
            ),
            SizedBox(height: 20),
            
            // Опис
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: I18n.inline('Опис матчу', 'Match description'),
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
            
            // Дата та час
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
                          Text(I18n.inline('Дата *', 'Date *'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                          Text(I18n.inline('Час *', 'Time *'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
            
            // Локація
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: I18n.inline('Локація *', 'Location *'),
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
                if (value?.isEmpty ?? true) return I18n.inline('Введіть локацію', 'Enter location');
                return null;
              },
            ),
            SizedBox(height: 20),
            
            // Місто та рівень
            Row(
              children: [
                Expanded(
                  child: CityAutocompleteField(
                    controller: _cityController,
                    label: I18n.inline('Місто *', 'City *'),
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
                      labelText: I18n.inline('Рівень *', 'Level *'),
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
            
            // Кількість гравців та вартість
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedPlayers,
                    decoration: InputDecoration(
                      labelText: I18n.inline('Гравці *', 'Players *'),
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
                        child: Text(I18n.inline('$players гравців', '$players players'))
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
                      labelText: I18n.inline('Вартість (грн)', 'Cost (UAH)'),
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
            
            // Налаштування
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 640;
                final toggles = [
                  _buildSettingToggle(
                    title: I18n.inline('Автобаланс', 'Auto balance'),
                    subtitle: I18n.inline('Система підбере склади', 'System balances teams'),
                    value: _autoBalance,
                    onChanged: (value) {
                      setState(() => _autoBalance = value);
                    },
                  ),
                  _buildSettingToggle(
                    title: I18n.inline('Приватний матч', 'Private match'),
                    subtitle: I18n.inline('Бачать лише запрошені', 'Visible to invited only'),
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
            
            // Вибір кількості команд
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
                    Text(I18n.inline('Кількість команд:', 'Number of teams:'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
                I18n.inline('Матч між командами', 'Team vs team'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                I18n.inline('Виберіть свою команду та оберіть склад',
                    'Pick your team and roster'),
                style: const TextStyle(color: Colors.white70),
              ),
              value: _teamMode,
              activeThumbColor: const Color(0xFF4caf50),
              onChanged: (value) {
                setState(() {
                  _teamMode = value;
                  if (value) {
                    _autoBalance = false;
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
                    I18n.inline('Запросити друзів', 'Invite friends'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadMyFriends(),
                builder: (context, snapshot) {
                  final friends = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (friends.isEmpty) {
                    return Text(
                      I18n.inline('Немає друзів для запрошення',
                          'No friends to invite'),
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
                                    I18n.inline('Користувач', 'User'))
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
                                    } else {
                                      _selectedInviteFriendIds.remove(id);
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
                                  } else {
                                    _selectedInviteFriendIds.add(id);
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
                        I18n.inline(
                            'Запрошення друзів вимкнено для командних матчів. Капітани додають гравців зі складу команди.',
                            'Inviting individual friends is disabled in team mode. Captains manage rosters inside their teams.'),
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 20),
            
            // Кнопка створення
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
                      I18n.t('create_match'),
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
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) return;

      final profileRepo = context.read<UserProfileRepository>();
      final matchesRepo = context.read<MatchesRepository>();
      final teamsRepo = context.read<TeamsRepository>();
      final profile = await profileRepo.loadProfile(currentUser.id);
      final emailPrefix = currentUser.email?.split('@').first;
      final resolvedOrganizerName =
          (currentUser.displayName?.trim().isNotEmpty == true)
              ? currentUser.displayName!.trim()
              : (profile?.resolveDisplayName().trim().isNotEmpty == true
                  ? profile!.resolveDisplayName().trim()
                  : emailPrefix ??
                      I18n.inline('Невідомий', 'Unknown'));
      
      var participants = <String>[currentUser.id];
      var currentPlayers = 1;
      var autoBalance = _autoBalance;
      var isTeamMatch = false;
      final Map<String, List<String>> teamRosters = {};
      final Map<String, Map<String, String>> teamRosterStatus = {};
      Team? teamAData;
      Team? teamBData;
      String? teamAId;
      String? teamBId;
      String? teamAStatus;
      String? teamBStatus;
      var hostIsMyTeam = false;

      if (_teamMode) {
        if (_selectedTeam == null) {
          throw Exception(I18n.inline('Оберіть команду', 'Select a team'));
        }
        hostIsMyTeam =
            _selectedTeam!.memberIds.contains(currentUser.id);
        if (hostIsMyTeam && _selectedRoster.isEmpty) {
          throw Exception(I18n.inline(
              'Оберіть склад команди', 'Choose at least one player'));
        }
        if (!hostIsMyTeam) {
          participants = <String>[];
          currentPlayers = 0;
        } else {
          participants = List<String>.from(_selectedRoster);
          currentPlayers = participants.length;
        }
        autoBalance = false;
        isTeamMatch = true;
        teamAId = _selectedTeam!.id;
        teamAStatus = 'pending';
        teamRosters['teamA'] =
            hostIsMyTeam ? List<String>.from(_selectedRoster) : <String>[];
        if (hostIsMyTeam) {
          teamRosterStatus['teamA'] = {
            for (final playerId in _selectedRoster) playerId: 'pending',
          };
        }
        if (_opponentTeam != null) {
          teamBId = _opponentTeam!.id;
          teamBStatus = 'pending';
          teamRosters['teamB'] = [];
          teamBData = Team(
            name: _opponentTeam!.name,
            playerIds: const [],
          );
        }
        teamAData = Team(
          name: _selectedTeam!.name,
          playerIds: hostIsMyTeam ? _selectedRoster : const [],
        );
      }

      _selectedCity = _cityController.text.trim();
      if (_selectedCity.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.inline('Оберіть місто зі списку', 'Select city from suggestions'))),
        );
        return;
      }

      final match = Match(
        id: '', // Assigned by MatchesRepository.createMatch
        title: _titleController.text,
        description: _descriptionController.text,
        organizerId: currentUser.id,
        organizerName: resolvedOrganizerName,
        date: _selectedDate,
        time: '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        location: _locationController.text,
        city: _selectedCity,
        currentPlayers: currentPlayers,
        maxPlayers: _selectedPlayers,
        participants: participants,
        level: _getMatchLevel(_selectedLevel),
        cost: _cost,
        autoBalance: autoBalance,
        isPrivate: _isPrivate,
        invitedFriends: _selectedInviteFriendIds.toList(),
        isTeamMatch: isTeamMatch,
        teamAId: teamAId,
        teamBId: teamBId,
        teamAStatus: teamAStatus,
        teamBStatus: teamBStatus,
        teamRosters: teamRosters,
        teamRosterStatus: teamRosterStatus,
        teamA: teamAData,
        teamB: teamBData,
        status: MatchStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final matchId = await matchesRepo.createMatch(match);

      // Надіслати інвайти вибраним друзям (push + in-app)
      if (_selectedInviteFriendIds.isNotEmpty) {
        try {
          final title = _titleController.text.trim();
          final notifService = NotificationService();
          for (final uid in _selectedInviteFriendIds) {
            await notifService.sendNotification(AppNotification(
              id: '',
              userId: uid,
              type: NotificationType.matchInvite,
              title: I18n.inline('Запрошення на матч', 'Match invitation'),
              message: I18n.inline(
                '$resolvedOrganizerName запросив вас на матч "$title"',
                '$resolvedOrganizerName invited you to the match "$title"',
              ),
              data: {
                'matchId': matchId, 
                'matchTitle': title,
                'city': _selectedCity,
                'date': _selectedDate.toIso8601String(),
                'time': '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                'action': 'open_match',
              },
              createdAt: DateTime.now(),
            ));
          }
        } catch (_) {}
      }
      
      if (_teamMode) {
        if (_selectedTeam != null && !hostIsMyTeam) {
          await teamsRepo.sendMatchRequest(
            teamId: _selectedTeam!.id,
            opponentTeamId: _opponentTeam?.id ?? '',
            opponentName:
                _opponentTeam?.name ?? I18n.inline('Суперник', 'Opponent'),
            matchId: matchId,
            proposedRoster: hostIsMyTeam ? _selectedRoster : const [],
          );
        }
        if (_opponentTeam != null) {
          await teamsRepo.sendMatchRequest(
            teamId: _opponentTeam!.id,
            opponentTeamId: _selectedTeam!.id,
            opponentName: _selectedTeam!.name,
            matchId: matchId,
            proposedRoster: const [],
          );
        }
        if (hostIsMyTeam) {
          await _sendRosterInvites(
            matchId: matchId,
            teamKey: 'teamA',
            teamName: _selectedTeam!.name,
            playerIds: _selectedRoster,
          );
        }
      }

      if (!mounted) return;
      await _showMatchCreatedDialog(
        matchId,
        _titleController.text.trim(),
        resolvedOrganizerName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(I18n.inline('Помилка створення: $e', 'Failed to create match: $e')),
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

  Future<void> _sendRosterInvites({
    required String matchId,
    required String teamKey,
    required String teamName,
    required List<String> playerIds,
  }) async {
    if (playerIds.isEmpty) return;
    final notifService = NotificationService();
    for (final playerId in playerIds) {
      await notifService.sendTeamRosterInvite(
        toUserId: playerId,
        matchId: matchId,
        teamName: teamName,
        teamKey: teamKey,
      );
    }
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
            final found = await ctx.read<TeamsRepository>().searchTeams(query, limit: 15);
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
                      labelText: I18n.inline('Пошук команди', 'Search team'),
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
                        I18n.inline('Введіть назву команди для пошуку.',
                            'Type a team name to search.'),
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
                            title: Text(team.name,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              '${team.memberIds.length} ${I18n.inline('гравців', 'players')}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              if (forHost) {
                                _onSelectTeam(team);
                              } else {
                                setState(() {
                                  _opponentTeam = team;
                                  _opponentResults = [];
                                });
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
              I18n.inline(
                  'Обрати команду організатора', 'Pick an organizer team'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              I18n.inline(
                  'Натисніть, щоб знайти існуючу команду, навіть якщо вона не ваша.',
                  'Tap to search any existing team, even if it is not yours.'),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTeamSearchSheet(forHost: true),
                icon: const Icon(Icons.search, color: Colors.white),
                label: Text(
                  I18n.inline('Знайти команду', 'Find a team'),
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
    final myId = AppAuthContext.userId;
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
                      '${_selectedTeam!.memberIds.length} ${I18n.inline('гравців', 'players')}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (!hostIsMine) ...[
                      const SizedBox(height: 4),
                      Text(
                        I18n.inline(
                            'Цю команду запросимо підтвердити склад',
                            'This club will confirm line-up themselves'),
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
                tooltip: I18n.t('remove'),
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _openTeamSearchSheet(forHost: true),
                  icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                  label: Text(
                    I18n.inline('Змінити', 'Change'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (hostIsMine) ...[
            Text(
              I18n.inline('Склад (${_selectedRoster.length}/$rosterLimit)',
                  'Roster (${_selectedRoster.length}/$rosterLimit)'),
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
                final name = _teamMemberNames[id] ?? I18n.t('player');
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
                I18n.inline(
                    'Капітан команди підтвердить участь та заявить склад у своїй програмі.',
                    'Team captain will accept the invite and pick the roster on their side.'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            I18n.inline('Запросити суперника', 'Invite opponent team'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _opponentSearchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: I18n.inline('Пошук команди', 'Search team'),
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4caf50)),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.white70),
                onPressed: _searchOpponentTeams,
              ),
            ),
          ),
          if (_opponentTeam != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                I18n.inline(
                    'Обрана команда: ${_opponentTeam!.name}',
                    'Selected team: ${_opponentTeam!.name}'),
                style: const TextStyle(color: Colors.white),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white70),
                onPressed: () => setState(() => _opponentTeam = null),
              ),
            ),
          if (_opponentSearching)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            )
          else if (_opponentResults.isNotEmpty)
            Column(
              children: _opponentResults.map((team) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    team.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${team.memberIds.length} ${I18n.inline('гравців', 'players')}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    setState(() {
                      _opponentTeam = team;
                      _opponentResults = [];
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  MatchLevel _getMatchLevel(String level) {
    switch (level) {
      case 'Початковий': return MatchLevel.beginner;
      case 'Середній': return MatchLevel.intermediate;
      case 'Високий': return MatchLevel.advanced;
      case 'Професійний': return MatchLevel.professional;
      default: return MatchLevel.intermediate;
    }
  }

  Future<List<Map<String, dynamic>>> _loadMyFriends() async {
    try {
      final me = AppAuthContext.currentUser;
      if (me == null) return [];
      final friendsRepo = context.read<FriendsRepository>();
      final friends = await friendsRepo.getUserFriends(me.id);
      return friends
          .take(50)
          .map(
            (f) => <String, dynamic>{
              'id': f.userId,
              'displayName': f.name,
              'name': f.name,
              'avatarUrl': f.avatar,
              'photoUrl': f.avatar,
              'position': f.position,
              'rating': f.rating,
              'averageRating': f.rating,
              'city': f.city,
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadMyTeams() async {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;
    try {
      final teams =
          await context.read<TeamsRepository>().fetchUserTeams(currentUser.id);
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

  Future<List<Map<String, dynamic>>> _loadInviteCandidates() async {
    try {
      final me = AppAuthContext.currentUser;
      if (me == null) return [];
      final rows = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'id, display_name, first_name, last_name, email, avatar_url, rating, city, position',
          )
          .neq('id', me.id)
          .limit(100);
      final result = <Map<String, dynamic>>[];
      for (final raw in (rows as List)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final snap = UserProfileSnapshot.fromSupabaseRow(row);
        final label = snap.resolveDisplayName().isNotEmpty
            ? snap.resolveDisplayName()
            : I18n.inline('Користувач', 'User');
        result.add({
          'id': id,
          'displayName': label,
          'name': row['first_name'] ?? row['name'],
          'city': (row['city'] ?? '').toString(),
          'rating': (row['rating'] as num?)?.toDouble() ?? 0.0,
          'avatarUrl': (row['avatar_url'] ?? '').toString(),
          'avatar': row['avatar_url'],
          'position': (row['position'] ?? '').toString(),
        });
      }
      result.sort((a, b) {
        final aName = (a['displayName'] ?? a['name'] ?? '').toString();
        final bName = (b['displayName'] ?? b['name'] ?? '').toString();
        return aName.compareTo(bName);
      });
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> _showInviteParticipantsDialog(
    String matchId,
    String matchTitle,
    String organizerName,
  ) async {
    final candidates = await _loadInviteCandidates();
    if (!mounted) return;

    final searchController = TextEditingController();
    String selectedCity = I18n.t('all_cities');
    final selectedIds = <String>{};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = candidates.where((user) {
            final name = (user['displayName'] ?? user['name'] ?? '').toString().toLowerCase();
            final city = (user['city'] ?? '').toString();
            final matchesQuery = query.isEmpty || name.contains(query);
            final matchesCity = selectedCity == I18n.t('all_cities') || city == selectedCity;
            return matchesQuery && matchesCity;
          }).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: Text(
              I18n.inline('Запросити учасників', 'Invite participants'),
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: I18n.inline('Пошук по імені', 'Search by name'),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCity,
                    dropdownColor: const Color(0xFF1a1a2e),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: I18n.inline('Місто', 'City'),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    items: _cities
                        .map((city) => DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            ))
                        .toList()
                      ..insert(
                        0,
                        DropdownMenuItem<String>(
                          value: I18n.t('all_cities'),
                          child: Text(I18n.t('all_cities')),
                        ),
                      ),
                    onChanged: (value) {
                      selectedCity = value ?? I18n.t('all_cities');
                      setStateDialog(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              I18n.inline('Нікого не знайдено', 'No users found'),
                              style: const TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final user = filtered[index];
                              final id = user['id'] as String;
                              final name = (user['displayName'] ?? user['name'] ?? I18n.inline('Користувач', 'User')).toString();
                              final city = (user['city'] ?? '').toString();
                              final rating = ((user['rating'] ?? 0) as num).toDouble();
                              final avatar = (user['avatarUrl'] ?? user['avatar'] ?? '').toString();
                              final selected = selectedIds.contains(id);

                              return ListTile(
                                onTap: () {
                                  setStateDialog(() {
                                    if (selected) {
                                      selectedIds.remove(id);
                                    } else {
                                      selectedIds.add(id);
                                    }
                                  });
                                },
                                leading: PlayerAvatarButton(
                                  userId: id,
                                  displayName: name,
                                  avatarUrl: avatar,
                                  size: 34,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '⭐ ${rating.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  city,
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                trailing: Checkbox(
                                  value: selected,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      if (value == true) {
                                        selectedIds.add(id);
                                      } else {
                                        selectedIds.remove(id);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(I18n.t('cancel')),
              ),
              ElevatedButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () async {
                        final matchesRepo = ctx.read<MatchesRepository>();
                        final notificationService = NotificationService();
                        for (final uid in selectedIds) {
                          await notificationService.sendNotification(
                            AppNotification(
                              id: '',
                              userId: uid,
                              type: NotificationType.matchInvite,
                              title: I18n.inline('Запрошення на матч', 'Match invitation'),
                              message: I18n.inline(
                                '$organizerName запросив вас на матч "$matchTitle"',
                                '$organizerName invited you to the match "$matchTitle"',
                              ),
                              data: {
                                'matchId': matchId,
                                'matchTitle': matchTitle,
                                'action': 'open_match',
                              },
                              createdAt: DateTime.now(),
                            ),
                          );
                        }

                        if (!ctx.mounted) return;
                        final existing = await matchesRepo.fetchMatch(matchId);
                        if (existing != null) {
                          final merged = <String>{
                            ...existing.invitedFriends,
                            ...selectedIds,
                          }.toList();
                          await matchesRepo.saveMatch(
                            existing.copyWith(invitedFriends: merged),
                          );
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: Text(I18n.inline('Запросити', 'Invite')),
              ),
            ],
          );
        },
      ),
    );

    searchController.dispose();
  }

  Future<void> _showMatchCreatedDialog(
    String matchId,
    String matchTitle,
    String organizerName,
  ) async {
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          I18n.inline('Матч створено!', 'Match created!'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          I18n.inline(
            'Матч успішно створено. Можете запросити учасників прямо зараз.',
            'The match was created successfully. You can invite participants right now.',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'done'),
            child: Text(I18n.inline('Готово', 'Done')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'invite'),
            child: Text(I18n.inline('Запросити учасників', 'Invite participants')),
          ),
        ],
      ),
    );

    if (action == 'invite') {
      await _showInviteParticipantsDialog(matchId, matchTitle, organizerName);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Матч створено успішно!', 'Match created successfully!')),
        ),
      );
    }
  }

  Future<Map<String, String>> _fetchMemberNames(List<String> ids) async {
    final map = <String, String>{};
    if (ids.isEmpty) return map;
    const chunkSize = 50;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = i + chunkSize > ids.length ? ids.length : i + chunkSize;
      final chunk = ids.sublist(i, end);
      try {
        final rows = await Supabase.instance.client
            .from('user_profiles')
            .select('id, display_name, first_name, last_name, email')
            .inFilter('id', chunk);
        for (final raw in (rows as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final snap = UserProfileSnapshot.fromSupabaseRow(row);
          final label = snap.resolveDisplayName().isNotEmpty
              ? snap.resolveDisplayName()
              : I18n.t('player');
          map[id] = label;
        }
      } catch (_) {}
      for (final id in chunk) {
        map.putIfAbsent(id, () => I18n.t('player'));
      }
    }
    return map;
  }

  void _onSelectTeam(AppTeam? team) async {
    if (team == null) return;
    setState(() => _loadingTeams = true);
    final names = await _fetchMemberNames(team.memberIds);
    final myId = AppAuthContext.userId;
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

  Future<void> _searchOpponentTeams() async {
    final query = _opponentSearchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _opponentSearching = true);
    final results =
        await context.read<TeamsRepository>().searchTeams(query, limit: 5);
    if (!mounted) return;
    setState(() {
      _opponentResults =
          results.where((team) => team.id != _selectedTeam?.id).toList();
      _opponentSearching = false;
    });
  }

@override
void dispose() {
  _titleController.dispose();
  _descriptionController.dispose();
  _locationController.dispose();
  _cityController.dispose();
  _opponentSearchCtrl.dispose();
  _friendsScrollController.dispose();
  super.dispose();
}
}