import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
// Removed dart:io to support web build
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/friends/domain/repositories/friends_repository.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/features/videos/data/thumbnail_service.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:intl/intl.dart';

@RoutePage()
class ChallengeCreateScreen extends StatefulWidget {
  @override
  _ChallengeCreateScreenState createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  static const int _maxVideoBytes = 25 * 1024 * 1024;
  static const Duration _maxVideoDuration = Duration(seconds: 10);
  static const Color _pageBg = Color(0xFF0F172A);
  static const Color _cardBg = Color(0xFF111827);
  static const Color _cardBorder = Color(0xFF273244);
  static const Color _heading = Color(0xFFF8FAFC);
  static const Color _body = Color(0xFFCBD5E1);
  static const Color _hint = Color(0xFF94A3B8);
  static const Color _primary = Color(0xFF4CAF50);
  static const Color _primaryDark = Color(0xFF2E7D32);
  static const Color _badgeBg = Color(0xFF163420);
  static const Color _badgeText = Color(0xFF86EFAC);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  
  ChallengeType _selectedType = ChallengeType.goal;
  ChallengeAudience _selectedAudience = ChallengeAudience.city;
  String _selectedCity = I18n.t('kyiv_city');
  int _selectedEntryFee = 10;
  /// Maps to `challenges.submit_due_date`, `vote_start_date`, `vote_end_date`.
  late DateTime _submitDueDate;
  late DateTime _voteStartDate;
  late DateTime _voteEndDate;
  bool _isCreating = false;
  XFile? _selectedVideoFile;
  bool _isVideoUploading = false;
  double _videoUploadProgress = 0.0;
  String? _uploadedCreatorVideoUrl;
  String? _uploadedCreatorVideoStoragePath;
  String? _videoUploadError;
  int _videoUploadSession = 0;
  
  final Set<String> _selectedInviteFriendIds = <String>{};

  final List<int> _entryFees = [5, 10, 15, 20, 25];

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
      case ChallengeType.freestyle:
        return I18n.inline('Фрістайл', 'Freestyle');
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
      case ChallengeType.freestyle:
        return '🤹';
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
      case ChallengeType.freestyle:
        return ['freestyle', 'фрістайл', 'skill', 'трюк'];
      case ChallengeType.other:
        return ['інше', 'other'];
    }
  }

  @override
  void initState() {
    super.initState();
    _maxParticipantsController.text = '20';
    _prizePoolController.text = '100';
    final now = DateTime.now();
    _submitDueDate = now.add(const Duration(days: 1));
    _voteStartDate = _submitDueDate;
    _voteEndDate = _voteStartDate.add(const Duration(days: 1));
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
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          I18n.t('create_challenge'),
          style: const TextStyle(
            color: _heading,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _heading),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // _buildSurfaceCard(
                //   padding: const EdgeInsets.all(20),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Container(
                //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                //         decoration: BoxDecoration(
                //           color: _badgeBg,
                //           borderRadius: BorderRadius.circular(999),
                //         ),
                //         child: Text(
                //           I18n.inline('Новий челендж', 'New challenge'),
                //           style: const TextStyle(
                //             color: _badgeText,
                //             fontWeight: FontWeight.w700,
                //             fontSize: 12,
                //           ),
                //         ),
                //       ),
                //       const SizedBox(height: 12),
                //       Text(
                //         I18n.inline('Створіть челендж, який захочуть пройти всі', 'Create a challenge players want to join'),
                //         style: const TextStyle(
                //           color: _heading,
                //           fontSize: 22,
                //           fontWeight: FontWeight.w700,
                //           height: 1.15,
                //         ),
                //       ),
                //       const SizedBox(height: 8),
                //       Text(
                //         I18n.inline(
                //           'Заповніть деталі, додайте приклад відео та запустіть нове змагання.',
                //           'Add challenge details, upload your sample video, and launch your competition.',
                //         ),
                //         style: const TextStyle(
                //           color: _body,
                //           fontSize: 14,
                //           height: 1.4,
                //         ),
                //       ),
                //       const SizedBox(height: 14),
                //       Row(
                //         children: [
                //           const Icon(Icons.location_on_outlined, size: 16, color: _hint),
                //           const SizedBox(width: 6),
                //           Expanded(
                //             child: Text(
                //               _selectedCity,
                //               style: const TextStyle(color: _hint, fontSize: 13),
                //               maxLines: 1,
                //               overflow: TextOverflow.ellipsis,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ],
                //   ),
                // ),
                // const SizedBox(height: 16),
                _buildSectionTitle(Icons.video_camera_back_outlined, I18n.inline('Challenge video', 'Challenge video')),
                const SizedBox(height: 10),
                _buildSurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      if (_selectedVideoFile == null) ...[
                        const Icon(Icons.play_circle_outline_rounded, size: 48, color: _hint),
                        const SizedBox(height: 10),
                        Text(
                          I18n.inline('Додайте коротке відео-приклад', 'Add a short sample video'),
                          style: const TextStyle(color: _heading, fontSize: 16, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          I18n.inline('До 10 секунд, максимум 25 МБ', 'Up to 10 seconds, maximum 25 MB'),
                          style: const TextStyle(color: _body, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickVideo(fromCamera: false),
                                icon: const Icon(Icons.video_library_outlined),
                                label: Text(I18n.inline('Галерея', 'Gallery')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _heading,
                                  side: const BorderSide(color: _cardBorder),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickVideo(fromCamera: true),
                                icon: const Icon(Icons.videocam_outlined),
                                label: Text(I18n.inline('Камера', 'Camera')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _heading,
                                  side: const BorderSide(color: _cardBorder),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _badgeBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.videocam_rounded, color: _badgeText),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isVideoUploading
                                        ? I18n.inline('Завантаження відео...', 'Uploading video...')
                                        : I18n.inline('Відео готове', 'Video ready'),
                                    style: const TextStyle(color: _heading, fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    _selectedVideoFile!.path.split('/').last,
                                    style: const TextStyle(color: _body, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_isVideoUploading) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: _videoUploadProgress <= 0 || _videoUploadProgress >= 1
                                            ? null
                                            : _videoUploadProgress,
                                        minHeight: 6,
                                        backgroundColor: const Color(0xFF334155),
                                        valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(_videoUploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(color: _hint, fontSize: 11),
                                    ),
                                  ] else if (_videoUploadError != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _videoUploadError!,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _isVideoUploading
                                  ? null
                                  : () => setState(() {
                                      _selectedVideoFile = null;
                                      _videoUploadError = null;
                                      _uploadedCreatorVideoUrl = null;
                                      _uploadedCreatorVideoStoragePath = null;
                                      _videoUploadProgress = 0.0;
                                    }),
                              icon: const Icon(Icons.close_rounded, color: _hint),
                            ),
                          ],
                        ),
                        if (_videoUploadError != null && !_isVideoUploading) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final selected = _selectedVideoFile;
                                if (selected != null) {
                                  _startVideoUpload(selected);
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(I18n.inline('Повторити завантаження', 'Retry upload')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _heading,
                                side: const BorderSide(color: _cardBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle(Icons.article_outlined, I18n.inline('Basic details', 'Basic details')),
                const SizedBox(height: 10),
                _buildSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
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
                      const SizedBox(height: 14),
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
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle(Icons.tune_rounded, I18n.t('settings')),
                const SizedBox(height: 10),
                _buildSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSchemaHint(
                        I18n.inline(
                          'Schema: type, audience, entry_fee (>= 0), max_participants (> 0)',
                          'Schema: type, audience, entry_fee (>= 0), max_participants (> 0)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              label: I18n.inline('Тип челенджу *', 'Challenge type *'),
                              value: _selectedType,
                              items: ChallengeType.values,
                              onChanged: (value) => setState(() => _selectedType = value!),
                              itemBuilder: (type) => Row(
                                children: [
                                  Text(_typeEmoji(type)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(_typeLabel(type), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                              icon: Icons.sports_soccer_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDropdownField(
                              label: I18n.inline('Аудиторія *', 'Audience *'),
                              value: _selectedAudience,
                              items: ChallengeAudience.values,
                              onChanged: (value) => setState(() => _selectedAudience = value!),
                              itemBuilder: (audience) => Text(
                                audience == ChallengeAudience.friends
                                    ? I18n.inline('Моїм друзям', 'My friends')
                                    : audience == ChallengeAudience.city
                                        ? I18n.inline('Моєму місту', 'My city')
                                        : audience == ChallengeAudience.country
                                            ? I18n.inline('Моїй країні', 'My country')
                                            : I18n.inline('Усьому світу', 'Worldwide'),
                                overflow: TextOverflow.ellipsis,
                              ),
                              icon: Icons.group_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildDropdownField(
                        label: I18n.inline('Ставка входу *', 'Entry fee *'),
                        value: _selectedEntryFee,
                        items: _entryFees,
                        onChanged: (value) => setState(() => _selectedEntryFee = value!),
                        itemBuilder: (fee) => Text(I18n.inline('$fee монет', '$fee coins')),
                        icon: Icons.monetization_on_outlined,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _maxParticipantsController,
                        label: I18n.inline('Макс. учасників *', 'Max participants *'),
                        hint: I18n.inline('Наприклад: 100', 'Example: 100'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return I18n.inline(
                              'Вкажіть число більше 0',
                              'Enter a number greater than 0',
                            );
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle(Icons.group_add_outlined, I18n.inline('Invite friends', 'Invite friends')),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadMyFriends(context),
                  builder: (context, snapshot) {
                    final friends = snapshot.data ?? const <Map<String, dynamic>>[];
                    if (friends.isEmpty) {
                      return _buildSurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          I18n.inline('Немає друзів для запрошення', 'No friends to invite'),
                          style: const TextStyle(color: _body),
                        ),
                      );
                    }
                    return _buildSurfaceCard(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: PlayerAvatarButton(
                              userId: id,
                              displayName: name,
                              avatarUrl: photoUrl,
                              size: 36,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(color: _heading, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                if (position.isNotEmpty) ...[
                                  const Icon(Icons.sports_soccer, color: _hint, size: 12),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      position,
                                      style: const TextStyle(color: _hint, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (rating > 0) ...[
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(color: _hint, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Checkbox(
                              value: selected,
                              activeColor: _primary,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedInviteFriendIds.add(id);
                                  } else {
                                    _selectedInviteFriendIds.remove(id);
                                  }
                                });
                              },
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
                const SizedBox(height: 18),
                _buildSectionTitle(
                  Icons.event_available_outlined,
                  I18n.inline('Етапи та дати', 'Stage schedule'),
                ),
                const SizedBox(height: 6),
                Text(
                  I18n.inline(
                    'Оберіть дедлайн подання, початок і кінець голосування (submit_due_date ≤ vote_start_date ≤ vote_end_date).',
                    'Pick submission deadline, voting start, and voting end (submit_due_date ≤ vote_start_date ≤ vote_end_date).',
                  ),
                  style: const TextStyle(color: _hint, fontSize: 12.5, height: 1.35),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final columns = maxWidth >= 900 ? 3 : maxWidth >= 600 ? 2 : 1;
                    final itemWidth = (maxWidth - 10 * (columns - 1)) / columns;
                    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _buildStageDatePickerTile(
                            label: I18n.inline('Дедлайн подання', 'Submission deadline'),
                            subtitle: I18n.inline('submit_due_date', 'submit_due_date'),
                            value: _submitDueDate,
                            icon: Icons.upload_file_outlined,
                            firstDate: today,
                            onChanged: (d) => setState(() {
                              _submitDueDate = d;
                              _ensureStageDatesOrdered();
                            }),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildStageDatePickerTile(
                            label: I18n.inline('Початок голосування', 'Voting starts'),
                            subtitle: I18n.inline('vote_start_date', 'vote_start_date'),
                            value: _voteStartDate,
                            icon: Icons.how_to_vote_outlined,
                            firstDate: DateTime(
                              _submitDueDate.year,
                              _submitDueDate.month,
                              _submitDueDate.day,
                            ),
                            onChanged: (d) => setState(() {
                              _voteStartDate = d;
                              _ensureStageDatesOrdered();
                            }),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildStageDatePickerTile(
                            label: I18n.inline('Кінець голосування', 'Voting ends'),
                            subtitle: I18n.inline('vote_end_date', 'vote_end_date'),
                            value: _voteEndDate,
                            icon: Icons.event_busy_outlined,
                            firstDate: DateTime(
                              _voteStartDate.year,
                              _voteStartDate.month,
                              _voteStartDate.day,
                            ),
                            onChanged: (d) => setState(() {
                              _voteEndDate = d;
                              _ensureStageDatesOrdered();
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _buildSectionTitle(Icons.timeline_rounded, I18n.inline('Challenge stages', 'Challenge stages')),
                const SizedBox(height: 10),
                _buildStageInfo(),
                const SizedBox(height: 18),
                _buildSectionTitle(Icons.emoji_events_outlined, I18n.inline('Prize distribution', 'Prize distribution')),
                const SizedBox(height: 10),
                _buildPrizeDistribution(),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isCreating
                        ? null
                        : () async {
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
                                    'Буде списано $_selectedEntryFee монет за створення челенджу. Продовжити?',
                                    '$_selectedEntryFee coins will be charged to create the challenge. Continue?',
                                  ),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(I18n.t('confirm')),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _createChallenge();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primary.withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.emoji_events_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                I18n.t('create_challenge'),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildSurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: _hint, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            I18n.inline('Важливо знати', 'Important to know'),
                            style: const TextStyle(color: _heading, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18n.inline(
                          '• Ліміт: 1 челендж на місяць\n'
                          '• Ставка входу: $_selectedEntryFee монет\n'
                          '• Призовий фонд: ${_selectedEntryFee * 20} монет\n'
                          '• 1-е місце: 50% (${(_selectedEntryFee * 20 * 0.5).toInt()} монет)\n'
                          '• 2-е місце: 30% (${(_selectedEntryFee * 20 * 0.3).toInt()} монет)\n'
                          '• 3-є місце: 20% (${(_selectedEntryFee * 20 * 0.2).toInt()} монет)',
                          '• Limit: 1 challenge per month\n'
                          '• Entry fee: $_selectedEntryFee coins\n'
                          '• Prize pool: ${_selectedEntryFee * 20} coins\n'
                          '• 1st place: 50% (${(_selectedEntryFee * 20 * 0.5).toInt()} coins)\n'
                          '• 2nd place: 30% (${(_selectedEntryFee * 20 * 0.3).toInt()} coins)\n'
                          '• 3rd place: 20% (${(_selectedEntryFee * 20 * 0.2).toInt()} coins)',
                        ),
                        style: const TextStyle(color: _body, fontSize: 12.5, height: 1.45),
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

  /// Uses Supabase `user_friends` + `profiles` via [FriendsRepository] (same graph as Friends tab).
  Future<List<Map<String, dynamic>>> _loadMyFriends(BuildContext context) async {
    try {
      final me = AppAuthContext.currentUser;
      if (me == null) return [];
      final friends =
          await context.read<FriendsRepository>().getUserFriends(me.id);
      final result = friends
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
            },
          )
          .toList();
      result.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
      return result;
    } catch (_) {
      return [];
    }
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorder),
          ),
          child: Icon(icon, color: _primaryDark, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _heading,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSchemaHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.data_object_rounded, size: 16, color: _hint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _body, fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
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
            color: _heading,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _hint, fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
            color: _heading,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              dropdownColor: const Color(0xFF0B1220),
              style: const TextStyle(color: _heading, fontSize: 14),
              iconEnabledColor: _body,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Row(
                    children: [
                      if (icon is IconData) Icon(icon, size: 18, color: _hint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(color: _heading, fontSize: 14),
                          child: itemBuilder(item),
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
      ],
    );
  }

  Widget _buildStageInfo() {
    return _buildSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStageItem(
            Icons.upload_file_outlined,
            I18n.inline('Подання до', 'Submissions until'),
            _formatStageDateTime(_submitDueDate),
            Colors.green,
          ),
          const Divider(color: _cardBorder, height: 20),
          _buildStageItem(
            Icons.how_to_vote_outlined,
            I18n.inline('Голосування', 'Voting'),
            '${_formatStageDateTime(_voteStartDate)} → ${_formatStageDateTime(_voteEndDate)}',
            Colors.blue,
          ),
          const Divider(color: _cardBorder, height: 20),
          _buildStageItem(
            Icons.emoji_events,
            I18n.inline('Оголошення переможців', 'Winner announcement'),
            I18n.inline('Після vote_end_date', 'After vote_end_date'),
            Colors.purple,
          ),
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
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.28)),
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
                  color: _heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  color: _body,
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
    
    return _buildSurfaceCard(
      padding: const EdgeInsets.all(20),
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
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color.withValues(alpha: 0.28)),
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
                  color: _heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                percentage,
                style: TextStyle(
                  color: _body,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.28)),
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

  String _formatStageDateTime(DateTime d) {
    return DateFormat.yMMMd().add_Hm().format(d);
  }

  void _ensureStageDatesOrdered() {
    if (_voteStartDate.isBefore(_submitDueDate)) {
      _voteStartDate = _submitDueDate;
    }
    if (_voteEndDate.isBefore(_voteStartDate)) {
      _voteEndDate = _voteStartDate.add(const Duration(hours: 1));
    }
  }

  Future<void> _pickStageDateTime({
    required BuildContext context,
    required DateTime initial,
    required DateTime firstDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: DateTime(firstDate.year + 2, 12, 31),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !context.mounted) return;

    final merged = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    onPicked(merged);
  }

  Widget _buildStageDatePickerTile({
    required String label,
    required String subtitle,
    required DateTime value,
    required IconData icon,
    required DateTime firstDate,
    required ValueChanged<DateTime> onChanged,
  }) {
    return _buildSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _pickStageDateTime(
            context: context,
            initial: value,
            firstDate: firstDate,
            onPicked: onChanged,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, color: _primaryDark, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: _heading,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: _hint, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatStageDateTime(value),
                        style: const TextStyle(color: _body, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.calendar_month_rounded, color: _hint, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BoxConstraints? constraints,
  }) {
    return Container(
      padding: padding,
      constraints: constraints,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100D1829),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _createChallenge() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _ensureStageDatesOrdered();
    final now = DateTime.now();
    if (_submitDueDate.isBefore(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Дедлайн подання має бути в майбутньому',
              'Submission deadline must be in the future',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_submitDueDate.isAfter(_voteStartDate) || _voteStartDate.isAfter(_voteEndDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Некоректні дати: submit_due_date ≤ vote_start_date ≤ vote_end_date',
              'Invalid dates: submit_due_date ≤ vote_start_date ≤ vote_end_date',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
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
    if (_isVideoUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Дочекайтесь завершення завантаження відео',
              'Please wait for the video upload to finish',
            ),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_uploadedCreatorVideoUrl == null || _uploadedCreatorVideoStoragePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Відео не завантажено. Спробуйте ще раз.',
              'Video is not uploaded yet. Please retry.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) {
        throw Exception(I18n.inline('Користувач не авторизований', 'User not authorized'));
      }

      final userData = await context
          .read<ProfileRepository>()
          .fetchLegacyUserMap(currentUser.id);
      if (userData == null || userData.isEmpty) {
        throw Exception(
          I18n.inline(
            'Профіль користувача не знайдено',
            'User profile not found',
          ),
        );
      }

      final userName = (userData['displayName'] ??
              userData['name'] ??
              I18n.inline('Невідомий', 'Unknown'))
          .toString();
      final userCity =
          (userData['city'] ?? _selectedCity).toString();

      final startDate = now;
      final submissionDeadline = _submitDueDate;
      final votingDeadline = _voteStartDate;
      final endDate = _voteEndDate;
      final durationDays = submissionDeadline.difference(now).inDays.abs().clamp(1, 3650);

      // Розрахунок призового фонду
      final prizePool = _selectedEntryFee * 20; // Призовий фонд = ставка × 20
      final maxParticipants = int.tryParse(_maxParticipantsController.text.trim()) ?? 100;

      // Створення челенджу
      final challenge = Challenge(
        id: '', // Встановлюється репозиторієм челенджів
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        audience: _selectedAudience,
        creatorId: currentUser.id,
        creatorName: userName,
        creatorVideoUrl: null, // Буде оновлено після завантаження відео
        city: userCity,
        entryFee: _selectedEntryFee,
        duration: durationDays,
        createdAt: now,
        startDate: startDate,
        submissionDeadline: submissionDeadline,
        votingDeadline: votingDeadline,
        endDate: endDate,
        status: ChallengeStatus.submission,
        maxParticipants: maxParticipants,
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

      final challengeId =
          await context.read<ChallengeRepository>().createChallenge(challenge);

      {
        await context.read<ChallengeRepository>().addCreatorParticipant(challengeId);

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

        await _attachPreUploadedCreatorVideo(challengeId, currentUser.id, userName);
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
          _videoUploadError = null;
          _uploadedCreatorVideoUrl = null;
          _uploadedCreatorVideoStoragePath = null;
        });
        await _startVideoUpload(video);
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
    if (_uploadedCreatorVideoUrl == null || _uploadedCreatorVideoStoragePath == null) {
      print('ERROR: uploaded creator video is missing in _uploadCreatorVideo');
      return null;
    }

    try {
      if (!mounted) return _uploadedCreatorVideoUrl;
      final videosRepo = context.read<VideosRepository>();
      final videoUrl = _uploadedCreatorVideoUrl!;
      final storagePath = _uploadedCreatorVideoStoragePath!;
      final challengeRepo = context.read<ChallengeRepository>();

      // Persist creator challenge video URL immediately after successful upload.
      // This avoids ending up with null challenge.video_url if later steps fail.
      await challengeRepo.setCreatorVideo(
        challengeId,
        videoUrl,
      );

      final titleText = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : I18n.inline('Відео створювача', 'Creator video');
      final descText = _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : I18n.inline('Відео челенджу', 'Challenge video');

      String? createdVideoDocId;
      try {
        createdVideoDocId = await videosRepo.createVideoRecord(
          userId: userId,
          authorName: authorName,
          title: titleText,
          description: descText,
          category: 'Інше',
          difficulty: null,
          videoUrl: videoUrl,
          videoStoragePath: storagePath,
          city: null,
          challengeId: challengeId,
          challengeTitle: _titleController.text.trim(),
          isChallengeVideo: true,
        );

        // `rpcUpsertSubmission` maps `videoId` → `challenge_submissions.video_storage_path`
        // (object key under `challenge_videos`), not `public.videos.id`.
        await challengeRepo.upsertSubmission(
              challengeId: challengeId,
              userId: userId,
              videoId: storagePath,
              videoUrl: videoUrl,
              title: titleText,
              authorName: authorName,
              isCreatorVideo: true,
            );
      } catch (e) {
        // Keep challenge.video_url set even if video record/submission writes fail.
        print('WARNING: creator video metadata write failed: $e');
      }

      _generateCreatorThumbnailInBackground(
        challengeId,
        videoUrl,
        userId,
        createdVideoDocId: createdVideoDocId,
      );

      return videoUrl;
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

  Future<void> _attachPreUploadedCreatorVideo(
    String challengeId,
    String userId,
    String authorName,
  ) async {
    final creatorVideoUrl = await _uploadCreatorVideo(challengeId, userId, authorName);
    if (!mounted) return;
    if (creatorVideoUrl == null || creatorVideoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              '⚠️ Відео створювача не привʼязано до челенджу',
              '⚠️ Creator video was not attached to the challenge',
            ),
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _startVideoUpload(XFile file) async {
    final user = AppAuthContext.currentUser;
    if (user == null) {
      setState(() {
        _videoUploadError = I18n.inline('Користувач не авторизований', 'User not authorized');
      });
      return;
    }

    final currentSession = ++_videoUploadSession;
    setState(() {
      _isVideoUploading = true;
      _videoUploadProgress = 0.02;
      _videoUploadError = null;
    });

    try {
      final bytes = await file.readAsBytes();
      if (currentSession != _videoUploadSession || !mounted) return;
      if (bytes.length > _maxVideoBytes) {
        throw Exception(
          I18n.inline(
            'Розмір відео перевищує 25 МБ.',
            'Video size exceeds 25 MB.',
          ),
        );
      }
      setState(() => _videoUploadProgress = 0.15);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'creator_video_${user.id}_$timestamp.mp4';
      final videosRepo = context.read<VideosRepository>();
      final uploaded = await videosRepo.uploadVideoBytes(
        userId: user.id,
        bytes: bytes,
        fileName: fileName,
        isChallengeVideo: true,
      );
      if (currentSession != _videoUploadSession || !mounted) return;
      setState(() {
        _uploadedCreatorVideoUrl = uploaded.publicUrl;
        _uploadedCreatorVideoStoragePath = uploaded.path;
        _videoUploadProgress = 1.0;
        _isVideoUploading = false;
      });
    } catch (e) {
      if (currentSession != _videoUploadSession || !mounted) return;
      final details = _friendlyUploadError(e);
      setState(() {
        _videoUploadError = I18n.inline(
          'Помилка завантаження відео. Спробуйте ще раз.\n$details',
          'Video upload failed. Please retry.\n$details',
        );
        _isVideoUploading = false;
        _videoUploadProgress = 0.0;
        _uploadedCreatorVideoUrl = null;
        _uploadedCreatorVideoStoragePath = null;
      });
    }
  }

  String _friendlyUploadError(Object e) {
    final raw = e.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('502') || lower.contains('bad gateway') || lower.contains('cloudflare')) {
      return I18n.inline(
        'Сервер тимчасово недоступний (502). Спробуйте ще раз за кілька секунд.',
        'Temporary server issue (502). Please retry in a few seconds.',
      );
    }
    if (lower.contains('<html') || lower.contains('<body')) {
      return I18n.inline(
        'Тимчасова помилка мережі. Спробуйте ще раз.',
        'Temporary network error. Please retry.',
      );
    }
    return raw;
  }

  void _generateCreatorThumbnailInBackground(
    String challengeId,
    String videoUrl,
    String userId, {
    String? createdVideoDocId,
  }) {
    // Генеруємо thumbnail в фоновому режимі
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        print('🎬 Starting creator thumbnail generation for challenge: $challengeId');
        
        final thumbnailService = ThumbnailService();
        if (!context.mounted) return;
        final videosRepo = context.read<VideosRepository>();
        final videoDocId = createdVideoDocId ??
            await videosRepo.findLibraryVideoIdByUrl(userId: userId, videoUrl: videoUrl);

        if (videoDocId != null && videoDocId.isNotEmpty) {
          final thumbnailUrl = await thumbnailService.generateAndUploadThumbnail(
            videosRepository: videosRepo,
            videoUrl: videoUrl,
            videoId: videoDocId,
            userId: userId,
          );
          
          if (thumbnailUrl != null && mounted) {
            final repo = context.read<ChallengeRepository>();
            await repo.setSubmissionThumbnail(
              challengeId: challengeId,
              userId: userId,
              thumbnailUrl: thumbnailUrl,
            );
            await repo.setCreatorVideo(
              challengeId,
              videoUrl,
              thumbnailUrl: thumbnailUrl,
            );
            print('✅ Creator video thumbnail generated: $thumbnailUrl');
          }
        } else {
          final thumbnailUrl = await thumbnailService.generateSubmissionThumbnail(
            videosRepository: videosRepo,
            videoUrl: videoUrl,
            challengeId: challengeId,
            submissionId: userId,
            userId: userId,
          );
          if (thumbnailUrl != null && mounted) {
            final repo = context.read<ChallengeRepository>();
            await repo.setCreatorVideo(
              challengeId,
              videoUrl,
              thumbnailUrl: thumbnailUrl,
            );
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
