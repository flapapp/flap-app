import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
// Removed dart:io to support web build
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import '../services/notification_service.dart';
import '../services/thumbnail_service.dart';
import '../utils/i18n.dart';
import '../widgets/player_avatar_button.dart';

@RoutePage()
class ChallengeCreateScreen extends StatefulWidget {
  @override
  _ChallengeCreateScreenState createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  static const int _maxVideoBytes = 25 * 1024 * 1024;
  static const Duration _maxVideoDuration = Duration(seconds: 10);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  
  ChallengeType _selectedType = ChallengeType.goal;
  ChallengeAudience _selectedAudience = ChallengeAudience.city;
  String _selectedCity = I18n.t('kyiv_city');
  int _selectedEntryFee = 10;
  int _recruitmentHours = 24; // 1 доба за замовчуванням
  int _submissionHours = 24;
  int _votingHours = 24;
  bool _isCreating = false;
  XFile? _selectedVideoFile;
  
  final ChallengeService _challengeService = ChallengeService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _selectedInviteFriendIds = <String>{};

  final List<String> _cities = [
    I18n.t('kyiv_city'),
    I18n.t('kharkiv_city'),
    I18n.t('odesa_city'),
    I18n.t('dnipro_city'),
    I18n.t('lviv_city'),
    I18n.t('zaporizhzhia'),
    I18n.t('kryvyi_rih'),
    I18n.t('mykolaiv'),
    I18n.t('vinnytsia'),
    I18n.t('poltava'),
    I18n.t('cherkasy'),
    I18n.inline('Суми', 'Sumy'),
    I18n.inline('Хмельницький', 'Khmelnytskyi'),
    I18n.inline('Чернівці', 'Chernivtsi'),
    I18n.inline('Житомир', 'Zhytomyr'),
    I18n.inline('Тернопіль', 'Ternopil'),
    I18n.inline('Івано-Франківськ', 'Ivano-Frankivsk'),
    I18n.inline('Луцьк', 'Lutsk'),
    I18n.inline('Рівне', 'Rivne'),
    I18n.inline('Ужгород', 'Uzhhorod'),
  ];

  final List<int> _entryFees = [5, 10, 15, 20, 25];
  List<Map<String, dynamic>> get _durations => [
    {'hours': 1, 'label': I18n.inline('1 година', '1 hour')},
    {'hours': 6, 'label': I18n.inline('6 годин', '6 hours')},
    {'hours': 24, 'label': I18n.inline('1 доба', '1 day')},
    {'hours': 72, 'label': I18n.inline('3 доби', '3 days')},
    {'hours': 168, 'label': I18n.inline('1 тиждень', '1 week')},
  ];

  String _typeLabel(ChallengeType type) {
    switch (type) {
      case ChallengeType.goal:
        return I18n.inline('Гол', 'Goal');
      case ChallengeType.shotPower:
        return I18n.inline('Сила удару', 'Shot power');
      case ChallengeType.save:
        return I18n.inline('Сейв', 'Save');
      case ChallengeType.pass:
        return I18n.inline('Пас', 'Pass');
      case ChallengeType.longPass:
        return I18n.inline('Довгий пас', 'Long pass');
      case ChallengeType.tackle:
        return I18n.inline('Підкат', 'Tackle');
      case ChallengeType.dribbling:
        return I18n.inline('Дриблінг', 'Dribbling');
      case ChallengeType.penalty:
        return I18n.inline('Пенальті', 'Penalty');
      case ChallengeType.wall:
        return I18n.inline('Стіна / стандарт', 'Wall / set-piece');
      case ChallengeType.strategy:
        return I18n.inline('Стратегія', 'Strategy');
      case ChallengeType.trick:
        return I18n.inline('Трюк', 'Trick');
      case ChallengeType.other:
        return I18n.inline('Інше', 'Other');
    }
  }

  String _typeEmoji(ChallengeType type) {
    switch (type) {
      case ChallengeType.goal:
        return '⚽';
      case ChallengeType.shotPower:
        return '💥';
      case ChallengeType.save:
        return '🧤';
      case ChallengeType.pass:
        return '🎯';
      case ChallengeType.longPass:
        return '📡';
      case ChallengeType.tackle:
        return '🛡️';
      case ChallengeType.dribbling:
        return '🌀';
      case ChallengeType.penalty:
        return '🎯';
      case ChallengeType.wall:
        return '🧱';
      case ChallengeType.strategy:
        return '🧠';
      case ChallengeType.trick:
        return '✨';
      case ChallengeType.other:
        return '🎲';
    }
  }

  String _typeTagValue(ChallengeType type) => challengeTypeToSlug(type);

  List<String> _typeKeywordTags(ChallengeType type) {
    switch (type) {
      case ChallengeType.goal:
        return ['гол', 'удар', 'goal', 'finish'];
      case ChallengeType.shotPower:
        return ['power', 'сила', 'гармата', 'rocket'];
      case ChallengeType.save:
        return ['сейв', 'воротар', 'save', 'goalkeeper'];
      case ChallengeType.pass:
        return ['пас', 'передача', 'pass'];
      case ChallengeType.longPass:
        return ['довг', 'long pass', 'cross', 'діагональ'];
      case ChallengeType.tackle:
        return ['підкат', 'відбір', 'tackle'];
      case ChallengeType.dribbling:
        return ['дриблінг', 'фінт', 'dribble', 'skill'];
      case ChallengeType.penalty:
        return ['пеналь', '11', 'penalty'];
      case ChallengeType.wall:
        return ['стінк', 'wall', 'бар\'єр'];
      case ChallengeType.strategy:
        return ['стратег', 'тактик', 'strategy', 'scheme'];
      case ChallengeType.trick:
        return ['трюк', 'фрістайл', 'trick'];
      case ChallengeType.other:
        return ['інше', 'other'];
    }
  }

  @override
  void initState() {
    super.initState();
    _maxParticipantsController.text = '20';
    _prizePoolController.text = '100';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prizePoolController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Text(
              I18n.t('create_challenge'),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                _buildSectionTitle(Icons.info, I18n.inline('Основна інформація', 'Basic Information')),
                const SizedBox(height: 15),

                // Завантаження відео для челенджу
                _buildSectionTitle(Icons.video_library, I18n.inline('Відео челенджу', 'Challenge Video')),
                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      if (_selectedVideoFile == null) ...[
                        Icon(
                          Icons.video_library,
                          size: 48,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          I18n.inline('Завантажте відео для челенджу', 'Upload challenge video'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          I18n.inline('Це відео буде показуватися як приклад для інших учасників', 'This video will be shown as an example for other participants'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          I18n.inline(
                            'Ліміт: до 10 секунд, максимум 25 МБ',
                            'Limit: up to 10 seconds, maximum 25 MB',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickVideo(fromCamera: false),
                                icon: const Icon(Icons.video_library),
                                label: Text(I18n.inline('Галерея', 'Gallery')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4caf50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickVideo(fromCamera: true),
                                icon: const Icon(Icons.videocam),
                                label: Text(I18n.inline('Камера', 'Camera')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(
                              Icons.video_file,
                              size: 32,
                              color: const Color(0xFF4caf50),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    I18n.inline('Відео обрано', 'Video selected'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _selectedVideoFile!.path.split('/').last,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _selectedVideoFile = null),
                              icon: const Icon(Icons.close, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                
                // Назва челенджу
                _buildTextField(
                  controller: _titleController,
                  label: I18n.inline('Назва челенджу *', 'Challenge title *'),
                  hint: I18n.inline('Наприклад: "Дриблінг через конуси"', 'Example: "Dribbling through cones"'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return I18n.inline('Введіть назву челенджу', 'Enter challenge title');
                    }
                    if (value.trim().length < 5) {
                      return I18n.inline('Назва має бути не менше 5 символів', 'Title must be at least 5 characters');
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Опис
                _buildTextField(
                  controller: _descriptionController,
                  label: I18n.inline('Опис челенджу *', 'Challenge description *'),
                  hint: I18n.inline('Детально опишіть правила та вимоги до челенджу...', 'Describe rules and requirements in detail...'),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return I18n.inline('Введіть опис челенджу', 'Enter challenge description');
                    }
                    if (value.trim().length < 20) {
                      return I18n.inline('Опис має бути не менше 20 символів', 'Description must be at least 20 characters');
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 25),
                
                // Тип та аудиторія
                _buildSectionTitle(Icons.settings, I18n.t('settings')),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildDropdownField(
                        label: I18n.inline('Тип челенджу *', 'Challenge type *'),
                        value: _selectedType,
                        items: ChallengeType.values,
                        onChanged: (value) { setState(() { _selectedType = value!; }); },
                        itemBuilder: (type) => Row(
                          children: [
                            Text(_typeEmoji(type)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _typeLabel(type),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        icon: Icons.sports_soccer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildDropdownField(
                        label: I18n.inline('Аудиторія *', 'Audience *'),
                        value: _selectedAudience,
                        items: ChallengeAudience.values,
                        onChanged: (value) { setState(() { _selectedAudience = value!; }); },
                        itemBuilder: (audience) => Text(
                          audience == ChallengeAudience.friends ? I18n.inline('Моїм друзям', 'My friends')
                          : audience == ChallengeAudience.city ? I18n.inline('Моєму місту', 'My city')
                          : audience == ChallengeAudience.country ? I18n.inline('Моїй країні', 'My country')
                          : I18n.inline('Усьому світу', 'Worldwide'),
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: '👥',
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),

                // Окремі друзі для запрошення (мульти-вибір)
                Row(
                  children: [
                    Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      I18n.inline('Запросити друзів', 'Invite friends'),
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadMyFriends(),
                  builder: (context, snapshot) {
                    final friends = snapshot.data ?? const <Map<String, dynamic>>[];
                    if (friends.isEmpty) {
                      return Text(I18n.inline('Немає друзів для запрошення', 'No friends to invite'), style: TextStyle(color: Colors.white.withOpacity(0.7)));
                    }
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final f = friends[index];
                          final id = f['id'] as String;
                          final name = (f['displayName'] ?? f['name'] ?? I18n.inline('Користувач', 'User')).toString();
                          final photoUrl = (f['avatarUrl'] ?? f['photoUrl'] ?? '').toString();
                          final position = (f['position'] ?? f['role'] ?? '').toString();
                          final rating = ((f['rating'] ?? f['averageRating'] ?? 0) as num).toDouble();
                          final selected = _selectedInviteFriendIds.contains(id);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            leading: PlayerAvatarButton(
                              userId: id,
                              displayName: name,
                              avatarUrl: photoUrl,
                              size: 36,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                if (position.isNotEmpty) ...[
                                  Icon(Icons.sports_soccer, color: Colors.white54, size: 12),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      position,
                                      style: TextStyle(color: Colors.white54, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (rating > 0) ...[
                                  Icon(Icons.star, color: Colors.amber, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
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
                    );
                  },
                ),
                
                // Ставка входу
                _buildDropdownField(
                  label: I18n.inline('Ставка входу *', 'Entry fee *'),
                  value: _selectedEntryFee,
                  items: _entryFees,
                  onChanged: (value) {
                    setState(() {
                      _selectedEntryFee = value!;
                    });
                  },
                  itemBuilder: (fee) => Text(I18n.inline('$fee монет', '$fee coins')),
                  icon: Icons.monetization_on,
                ),
                
                const SizedBox(height: 20),
                
                // Тривалості етапів
                _buildSectionTitle(Icons.schedule, I18n.inline('Тривалості етапів', 'Stage durations')),
                const SizedBox(height: 15),
                
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxWidth = constraints.maxWidth;
                    final int columns = maxWidth >= 900 ? 3 : maxWidth >= 600 ? 2 : 1;
                    final double itemWidth = (maxWidth - 10 * (columns - 1)) / columns;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _buildDurationDropdown(
                            label: I18n.t('participant_recruitment') + ' *',
                            value: _recruitmentHours,
                            onChanged: (value) {
                              setState(() {
                                _recruitmentHours = value!;
                              });
                            },
                            icon: Icons.people,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDurationDropdown(
                            label: I18n.t('video_submission_stage') + ' *',
                            value: _submissionHours,
                            onChanged: (value) {
                              setState(() {
                                _submissionHours = value!;
                              });
                            },
                            icon: Icons.video_library,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildDurationDropdown(
                            label: I18n.t('voting') + ' *',
                            value: _votingHours,
                            onChanged: (value) {
                              setState(() {
                                _votingHours = value!;
                              });
                            },
                            icon: Icons.how_to_vote,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 25),
                
                // Інформація про етапи
                _buildSectionTitle(Icons.schedule, I18n.inline('Етапи челенджу', 'Challenge stages')),
                const SizedBox(height: 15),
                
                _buildStageInfo(),
                
                const SizedBox(height: 25),
                
                // Призовий фонд розподіл
                _buildSectionTitle(Icons.monetization_on, I18n.inline('Розподіл призів', 'Prize distribution')),
                const SizedBox(height: 15),
                
                _buildPrizeDistribution(),
                
                const SizedBox(height: 30),
                
                // Кнопка створення
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : () async {
                      // Confirm fee charge
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1e7d32),
                          title: Text(
                            I18n.inline('Підтвердження', 'Confirmation'),
                            style: const TextStyle(color: Colors.white),
                          ),
                          content: Text(
                            I18n.inline(
                              'Буде списано ${_selectedEntryFee} монет за створення челенджу. Продовжити?',
                              '${_selectedEntryFee} coins will be charged to create the challenge. Continue?',
                            ),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70))),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(I18n.t('confirm'))),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _createChallenge();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.emoji_events, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                I18n.t('create_challenge'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Пояснення
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            I18n.inline('Важливо знати:', 'Important to know:'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                                                 I18n.inline('• Ліміт: 1 челендж на місяць\n', '• Limit: 1 challenge per month\n')
                         + I18n.inline('• Ставка входу: ${_selectedEntryFee} монет\n', '• Entry fee: ${_selectedEntryFee} coins\n')
                         + I18n.inline('• Призовий фонд: ${_selectedEntryFee * 20} монет\n', '• Prize pool: ${_selectedEntryFee * 20} coins\n')
                         + I18n.inline('• 1-е місце: 50% (${(_selectedEntryFee * 20 * 0.5).toInt()} монет)\n', '• 1st place: 50% (${(_selectedEntryFee * 20 * 0.5).toInt()} coins)\n')
                         + I18n.inline('• 2-е місце: 30% (${(_selectedEntryFee * 20 * 0.3).toInt()} монет)\n', '• 2nd place: 30% (${(_selectedEntryFee * 20 * 0.3).toInt()} coins)\n')
                         + I18n.inline('• 3-є місце: 20% (${(_selectedEntryFee * 20 * 0.2).toInt()} монет)', '• 3rd place: 20% (${(_selectedEntryFee * 20 * 0.2).toInt()} coins)'),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadMyFriends() async {
    try {
      final me = _auth.currentUser;
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
      result.sort((a, b) => (a['displayName'] ?? a['name'] ?? '').toString().compareTo((b['displayName'] ?? b['name'] ?? '').toString()));
      return result;
    } catch (_) {
      return [];
    }
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,

          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
  required String label,
  required T value,
  required List<T> items,
  required Function(T?) onChanged,
  required Widget Function(T) itemBuilder,
  required dynamic icon,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44), // єдина висота
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.05), // єдиний розмір шрифту
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Row(
                    children: [
                      if (icon is IconData)
                        Icon(icon, size: 18, color: Colors.grey[700])
                      else if (icon is String)
                        Text(icon),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(fontSize: 14), // єдиний розмір у списку
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: itemBuilder(item),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildStageInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildStageItem(Icons.people, I18n.t('participant_recruitment'), _formatDuration(_recruitmentHours), Colors.green),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(Icons.video_library, I18n.t('video_submission_stage'), _formatDuration(_submissionHours), Colors.orange),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(Icons.how_to_vote, I18n.t('voting'), _formatDuration(_votingHours), Colors.blue),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(Icons.emoji_events, I18n.inline('Оголошення переможців', 'Winner announcement'), I18n.inline('Автоматично', 'Automatic'), Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStageItem(dynamic icon, String title, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: icon is IconData 
              ? Icon(icon, size: 18, color: color)
              : Text(
                  icon,
                  style: const TextStyle(fontSize: 18),
                ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeDistribution() {
    final prizePool = _selectedEntryFee * 20; // Призовий фонд = ставка × 20
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildPrizeItem('🥇', I18n.inline('1-е місце', '1st place'), '50%', (prizePool * 0.5).toInt(), Colors.amber),
          const SizedBox(height: 15),
          _buildPrizeItem('🥈', I18n.inline('2-е місце', '2nd place'), '30%', (prizePool * 0.3).toInt(), Colors.grey),
          const SizedBox(height: 15),
          _buildPrizeItem('🥉', I18n.inline('3-є місце', '3rd place'), '20%', (prizePool * 0.2).toInt(), Colors.orange),
        ],
      ),
    );
  }

  Widget _buildPrizeItem(String icon, String place, String percentage, int coins, Color color) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                percentage,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            I18n.inline('$coins монет', '$coins coins'),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationDropdown({
    required String label,
    required int value,
    required ValueChanged<int?> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
  children: [
    Icon(icon, color: Colors.white, size: 16),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: value,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
            ),
            dropdownColor: const Color(0xFF1a1a2e),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: _durations.map((d) {
              return DropdownMenuItem<int>(
                value: d['hours'] as int,
                child: Text(
                  d['label'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _formatDuration(int hours) {
    if (hours == 1) return I18n.inline('1 година', '1 hour');
    if (hours == 6) return I18n.inline('6 годин', '6 hours');
    if (hours == 24) return I18n.inline('1 доба', '1 day');
    if (hours == 72) return I18n.inline('3 доби', '3 days');
    if (hours == 168) return I18n.inline('1 тиждень', '1 week');
    return I18n.inline('$hours год', '$hours h');
  }

  Future<void> _createChallenge() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  I18n.inline('Будь ласка, оберіть відео для челенджу', 'Please select challenge video'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(I18n.inline('Користувач не авторизований', 'User not authorized'));
      }

      // Отримати дані користувача
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!userDoc.exists) {
        throw Exception(I18n.inline('Профіль користувача не знайдено', 'User profile not found'));
      }

      final userData = userDoc.data()!;
      final userName = userData['displayName'] ?? userData['name'] ?? I18n.inline('Невідомий', 'Unknown');
      final userCity = userData['city'] ?? _selectedCity;

      // Розрахунок дат з окремими тривалостями
      final now = DateTime.now();
      final startDate = now;
      final submissionDeadline = now.add(Duration(hours: _recruitmentHours));
      final votingDeadline = submissionDeadline.add(Duration(hours: _submissionHours));
      final endDate = votingDeadline.add(Duration(hours: _votingHours));

      // Розрахунок призового фонду
      final prizePool = _selectedEntryFee * 20; // Призовий фонд = ставка × 20

      // Створення челенджу
      final challenge = Challenge(
        id: '', // Буде встановлено Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        audience: _selectedAudience,
        creatorId: currentUser.uid,
        creatorName: userName,
        creatorVideoUrl: null, // Буде оновлено після завантаження відео
        city: userCity,
        entryFee: _selectedEntryFee,
        duration: (_recruitmentHours / 24).ceil(), // Зберігаємо в днях для сумісності
        createdAt: now,
        startDate: startDate,
        submissionDeadline: submissionDeadline,
        votingDeadline: votingDeadline,
        endDate: endDate,
        status: ChallengeStatus.submission,
        maxParticipants: 100, // Максимум учасників
        currentParticipants: 0,
        prizePool: prizePool.toDouble(),
        participants: [],
        submissions: [],
        votes: {},
        detailedVotes: {},
        winners: [],
        finalScores: {},
        isActive: true,
        tags: _generateTags(),
      );

      final challengeId = await _challengeService.createChallenge(challenge);
      
      if (challengeId != null) {
        // Додаємо створювача як учасника (статус вже правильний)
        await FirebaseFirestore.instance
            .collection('challenges')
            .doc(challengeId)
            .update({
          'participants': FieldValue.arrayUnion([currentUser.uid]),
          'currentParticipants': FieldValue.increment(1),
        });

        // Надсилаємо інвайти обраним друзям (якщо обрали)
        if (_selectedInviteFriendIds.isNotEmpty) {
          try {
            await NotificationService().sendBulkChallengeInvitations(
              userIds: _selectedInviteFriendIds.toList(),
              challengeId: challengeId,
              challengeTitle: _titleController.text.trim(),
              creatorName: userName,
              challengeType: challengeTypeToSlug(_selectedType),
            );
          } catch (_) {}
        }

        // Потім завантажуємо відео створювача
        if (_selectedVideoFile != null) {
          print('Starting creator video upload for challenge: $challengeId');
          try {
            final creatorVideoUrl = await _uploadCreatorVideo(challengeId, currentUser.uid, userName);
            if (creatorVideoUrl != null && creatorVideoUrl.isNotEmpty) {
              print('Creator video upload completed successfully with URL: $creatorVideoUrl');
              
              // Оновлюємо челендж з URL відео творця
              await FirebaseFirestore.instance
                  .collection('challenges')
                  .doc(challengeId)
                  .update({
                'creatorVideoUrl': creatorVideoUrl,
              });
              print('Updated challenge $challengeId with creatorVideoUrl: $creatorVideoUrl');
              
            } else {
              print('WARNING: Creator video upload returned null/empty URL');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(I18n.inline('⚠️ Відео створювача не завантажено!', '⚠️ Creator video was not uploaded!')),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            print('ERROR: Creator video upload failed: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(I18n.inline('❌ Помилка завантаження відео: $e', '❌ Video upload error: $e')),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          print('WARNING: No video file selected for creator!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(I18n.inline('⚠️ Відео створювача обов\'язкове!', '⚠️ Creator video is required!')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        // Показати повідомлення про успіх та запитати про завантаження відео
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1e7d32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    I18n.inline('Челендж створено!', 'Challenge created!'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                _selectedVideoFile != null 
                  ? I18n.inline(
                      'Челендж та ваше відео успішно створені! Тепер інші гравці можуть приєднатися та завантажити свої відео.',
                      'The challenge and your video were created successfully! Other players can now join and upload their videos.',
                    )
                  : I18n.inline(
                      'Челендж створено! Ви можете додати відео пізніше в деталях челенджу.',
                      'Challenge created! You can add a video later in the challenge details.',
                    ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Закрити діалог
                    Navigator.pop(context); // Повернутися назад
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1e7d32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    I18n.inline('Готово', 'Done'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        throw Exception(I18n.inline('Помилка створення челенджу', 'Failed to create challenge'));
      }
    } catch (e) {
      // Показати помилку
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  I18n.inline('Помилка: ${e.toString()}', 'Error: ${e.toString()}'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  List<String> _generateTags() {
    final tags = <String>[];
    
    // Тип і ключові слова
    tags.add(_typeTagValue(_selectedType));
    tags.addAll(_typeKeywordTags(_selectedType));

    // Додати місто
    tags.add(_selectedCity.toLowerCase());
    
    // Додати теги з назви та опису
    final title = _titleController.text.toLowerCase();
    final description = _descriptionController.text.toLowerCase();
    
    if (title.contains('дриблінг') || description.contains('дриблінг')) {
      tags.add('дриблінг');
    }
    if (title.contains('удар') || description.contains('удар')) {
      tags.add('удари');
    }
    if (title.contains('передача') || description.contains('передача')) {
      tags.add('передачі');
    }
    if (title.contains('воротар') || description.contains('воротар')) {
      tags.add('воротар');
    }
    if (title.contains('захист') || description.contains('захист')) {
      tags.add('захист');
    }
    
    return tags;
  }

  Future<void> _pickVideo({bool fromCamera = false}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: _maxVideoDuration,
      );
      
      if (video != null) {
        final fileSize = await video.length();
        if (fileSize > _maxVideoBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                I18n.inline(
                  'Файл занадто великий. Максимум 25 МБ.',
                  'File is too large. Maximum size is 25 MB.',
                ),
              ),
            ),
          );
          return;
        }
        setState(() {
          _selectedVideoFile = video;
        });
      }
    } catch (e) {
      print('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Помилка вибору відео: ${e.toString()}', 'Video selection error: ${e.toString()}')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadCreatorVideo(String challengeId, String userId, String authorName) async {
    if (_selectedVideoFile == null) {
      print('ERROR: _selectedVideoFile is null in _uploadCreatorVideo');
      return null;
    }
    
    try {
      print('Uploading creator video for challenge: $challengeId');
      
      print('Picked file name: ${_selectedVideoFile!.name}');
      
      // Завантажуємо відео в Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'creator_video_$timestamp.mp4';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos/$userId/$fileName');
      
      print('Storage path: videos/$userId/$fileName');
      
      // Завантажуємо відео
      UploadTask uploadTask;
      try {
        // Універсальний підхід: читаємо байти і виконуємо putData (працює і на web, і на mobile)
        print('Reading video file as bytes...');
        final bytes = await _selectedVideoFile!.readAsBytes();
        if (bytes.length > _maxVideoBytes) {
          throw Exception(
            I18n.inline(
              'Розмір відео перевищує 25 МБ.',
              'Video size exceeds 25 MB.',
            ),
          );
        }
        print('Video file size: ${bytes.length} bytes');
        uploadTask = storageRef.putData(bytes);
      } catch (e) {
        print('ERROR reading video file: $e');
        throw Exception(I18n.inline('Помилка читання відео файлу: $e', 'Video file read error: $e'));
      }
      
      print('Upload started...');
      
      String videoUrl;
      try {
        final snapshot = await uploadTask;
        print('Upload completed. Bytes transferred: ${snapshot.bytesTransferred}');
        
        videoUrl = await snapshot.ref.getDownloadURL();
        print('Video URL obtained: $videoUrl');
      } catch (e) {
        print('ERROR during upload or getting URL: $e');
        throw Exception(I18n.inline('Помилка завантаження або отримання URL: $e', 'Upload or URL retrieval error: $e'));
      }
      
      // Створюємо запис у колекції videos, щоб мати єдиний шлях голосів і агрегатів
      String createdVideoDocId = '';
      try {
        final videoDoc = await FirebaseFirestore.instance.collection('videos').add({
          'userId': userId,
          'authorId': userId,
          'authorName': authorName,
          'title': _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : I18n.inline('Відео створювача', 'Creator video'),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : I18n.inline('Відео челенджу', 'Challenge video'),
          'category': 'Інше',
          'difficulty': null,
          'videoUrl': videoUrl,
          'challengeId': challengeId,
          'challengeTitle': _titleController.text.trim(),
          'isChallengeVideo': true,
          'createdAt': FieldValue.serverTimestamp(),
          'likes': 0,
          'rating': 0.0,
          'views': 0,
          'thumbnailUrl': null,
          'thumbnailGenerated': false,
        });
        createdVideoDocId = videoDoc.id;
      } catch (_) {}

      // Зберігаємо відео створювача в submissions і помічаємо як головне
      print('Saving creator video to submissions collection...');
      try {
        await FirebaseFirestore.instance
            .collection('challenges')
            .doc(challengeId)
            .collection('submissions')
            .doc(userId)
            .set({
          'userId': userId,
          'authorName': authorName,
          'title': _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : I18n.inline('Відео створювача', 'Creator video'),
          'videoUrl': videoUrl,
          'videoId': createdVideoDocId,
          'isCreatorVideo': true,
          'createdAt': FieldValue.serverTimestamp(),
          'averageRating': 0.0,
          'voteCount': 0,
          'votes': <String, dynamic>{},
          'thumbnailUrl': null, // Буде оновлено після генерації
        });
        print('Creator video saved to submissions collection');
      } catch (e) {
        print('ERROR saving to submissions collection: $e');
        throw Exception('Помилка збереження в submissions: $e');
      }
      
      // Додаємо до списку submissions
      print('Updating challenge document with submissions...');
      try {
        await FirebaseFirestore.instance
            .collection('challenges')
            .doc(challengeId)
            .update({
          'submissions': FieldValue.arrayUnion([userId]),
        });
        print('Challenge document updated successfully');
      } catch (e) {
        print('ERROR updating challenge document: $e');
        throw Exception('Помилка оновлення челенджу: $e');
      }
      
      print('Successfully uploaded creator video: $videoUrl');
      
      // Генеруємо thumbnail для відео творця в фоновому режимі
      _generateCreatorThumbnailInBackground(challengeId, videoUrl, userId);
      
      return videoUrl; // Повертаємо URL відео
      
    } catch (e) {
      print('Error uploading creator video: $e');
      
      // Показуємо помилку користувачу
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка завантаження відео: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return null; // Помилка завантаження
    }
  }

  void _generateCreatorThumbnailInBackground(String challengeId, String videoUrl, String userId) {
    // Генеруємо thumbnail в фоновому режимі
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        print('🎬 Starting creator thumbnail generation for challenge: $challengeId');
        
        final thumbnailService = ThumbnailService();
        // Спочатку генеруємо thumbnail для основного відео документа
        final videoDoc = await FirebaseFirestore.instance
            .collection('videos')
            .where('userId', isEqualTo: userId)
            .where('videoUrl', isEqualTo: videoUrl)
            .limit(1)
            .get();
        
        String? videoDocId;
        if (videoDoc.docs.isNotEmpty) {
          videoDocId = videoDoc.docs.first.id;
          final thumbnailUrl = await thumbnailService.generateAndUploadThumbnail(
            videoUrl: videoUrl,
            videoId: videoDocId,
            userId: userId,
          );
          
          if (thumbnailUrl != null) {
            // Оновлюємо submission з thumbnailUrl
            await FirebaseFirestore.instance
                .collection('challenges')
                .doc(challengeId)
                .collection('submissions')
                .doc(userId)
                .update({
              'thumbnailUrl': thumbnailUrl,
              'thumbnailGenerated': true,
            });
            await FirebaseFirestore.instance
                .collection('challenges')
                .doc(challengeId)
                .update({
              'creatorThumbnailUrl': thumbnailUrl,
              'thumbnailUrl': thumbnailUrl,
            });
            print('✅ Creator video thumbnail generated: $thumbnailUrl');
          }
        } else {
          // Якщо не знайшли відео документ, генеруємо thumbnail для submission
          final thumbnailUrl = await thumbnailService.generateSubmissionThumbnail(
            videoUrl: videoUrl,
            challengeId: challengeId,
            submissionId: userId,
            userId: userId,
          );
          if (thumbnailUrl != null) {
            await FirebaseFirestore.instance
                .collection('challenges')
                .doc(challengeId)
                .update({
              'creatorThumbnailUrl': thumbnailUrl,
              'thumbnailUrl': thumbnailUrl,
            });
            print('✅ Creator submission thumbnail generated: $thumbnailUrl');
          }
        }
      } catch (e) {
        print('❌ Background creator thumbnail generation error: $e');
        // Не показуємо помилку користувачу, оскільки челендж вже створено
      }
    });
  }
}
