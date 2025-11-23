import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/match.dart';
import '../services/match_service.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';
import '../utils/i18n.dart';

class CreateMatchScreen extends StatefulWidget {
  @override
  _CreateMatchScreenState createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
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
                  child: DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: I18n.inline('Місто *', 'City *'),
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
                    items: _cities.map((city) => 
                      DropdownMenuItem(value: city, child: Text(city))
                    ).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCity = value!);
                    },
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLevel,
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
                    value: _selectedPlayers,
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
                      setState(() => _selectedPlayers = value!);
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
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(I18n.inline('Автобаланс команд', 'Auto-balance teams'), style: const TextStyle(color: Colors.white)),
                    value: _autoBalance,
                    onChanged: (value) {
                      setState(() => _autoBalance = value!);
                    },
                    activeColor: Color(0xFF4caf50),
                    checkColor: Colors.white,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text(I18n.inline('Приватний матч', 'Private match'), style: const TextStyle(color: Colors.white)),
                    value: _isPrivate,
                    onChanged: (value) {
                      setState(() => _isPrivate = value!);
                    },
                    activeColor: Color(0xFF4caf50),
                    checkColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            // Вибір кількості команд
            if (_autoBalance) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(I18n.inline('Кількість команд:', 'Number of teams:'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [2, 3, 4].map((num) {
                        final isSelected = _numberOfTeams == num;
                        return GestureDetector(
                          onTap: () => setState(() => _numberOfTeams = num),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: isSelected ? Color(0xFF4caf50) : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Color(0xFF4caf50) : Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                num.toString(),
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

            const SizedBox(height: 20),
// Запросити друзів
Row(
  children: [
    Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
    const SizedBox(width: 8),
    Text(
      I18n.inline('Запросити друзів', 'Invite friends'),
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
        I18n.inline('Немає друзів для запрошення', 'No friends to invite'),
        style: TextStyle(color: Colors.white.withOpacity(0.75)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
        color: Colors.white.withOpacity(0.08),
      ),
      itemBuilder: (context, i) {
              final f = friends[i];
              final id = f['id'] as String;
              final name = (f['displayName'] ?? f['name'] ?? I18n.inline('Користувач', 'User')).toString();
              final photoUrl = (f['avatarUrl'] ?? f['photoUrl'] ?? '').toString();
              final position = (f['position'] ?? f['role'] ?? '').toString();
              final rating = ((f['rating'] ?? f['averageRating'] ?? 0) as num).toDouble();
              final selected = _selectedInviteFriendIds.contains(id);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF4caf50),
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                title: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    if (position.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          position,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    if (position.isNotEmpty) const SizedBox(width: 8),
                    const Icon(Icons.star, size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 2),
                    Text(
                      rating > 0 ? rating.toStringAsFixed(1) : '-',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
            SizedBox(height: 20),
            
            // Кнопка створення
            ElevatedButton(
              onPressed: _createMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4caf50),
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                I18n.t('create_match'),
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // NEW: resolve organizer name reliably
final userSnap = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .get();
final userData = userSnap.data() ?? {};
final emailPrefix = currentUser.email?.split('@').first;
final resolvedOrganizerName = (currentUser.displayName?.trim().isNotEmpty == true)
    ? currentUser.displayName!.trim()
    : (userData['displayName'] ??
       userData['authorName'] ??
       userData['name'] ??
       emailPrefix ??
       I18n.inline('Невідомий', 'Unknown')).toString();
      
      final match = Match(
        id: '', // Firestore згенерує ID
        title: _titleController.text,
        description: _descriptionController.text,
        organizerId: currentUser.uid,
        organizerName: resolvedOrganizerName,
        date: _selectedDate,
        time: '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        location: _locationController.text,
        city: _selectedCity,
        currentPlayers: 1, // Тільки організатор
        maxPlayers: _selectedPlayers,
        participants: [currentUser.uid],
        level: _getMatchLevel(_selectedLevel),
        cost: _cost,
        autoBalance: _autoBalance,
        isPrivate: _isPrivate,
        invitedFriends: _selectedInviteFriendIds.toList(),
        status: MatchStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
            final matchId = await MatchService().createMatch(match);

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
              title: 'Запрошення на матч',
              message: '$resolvedOrganizerName запросив вас на матч "$title"',
              data: {
                'matchId': matchId,  // ← ДОДАНО matchId!
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
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Матч створено успішно!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка створення: $e'), backgroundColor: Colors.red),
      );
    }
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
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return [];
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(me.uid).get();
    final ids = List<String>.from(userDoc.data()?['friends'] ?? []);
    if (ids.isEmpty) return [];
    final result = <Map<String, dynamic>>[];
    for (final id in ids.take(50)) {
      final d = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (d.exists) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = id;
        result.add(data);
      }
    }
    result.sort((a, b) => (a['displayName'] ?? a['name'] ?? '')
        .toString()
        .compareTo((b['displayName'] ?? b['name'] ?? '').toString()));
    return result;
  } catch (_) {
    return [];
  }
}

@override
void dispose() {
  _titleController.dispose();
  _descriptionController.dispose();
  _locationController.dispose();
  _friendsScrollController.dispose();
  super.dispose();
}
}