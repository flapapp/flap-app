import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import '../../../../constants/video_categories.dart';
import 'package:image_picker/image_picker.dart';
// Removed dart:io to support web build
import '../../../../core/di/injection.dart';
import '../../domain/repositories/challenges_repository.dart';
import '../../data/models/challenge.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../video/data/services/thumbnail_service.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/styled_dropdown_form_field.dart';
import 'package:flap_app/core/auth/app_auth.dart';

@RoutePage()
class ChallengeCreateScreen extends StatefulWidget {
  const ChallengeCreateScreen({super.key});

  @override
  State<ChallengeCreateScreen> createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  final SupabaseClient _sb = Supabase.instance.client;
  static const int _maxVideoBytes = 25 * 1024 * 1024;
  static const Duration _maxVideoDuration = Duration(seconds: 10);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  ChallengeType _selectedType = ChallengeType.goal;
  ChallengeAudience _selectedAudience = ChallengeAudience.city;
  String _selectedCity = tr('kyiv_city');
  int _selectedEntryFee = 10;
  int _recruitmentHours = 24; // 1 доба за замовчуванням
  int _submissionHours = 24;
  int _votingHours = 24;
  bool _isCreating = false;
  XFile? _selectedVideoFile;

  ChallengesRepository get _challengesRepo => sl<ChallengesRepository>();

  final Set<String> _selectedInviteFriendIds = <String>{};

  final List<int> _entryFees = [5, 10, 15, 20, 25];
  List<Map<String, dynamic>> get _durations => [
    {'hours': 1, 'label': tr('il_f8b8883f0c')},
    {'hours': 6, 'label': tr('il_4105ae3b8a')},
    {'hours': 24, 'label': tr('il_fa665d95d2')},
    {'hours': 72, 'label': tr('il_360719440e')},
    {'hours': 168, 'label': tr('il_c8cc522340')},
  ];

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
      case ChallengeType.defending:
        return ['захист', 'оборона', 'defending', 'defense', 'block'];
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
              tr('create_challenge'),
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
                _buildSectionTitle(Icons.info, tr('il_d094b334d8')),
                const SizedBox(height: 15),

                // Завантаження відео для челенджу
                _buildSectionTitle(Icons.video_library, tr('il_af9d7e3d65')),
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
                          tr('il_7d7eb7441c'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('il_55d7bf332a'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('il_2186dc395e'),
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
                                label: Text(tr('il_352cfc749e')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4caf50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
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
                                label: Text(tr('il_03494b0d1f')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
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
                                    tr('il_4f8b7998bd'),
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
                              onPressed: () =>
                                  setState(() => _selectedVideoFile = null),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
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
                  label: tr('il_1b64eea021'),
                  hint: tr('il_3ba12e8766'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return tr('il_841873f8a6');
                    }
                    if (value.trim().length < 5) {
                      return tr('il_a405ba411a');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Опис
                _buildTextField(
                  controller: _descriptionController,
                  label: tr('il_d1b6cdb562'),
                  hint: tr('il_c6fe7905a3'),
                  maxLines: 4,
                  validator: (value) {
                    final t = value?.trim() ?? '';
                    if (t.isEmpty) return null;
                    if (t.length < 20) {
                      return tr('il_01a8bb483e');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 25),
                // Тип та аудиторія
                _buildSectionTitle(Icons.settings, tr('settings')),
                const SizedBox(height: 15),
                StyledDropdownFormField<String>(
                  value: challengeTypeToSlug(_selectedType),
                  labelText: tr('il_9a2597b919'),
                  items: kVideoCategories
                      .map((category) => category.id)
                      .toList(),
                  itemBuilder: (categoryId) {
                    final category = videoCategoryById(categoryId);
                    final label =
                        category?.label() ?? videoCategoryLabel(categoryId);
                    final description = category?.description() ?? '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    );
                  },
                  selectedItemBuilder: (categoryId) {
                    final category = videoCategoryById(categoryId);
                    final label =
                        category?.label() ?? videoCategoryLabel(categoryId);
                    return Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedType = parseChallengeType(value);
                    });
                  },
                ),
                const SizedBox(width: 12),
                _buildDropdownField(
                  label: tr('il_3013c7e4fa'),
                  value: _selectedAudience,
                  items: ChallengeAudience.values,
                  onChanged: (value) {
                    setState(() {
                      _selectedAudience = value!;
                    });
                  },
                  itemBuilder: (audience) => Text(
                    audience == ChallengeAudience.friends
                        ? tr('il_1419851d1b')
                        : audience == ChallengeAudience.city
                        ? tr('il_eb5e5b054b')
                        : audience == ChallengeAudience.country
                        ? tr('il_beba73d45d')
                        : tr('il_42605c01fa'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: '👥',
                ),

                // Тип та аудиторія
                // _buildSectionTitle(Icons.settings, tr('settings')),
                // const SizedBox(height: 15),
                // Row(
                //   children: [
                //     Expanded(
                //       flex: 1,
                //       child:
                //       StyledDropdownFormField<String>(
                //         value: challengeTypeToSlug(_selectedType),
                //         labelText: tr('il_9a2597b919'),
                //         items: kVideoCategories.map((category) => category.id).toList(),
                //         itemBuilder: (categoryId) {
                //           final category = videoCategoryById(categoryId);
                //           final label =
                //               category?.label() ?? videoCategoryLabel(categoryId);
                //           final description = category?.description() ?? '';
                //           return Column(
                //             crossAxisAlignment: CrossAxisAlignment.start,
                //             mainAxisSize: MainAxisSize.min,
                //             children: [
                //               Text(
                //                 label,
                //                 style: const TextStyle(
                //                   color: Colors.white,
                //                   fontWeight: FontWeight.w600,
                //                 ),
                //                 overflow: TextOverflow.ellipsis,
                //               ),
                //               if (description.isNotEmpty) ...[
                //                 const SizedBox(height: 2),
                //                 Text(
                //                   description,
                //                   style: const TextStyle(
                //                     color: Colors.white70,
                //                     fontSize: 11,
                //                   ),
                //                   maxLines: 1,
                //                   overflow: TextOverflow.ellipsis,
                //                 ),
                //               ],
                //             ],
                //           );
                //         },
                //         selectedItemBuilder: (categoryId) {
                //           final category = videoCategoryById(categoryId);
                //           final label =
                //               category?.label() ?? videoCategoryLabel(categoryId);
                //           return Text(
                //             label,
                //             maxLines: 1,
                //             overflow: TextOverflow.ellipsis,
                //             style: const TextStyle(
                //               color: Colors.white,
                //               fontWeight: FontWeight.w600,
                //             ),
                //           );
                //         },
                //         onChanged: (value) {
                //           if (value == null) return;
                //           setState(() {
                //             _selectedType = parseChallengeType(value);
                //           });
                //         },
                //       ),
                //     ),
                //     const SizedBox(width: 12),
                //     Expanded(
                //       flex: 1,
                //       child: _buildDropdownField(
                //         label: tr('il_3013c7e4fa'),
                //         value: _selectedAudience,
                //         items: ChallengeAudience.values,
                //         onChanged: (value) { setState(() { _selectedAudience = value!; }); },
                //         itemBuilder: (audience) => Text(
                //           audience == ChallengeAudience.friends ? tr('il_1419851d1b')
                //           : audience == ChallengeAudience.city ? tr('il_eb5e5b054b')
                //           : audience == ChallengeAudience.country ? tr('il_beba73d45d')
                //           : tr('il_42605c01fa'),
                //           overflow: TextOverflow.ellipsis,
                //         ),
                //         icon: '👥',
                //       ),
                //     ),
                //   ],
                // ),
                const SizedBox(height: 20),

                // Окремі друзі для запрошення (мульти-вибір)
                Row(
                  children: [
                    Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      tr('il_2614b42d84'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadMyFriends(),
                  builder: (context, snapshot) {
                    final friends =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    if (friends.isEmpty) {
                      return Text(
                        tr('il_3f6a83aa65'),
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      );
                    }
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final f = friends[index];
                          final id = f['id'] as String;
                          final name =
                              (f['displayName'] ??
                                      f['name'] ??
                                      tr('il_b512d97e7c'))
                                  .toString();
                          final photoUrl =
                              (f['avatarUrl'] ?? f['photoUrl'] ?? '')
                                  .toString();
                          final position = (f['position'] ?? f['role'] ?? '')
                              .toString();
                          final rating =
                              ((f['rating'] ?? f['averageRating'] ?? 0) as num)
                                  .toDouble();
                          final selected = _selectedInviteFriendIds.contains(
                            id,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                if (position.isNotEmpty) ...[
                                  Icon(
                                    Icons.sports_soccer,
                                    color: Colors.white54,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      position,
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (rating > 0) ...[
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
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
                  label: tr('il_8ef4bf1d45'),
                  value: _selectedEntryFee,
                  items: _entryFees,
                  onChanged: (value) {
                    setState(() {
                      _selectedEntryFee = value!;
                    });
                  },
                  itemBuilder: (fee) =>
                      Text(tr('il_eae716cab3', namedArgs: {'fee': '$fee'})),
                  icon: Icons.monetization_on,
                ),

                const SizedBox(height: 20),

                // Тривалості етапів
                _buildSectionTitle(Icons.schedule, tr('il_8c56789629')),
                const SizedBox(height: 15),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxWidth = constraints.maxWidth;
                    final int columns = maxWidth >= 900
                        ? 3
                        : maxWidth >= 600
                        ? 2
                        : 1;
                    final double itemWidth =
                        (maxWidth - 10 * (columns - 1)) / columns;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _buildDurationDropdown(
                            label: tr('participant_recruitment') + ' *',
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
                            label: tr('video_submission_stage') + ' *',
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
                            label: tr('voting') + ' *',
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
                _buildSectionTitle(Icons.schedule, tr('il_d35fa97769')),
                const SizedBox(height: 15),

                _buildStageInfo(),

                const SizedBox(height: 25),

                // Призовий фонд розподіл
                _buildSectionTitle(Icons.monetization_on, tr('il_54d3171fd8')),
                const SizedBox(height: 15),

                _buildPrizeDistribution(),

                const SizedBox(height: 30),

                // Кнопка створення
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreating
                        ? null
                        : () async {
                            // Confirm fee charge
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1e7d32),
                                title: Text(
                                  tr('il_d743070540'),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                content: Text(
                                  bilingual(
                                    'Буде списано ${_selectedEntryFee} монет за створення челенджу. Продовжити?',
                                    '${_selectedEntryFee} coins will be charged to create the challenge. Continue?',
                                  ),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(
                                      tr('cancel'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(tr('confirm')),
                                  ),
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
                              Icon(
                                Icons.emoji_events,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr('create_challenge'),
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
                          const Icon(
                            Icons.info_outline,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('il_7a26875758'),
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
                        tr('il_b288ca1f0f') +
                            tr('il_82a07f2980', args: ['$_selectedEntryFee']) +
                            tr(
                              'il_c96602cb3a',
                              args: ['${_selectedEntryFee * 20}'],
                            ) +
                            tr(
                              'il_f1b4cbd59c',
                              args: [
                                '${(_selectedEntryFee * 20 * 0.5).toInt()}',
                              ],
                            ) +
                            tr(
                              'il_0b24b4d5e6',
                              args: [
                                '${(_selectedEntryFee * 20 * 0.3).toInt()}',
                              ],
                            ) +
                            tr(
                              'il_1f74dfdb89',
                              args: [
                                '${(_selectedEntryFee * 20 * 0.2).toInt()}',
                              ],
                            ),
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
      final me = AppAuth.currentUser;
      if (me == null) return [];
      final rows = await _sb
          .from('friendships')
          .select('friend_user_id')
          .eq('user_id', me.id);
      final ids = (rows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['friend_user_id'].toString())
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) return [];
      final profiles = await _sb
          .from('profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', ids.take(50).toList());
      final result = (profiles as List<dynamic>).map((raw) {
        final data = raw as Map<String, dynamic>;
        return <String, dynamic>{
          'id': data['id'],
          'displayName': data['display_name'],
          'avatarUrl': data['avatar_url'],
        };
      }).toList();
      result.sort(
        (a, b) => (a['displayName'] ?? a['name'] ?? '').toString().compareTo(
          (b['displayName'] ?? b['name'] ?? '').toString(),
        ),
      );
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
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
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
    required ValueChanged<T?> onChanged,
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
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  height: 1.05,
                ), // єдиний розмір шрифту
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
                            style: const TextStyle(
                              fontSize: 14,
                            ), // єдиний розмір у списку
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
          _buildStageItem(
            Icons.people,
            tr('participant_recruitment'),
            _formatDuration(_recruitmentHours),
            Colors.green,
          ),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(
            Icons.video_library,
            tr('video_submission_stage'),
            _formatDuration(_submissionHours),
            Colors.orange,
          ),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(
            Icons.how_to_vote,
            tr('voting'),
            _formatDuration(_votingHours),
            Colors.blue,
          ),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(
            Icons.emoji_events,
            tr('il_c2f88479d7'),
            tr('il_d461a493a3'),
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStageItem(
    dynamic icon,
    String title,
    String duration,
    Color color,
  ) {
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
                : Text(icon, style: const TextStyle(fontSize: 18)),
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
                style: TextStyle(color: Colors.white70, fontSize: 14),
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
          _buildPrizeItem(
            '🥇',
            tr('il_6b25a21b71'),
            '50%',
            (prizePool * 0.5).toInt(),
            Colors.amber,
          ),
          const SizedBox(height: 15),
          _buildPrizeItem(
            '🥈',
            tr('il_aaeaebca09'),
            '30%',
            (prizePool * 0.3).toInt(),
            Colors.grey,
          ),
          const SizedBox(height: 15),
          _buildPrizeItem(
            '🥉',
            tr('il_bb8a4734dc'),
            '20%',
            (prizePool * 0.2).toInt(),
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeItem(
    String icon,
    String place,
    String percentage,
    int coins,
    Color color,
  ) {
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
            child: Text(icon, style: const TextStyle(fontSize: 24)),
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
                style: TextStyle(color: Colors.white70, fontSize: 14),
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
            tr('il_ddf8cb0f4a', namedArgs: {'coins': '$coins'}),
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
    if (hours == 1) return tr('il_f8b8883f0c');
    if (hours == 6) return tr('il_4105ae3b8a');
    if (hours == 24) return tr('il_fa665d95d2');
    if (hours == 72) return tr('il_360719440e');
    if (hours == 168) return tr('il_c8cc522340');
    return tr('il_fc64c33206', args: ['$hours']);
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
                  tr('il_f9ca2c929f'),
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
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('il_76144c407d'));
      }

      // Отримати дані користувача
      final userData = await _sb
          .from('profiles')
          .select('display_name,city,email')
          .eq('id', currentUser.id)
          .maybeSingle();
      if (userData == null) {
        throw Exception(tr('il_9ea4a0bb3d'));
      }
      final userName =
          (userData['display_name'] ??
                  userData['email']?.toString().split('@').first ??
                  tr('il_b764cdc0ea'))
              .toString();
      final userCity = (userData['city'] ?? _selectedCity).toString();

      // Розрахунок дат з окремими тривалостями
      final now = DateTime.now();
      final startDate = now;
      final submissionDeadline = now.add(Duration(hours: _recruitmentHours));
      final votingDeadline = submissionDeadline.add(
        Duration(hours: _submissionHours),
      );
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
        creatorId: currentUser.id,
        creatorName: userName,
        creatorVideoUrl: null, // Буде оновлено після завантаження відео
        city: userCity,
        entryFee: _selectedEntryFee,
        duration: challengeDurationDaysFromSpan(startDate, endDate),
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

      final challengeId = await _challengesRepo.createChallenge(challenge);

      if (challengeId != null) {
        // Надсилаємо інвайти обраним друзям (якщо обрали)
        if (_selectedInviteFriendIds.isNotEmpty) {
          try {
            await sl<NotificationService>().sendBulkChallengeInvitations(
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
            final creatorVideoUrl = await _uploadCreatorVideo(
              challengeId,
              currentUser.id,
              userName,
            );
            if (creatorVideoUrl != null && creatorVideoUrl.isNotEmpty) {
              print(
                'Creator video upload completed successfully with URL: $creatorVideoUrl',
              );

              // Оновлюємо челендж з URL відео творця
              await _sb
                  .from('challenges')
                  .update({'video_url': creatorVideoUrl})
                  .eq('id', challengeId);
              print(
                'Updated challenge $challengeId with video_url: $creatorVideoUrl',
              );
            } else {
              print('WARNING: Creator video upload returned null/empty URL');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('il_bf73be535c')),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            print('ERROR: Creator video upload failed: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr('il_7fe2d5cb6e', namedArgs: {'e': e.toString()}),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          print('WARNING: No video file selected for creator!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('il_32d2ecebbd')),
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
                    tr('il_ebee9d2f8e'),
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
                    ? tr('il_b80e3f2d55')
                    : tr('il_dff6be6f34'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
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
                    tr('il_11a6767d56'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        throw Exception(tr('il_0d4aef73b7'));
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
                  tr('il_7bdfebf56b', args: [e.toString()]),
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
              content: Text(tr('il_c5e57856db')),
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
          content: Text(tr('il_d1976cbb3b', args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadCreatorVideo(
    String challengeId,
    String userId,
    String authorName,
  ) async {
    if (_selectedVideoFile == null) {
      print('ERROR: _selectedVideoFile is null in _uploadCreatorVideo');
      return null;
    }

    try {
      print('Uploading creator video for challenge: $challengeId');

      print('Picked file name: ${_selectedVideoFile!.name}');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'creator_video_$timestamp.mp4';
      final objectPath = '$userId/$fileName';

      print('Storage path: $objectPath');

      String videoUrl;
      try {
        print('Reading video file as bytes...');
        final bytes = await _selectedVideoFile!.readAsBytes();
        if (bytes.length > _maxVideoBytes) {
          throw Exception(tr('il_8af3536c64'));
        }
        print('Video file size: ${bytes.length} bytes');

        videoUrl = await SupabaseAppStorage.uploadPublicBytes(
          Supabase.instance.client,
          bucket: SupabaseAppStorage.videos,
          path: objectPath,
          bytes: bytes,
          contentType: 'video/mp4',
        );
        print('Video URL obtained: $videoUrl');
      } catch (e) {
        print('ERROR during upload: $e');
        throw Exception(tr('il_cc3ca4e740', args: [e.toString()]));
      }

      // Зберігаємо відео створювача в submissions (без [videos]: окремий [video_url]).
      print('Saving creator video to submissions collection...');
      try {
        final creatorSubDesc = _descriptionController.text.trim();
        await _sb.from('challenge_submissions').upsert({
          'challenge_id': challengeId,
          'user_id': userId,
          'title': _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : tr('il_b51a6ac57e'),
          'video_url': videoUrl,
          'thumbnail_url': null,
          if (creatorSubDesc.isNotEmpty) 'description': creatorSubDesc,
        }, onConflict: 'challenge_id,user_id');
        print('Creator video saved to submissions collection');
      } catch (e) {
        print('ERROR saving to submissions collection: $e');
        throw Exception('Помилка збереження в submissions: $e');
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
            content: Text(
              tr('video_upload_error_detail', args: [e.toString()]),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null; // Помилка завантаження
    }
  }

  void _generateCreatorThumbnailInBackground(
    String challengeId,
    String videoUrl,
    String userId,
  ) {
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        print(
          '🎬 Starting creator thumbnail generation for challenge: $challengeId',
        );

        final sub = await _sb
            .from('challenge_submissions')
            .select('id')
            .eq('challenge_id', challengeId)
            .eq('user_id', userId)
            .maybeSingle();
        final submissionId = (sub?['id'] ?? '').toString();
        if (submissionId.isEmpty) {
          print('❌ No submission row for creator thumbnail');
          return;
        }

        final thumbnailService = ThumbnailService();
        final thumbnailUrl = await thumbnailService.generateSubmissionThumbnail(
          videoUrl: videoUrl,
          challengeId: challengeId,
          submissionId: submissionId,
          userId: userId,
        );
        if (thumbnailUrl != null) {
          await _sb
              .from('challenges')
              .update({
                'video_thumbnail_url': thumbnailUrl,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', challengeId);
          print('✅ Creator video thumbnail: $thumbnailUrl');
        }
      } catch (e) {
        print('❌ Background creator thumbnail generation error: $e');
      }
    });
  }
}
