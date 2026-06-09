import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../../../widgets/video_preview_box.dart';
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
  // Single source of truth for the participant cap so the prize-distribution
  // preview, the persisted `max_participants` column and any future UI all
  // agree. Bumping this changes both the cap and the "if it fills up"
  // preview at the same time.
  static const int _kChallengeMaxParticipants = 100;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  ChallengeType _selectedType = ChallengeType.goal;
  ChallengeAudience _selectedAudience = ChallengeAudience.city;
  String _selectedCity = tr('kyiv_city');
  int _selectedEntryFee = 10;
  int _recruitmentHours = 24; // Default: 1 day (24 hours)
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

  List<String> _tagsFromLocalizedCsv(String trKey) {
    return tr(trKey)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> _typeKeywordTags(ChallengeType type) => _tagsFromLocalizedCsv(
        'challenge_type_keywords_${challengeTypeToSlug(type)}',
      );

  void _addSlugIfDescriptionMatches(
    List<String> tags,
    String title,
    String description,
    String scanKeywordsTrKey,
    String slug,
  ) {
    final haystack = '$title$description';
    for (final kw in _tagsFromLocalizedCsv(scanKeywordsTrKey)) {
      if (haystack.contains(kw.toLowerCase())) {
        tags.add(slug);
        return;
      }
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
      backgroundColor: FlapColors.bg,
      appBar: AppBar(
        backgroundColor: FlapColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 66,
        leadingWidth: 60,
        titleSpacing: 0,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlapColors.surface2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: FlapColors.border),
                ),
                child: const Icon(Icons.chevron_left,
                    color: FlapColors.text, size: 19),
              ),
            ),
          ),
        ),
        title: Text(
          tr('create_challenge'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Challenge video upload (9:16 design upload box)
                  _sectionTitle(Icons.movie_creation_outlined,
                      tr('il_af9d7e3d65')),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: _isCreating ? null : _showSourceChooser,
                      child: SizedBox(
                        width: 169,
                        height: 300,
                        child: _selectedVideoFile == null
                            ? CustomPaint(
                                painter: _UploadBoxPainter(),
                                child: Center(child: _uploadPlaceholder()),
                              )
                            : _buildPickedPreview(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Challenge details
                  _sectionTitle(Icons.edit_note_rounded, tr('il_d094b334d8')),
                  const SizedBox(height: 14),
                  _fieldLabel(tr('il_1b64eea021')),
                  _styledField(
                    controller: _titleController,
                    hint: tr('il_3ba12e8766'),
                    onChanged: (_) => setState(() {}),
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
                  const SizedBox(height: 16),
                  _fieldLabel(tr('il_d1b6cdb562')),
                  _styledField(
                    controller: _descriptionController,
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

                  const SizedBox(height: 26),

                  // Type + audience
                  _sectionTitle(Icons.tune_rounded, tr('settings')),
                  const SizedBox(height: 14),
                  _fieldLabel(tr('il_9a2597b919')),
                  _chipRow([
                    for (final category in kVideoCategories)
                      _choiceChip(
                        category.label(),
                        selected:
                            challengeTypeToSlug(_selectedType) == category.id,
                        onTap: () => setState(() {
                          _selectedType = parseChallengeType(category.id);
                        }),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  _fieldLabel(tr('il_3013c7e4fa')),
                  _chipRow([
                    for (final audience in ChallengeAudience.values)
                      _choiceChip(
                        _audienceLabel(audience),
                        selected: _selectedAudience == audience,
                        onTap: () =>
                            setState(() => _selectedAudience = audience),
                      ),
                  ]),

                  const SizedBox(height: 16),
                  _fieldLabel(tr('il_8ef4bf1d45')),
                  _chipRow([
                    for (final fee in _entryFees)
                      _choiceChip(
                        tr('il_eae716cab3', namedArgs: {'fee': '$fee'}),
                        selected: _selectedEntryFee == fee,
                        leadingIcon: Icons.monetization_on,
                        onTap: () => setState(() => _selectedEntryFee = fee),
                      ),
                  ]),

                  const SizedBox(height: 26),

                  // Invite friends
                  _sectionTitle(Icons.person_add_alt_1, tr('il_2614b42d84')),
                  const SizedBox(height: 14),
                  _buildInviteFriends(),

                  const SizedBox(height: 26),

                  // Stage durations
                  _sectionTitle(Icons.schedule_rounded, tr('il_8c56789629')),
                  const SizedBox(height: 14),
                  _buildDurationField(
                    label: tr('participant_recruitment'),
                    icon: Icons.groups_outlined,
                    accent: FlapColors.greenBright,
                    value: _recruitmentHours,
                    onChanged: (v) => setState(() => _recruitmentHours = v),
                  ),
                  const SizedBox(height: 12),
                  _buildDurationField(
                    label: tr('video_submission_stage'),
                    icon: Icons.video_library_outlined,
                    accent: FlapColors.amber,
                    value: _submissionHours,
                    onChanged: (v) => setState(() => _submissionHours = v),
                  ),
                  const SizedBox(height: 12),
                  _buildDurationField(
                    label: tr('voting'),
                    icon: Icons.how_to_vote_outlined,
                    accent: FlapColors.blue,
                    value: _votingHours,
                    onChanged: (v) => setState(() => _votingHours = v),
                  ),

                  const SizedBox(height: 26),

                  // Stage timeline preview
                  _sectionTitle(Icons.timeline_rounded, tr('il_d35fa97769')),
                  const SizedBox(height: 14),
                  _buildStageInfo(),

                  const SizedBox(height: 26),

                  // Prize distribution
                  _sectionTitle(
                      Icons.emoji_events_outlined, tr('il_54d3171fd8')),
                  const SizedBox(height: 14),
                  _buildPrizeDistribution(),

                  const SizedBox(height: 20),

                  // Help note
                  _buildHelpNote(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: FlapColors.bg,
          border: Border(top: BorderSide(color: FlapColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: GestureDetector(
            onTap: _isCreating ? null : _onCreatePressed,
            child: Opacity(
              opacity: _isCreating ? 0.6 : 1,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: FlapColors.primaryButton,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: FlapColors.onGreen,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tr('create_challenge'),
                            style: FlapText.sora(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: FlapColors.onGreen),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: FlapColors.onGreen, size: 19),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _audienceLabel(ChallengeAudience audience) {
    switch (audience) {
      case ChallengeAudience.friends:
        return tr('il_1419851d1b');
      case ChallengeAudience.city:
        return tr('il_eb5e5b054b');
      case ChallengeAudience.country:
        return tr('il_beba73d45d');
      default:
        return tr('il_42605c01fa');
    }
  }

  /// Confirms the entry-fee charge, then creates the challenge.
  Future<void> _onCreatePressed() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlapColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FlapColors.borderStrong),
        ),
        title: Text(
          tr('il_d743070540'),
          style: FlapText.sora(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          tr('challenge_create_fee_confirm',
              namedArgs: {'coins': '$_selectedEntryFee'}),
          style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              tr('cancel'),
              style: FlapText.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FlapColors.muted),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(dialogContext, true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: FlapColors.primaryButton,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tr('confirm'),
                style: FlapText.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FlapColors.onGreen),
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _createChallenge();
    }
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

  // ── Design helpers ─────────────────────────────────────────────────────

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FlapColors.green.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: FlapColors.green.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 16, color: FlapColors.greenBright),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: FlapText.sora(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: FlapText.sora(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: FlapColors.muted),
      ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: FlapText.sora(fontSize: 14),
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: FlapText.sora(fontSize: 14, color: FlapColors.muted),
        filled: true,
        fillColor: const Color(0x09FFFFFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlapColors.green),
        ),
        errorStyle: FlapText.sora(fontSize: 11.5, color: FlapColors.red),
      ),
    );
  }

  /// A horizontally scrolling chip row.
  Widget _chipRow(List<Widget> chips) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _choiceChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
    IconData? leadingIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? FlapColors.green.withValues(alpha: 0.16)
              : FlapColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? FlapColors.green.withValues(alpha: 0.5)
                : FlapColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon,
                  size: 14,
                  color: selected ? FlapColors.gold : FlapColors.muted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: FlapText.sora(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? FlapColors.greenBright : FlapColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteFriends() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadMyFriends(),
      builder: (context, snapshot) {
        final friends = snapshot.data ?? const <Map<String, dynamic>>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FlapColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FlapColors.border),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: FlapColors.muted),
            ),
          );
        }
        if (friends.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: FlapColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FlapColors.border),
            ),
            child: Text(
              tr('il_3f6a83aa65'),
              style: FlapText.sora(fontSize: 13, color: FlapColors.muted),
            ),
          );
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: FlapColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlapColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(6),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final f = friends[index];
              final id = f['id'] as String;
              final name = (f['displayName'] ?? f['name'] ?? tr('il_b512d97e7c'))
                  .toString();
              final photoUrl =
                  (f['avatarUrl'] ?? f['photoUrl'] ?? '').toString();
              final position = (f['position'] ?? f['role'] ?? '').toString();
              final rating =
                  ((f['rating'] ?? f['averageRating'] ?? 0) as num).toDouble();
              final selected = _selectedInviteFriendIds.contains(id);

              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedInviteFriendIds.remove(id);
                  } else {
                    _selectedInviteFriendIds.add(id);
                  }
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? FlapColors.green.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? FlapColors.green.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      PlayerAvatarButton(
                        userId: id,
                        displayName: name,
                        avatarUrl: photoUrl,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlapText.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (position.isNotEmpty || rating > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (position.isNotEmpty) ...[
                                    Flexible(
                                      child: Text(
                                        position,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: FlapText.sora(
                                            fontSize: 11.5,
                                            color: FlapColors.muted),
                                      ),
                                    ),
                                    if (rating > 0) const SizedBox(width: 8),
                                  ],
                                  if (rating > 0) ...[
                                    const Icon(Icons.star,
                                        color: FlapColors.gold, size: 12),
                                    const SizedBox(width: 2),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: FlapText.sora(
                                          fontSize: 11.5,
                                          color: FlapColors.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? FlapColors.green
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? FlapColors.green
                                : FlapColors.borderStrong,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                color: FlapColors.onGreen, size: 15)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// One stage's duration as a label + horizontal chip row of options.
  Widget _buildDurationField({
    required String label,
    required IconData icon,
    required Color accent,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      FlapText.sora(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _chipRow([
            for (final d in _durations)
              _choiceChip(
                d['label'] as String,
                selected: value == d['hours'] as int,
                onTap: () => onChanged(d['hours'] as int),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildStageInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlapColors.borderStrong),
      ),
      child: Column(
        children: [
          _buildStageItem(
            Icons.groups_outlined,
            tr('participant_recruitment'),
            _formatDuration(_recruitmentHours),
            FlapColors.greenBright,
            isFirst: true,
          ),
          _buildStageItem(
            Icons.video_library_outlined,
            tr('video_submission_stage'),
            _formatDuration(_submissionHours),
            FlapColors.amber,
          ),
          _buildStageItem(
            Icons.how_to_vote_outlined,
            tr('voting'),
            _formatDuration(_votingHours),
            FlapColors.blue,
          ),
          _buildStageItem(
            Icons.emoji_events_outlined,
            tr('il_c2f88479d7'),
            tr('il_d461a493a3'),
            FlapColors.gold,
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// A vertical-timeline row: connector dot + line on the left, label + value.
  Widget _buildStageItem(
    IconData icon,
    String title,
    String duration,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connector column.
          Column(
            children: [
              SizedBox(
                width: 2,
                height: 10,
                child: isFirst
                    ? null
                    : const ColoredBox(color: FlapColors.borderStrong),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              Expanded(
                child: SizedBox(
                  width: 2,
                  child: isLast
                      ? null
                      : const ColoredBox(color: FlapColors.borderStrong),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: FlapText.sora(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    duration,
                    style:
                        FlapText.sora(fontSize: 12.5, color: FlapColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeDistribution() {
    // Honest "if it fills up" preview: cap × entry-fee. Replaces a hardcoded
    // ×20 multiplier that was unrelated to the actual participant cap.
    final maxPrizePool = computeChallengeMaxPrizePoolCoins(
      maxParticipants: _kChallengeMaxParticipants,
      entryFee: _selectedEntryFee,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlapColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              'challenge_create_prize_max_disclaimer',
              namedArgs: {'max': '$_kChallengeMaxParticipants'},
            ),
            style: FlapText.sora(fontSize: 11.5, color: FlapColors.muted)
                .copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 14),
          _buildPrizeItem(
            1,
            tr('il_6b25a21b71'),
            '50%',
            (maxPrizePool * 0.5).toInt(),
            FlapColors.gold,
          ),
          const SizedBox(height: 10),
          _buildPrizeItem(
            2,
            tr('il_aaeaebca09'),
            '30%',
            (maxPrizePool * 0.3).toInt(),
            const Color(0xFFC7CDD2),
          ),
          const SizedBox(height: 10),
          _buildPrizeItem(
            3,
            tr('il_bb8a4734dc'),
            '20%',
            (maxPrizePool * 0.2).toInt(),
            const Color(0xFFCD7F32),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeItem(
    int rank,
    String place,
    String percentage,
    int coins,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$rank',
            style: FlapText.cond(
                fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place,
                style:
                    FlapText.sora(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                percentage,
                style: FlapText.sora(fontSize: 12, color: FlapColors.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: FlapColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: FlapColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on,
                  size: 13, color: FlapColors.gold),
              const SizedBox(width: 5),
              Text(
                tr('il_ddf8cb0f4a', namedArgs: {'coins': '$coins'}),
                style: FlapText.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FlapColors.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: FlapColors.muted, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('il_7a26875758'),
                style: FlapText.sora(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('il_b288ca1f0f') +
                tr('il_82a07f2980', args: ['$_selectedEntryFee']) +
                tr('il_c96602cb3a', args: ['${_selectedEntryFee * 20}']) +
                tr('il_f1b4cbd59c',
                    args: ['${(_selectedEntryFee * 20 * 0.5).toInt()}']) +
                tr('il_0b24b4d5e6',
                    args: ['${(_selectedEntryFee * 20 * 0.3).toInt()}']) +
                tr('il_1f74dfdb89',
                    args: ['${(_selectedEntryFee * 20 * 0.2).toInt()}']),
            style: FlapText.sora(
                fontSize: 12, color: FlapColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Upload box (9:16 design `.uploadbox`) ──────────────────────────────

  Widget _uploadPlaceholder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FlapColors.green.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FlapColors.green.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.videocam_rounded,
              color: FlapColors.greenBright, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          tr('il_7d7eb7441c'),
          textAlign: TextAlign.center,
          style: FlapText.sora(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            tr('il_2186dc395e'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: FlapColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildPickedPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPreviewBox(
            key: ValueKey(_selectedVideoFile!.path),
            videoUrl: _selectedVideoFile!.path,
            aspectRatio: 9 / 16,
            borderRadius: 18,
            showPlayIcon: false,
            placeholderColor: const Color(0xFF0D1A15),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF070A08).withValues(alpha: 0.85),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 11,
            right: 11,
            bottom: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedVideoFile!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.sora(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('il_79906b4600'),
                  style: FlapText.sora(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFCDD4CE)),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: FlapColors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: FlapColors.onGreen, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showSourceChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: FlapColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              _chooserRow(
                icon: Icons.photo_library_outlined,
                label: tr('il_352cfc749e'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickVideo(fromCamera: false);
                },
              ),
              const SizedBox(height: 8),
              _chooserRow(
                icon: Icons.videocam_outlined,
                label: tr('il_03494b0d1f'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickVideo(fromCamera: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chooserRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: FlapColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlapColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FlapColors.green.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
                border:
                    Border.all(color: FlapColors.green.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 19, color: FlapColors.greenBright),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: FlapText.sora(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
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

      // Load user profile
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

      // Compute dates from stage durations
      final now = DateTime.now();
      final startDate = now;
      final submissionDeadline = now.add(Duration(hours: _recruitmentHours));
      final votingDeadline = submissionDeadline.add(
        Duration(hours: _submissionHours),
      );
      final endDate = votingDeadline.add(Duration(hours: _votingHours));

      // No `prizePool` carried on the entity: the canonical pot is always
      // `participant_count × entry_fee` derived live from the database (see
      // `computeChallengePrizePoolCoins`). Persisting a snapshot here would
      // re-introduce drift between the create preview and the live cards.
      final challenge = Challenge(
        id: '', // Assigned server-side
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        audience: _selectedAudience,
        creatorId: currentUser.id,
        creatorName: userName,
        creatorVideoUrl: null, // Set after video upload
        city: userCity,
        entryFee: _selectedEntryFee,
        duration: challengeDurationDaysFromSpan(startDate, endDate),
        createdAt: now,
        startDate: startDate,
        submissionDeadline: submissionDeadline,
        votingDeadline: votingDeadline,
        endDate: endDate,
        status: ChallengeStatus.submission,
        maxParticipants: _kChallengeMaxParticipants,
        currentParticipants: 0,
        prizePool: 0,
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
        // Send invites to selected friends (if any)
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

        // Then upload creator video
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

              // Update challenge with creator video URL
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
        // Show success message and prompt about video upload
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: FlapColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: FlapColors.borderStrong),
              ),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FlapColors.green.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle,
                        color: FlapColors.greenBright, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('il_ebee9d2f8e'),
                      style: FlapText.sora(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: Text(
                _selectedVideoFile != null
                    ? tr('il_b80e3f2d55')
                    : tr('il_dff6be6f34'),
                style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
              ),
              actions: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: FlapColors.primaryButton,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tr('il_11a6767d56'),
                      style: FlapText.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FlapColors.onGreen),
                    ),
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
      // Show error
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

    // Type and keyword tags
    tags.add(_typeTagValue(_selectedType));
    tags.addAll(_typeKeywordTags(_selectedType));

    // Add city
    tags.add(_selectedCity.toLowerCase());

    // Add tags from title and description (localized keywords → canonical slugs)
    final title = _titleController.text.toLowerCase();
    final description = _descriptionController.text.toLowerCase();
    _addSlugIfDescriptionMatches(
      tags,
      title,
      description,
      'challenge_desc_scan_dribbling',
      challengeTypeToSlug(ChallengeType.dribbling),
    );
    _addSlugIfDescriptionMatches(
      tags,
      title,
      description,
      'challenge_desc_scan_shot',
      challengeTypeToSlug(ChallengeType.goal),
    );
    _addSlugIfDescriptionMatches(
      tags,
      title,
      description,
      'challenge_desc_scan_pass',
      challengeTypeToSlug(ChallengeType.pass),
    );
    _addSlugIfDescriptionMatches(
      tags,
      title,
      description,
      'challenge_desc_scan_goalkeeper',
      challengeTypeToSlug(ChallengeType.save),
    );
    _addSlugIfDescriptionMatches(
      tags,
      title,
      description,
      'challenge_desc_scan_defending',
      challengeTypeToSlug(ChallengeType.defending),
    );

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

      // Save creator video in submissions (no videos relation: standalone video_url).
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
        throw Exception(
          tr(
            'challenge_submission_save_error',
            namedArgs: {'error': e.toString()},
          ),
        );
      }

      print('Successfully uploaded creator video: $videoUrl');

      // Generate creator video thumbnail in the background
      _generateCreatorThumbnailInBackground(challengeId, videoUrl, userId);

      return videoUrl; // Return video URL
    } catch (e) {
      print('Error uploading creator video: $e');

      // Show error to user
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

      return null; // Upload failed
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
          print('[challenge_create] ERROR: No submission row for creator thumbnail');
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
          print('[challenge_create] Creator video thumbnail: $thumbnailUrl');
        }
      } catch (e) {
        print('[challenge_create] ERROR background creator thumbnail generation: $e');
      }
    });
  }
}

/// Diagonal striped fill + dashed border for the upload box (design `.uploadbox`).
class _UploadBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(18));

    canvas.save();
    canvas.clipRRect(rrect);
    // Base + 16px diagonal stripes (135deg).
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0D1A15));
    final stripe = Paint()
      ..color = const Color(0xFF11201A)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;
    for (double x = -size.height; x < size.width + size.height; x += 32) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), stripe);
    }
    canvas.restore();

    // 1.5px dashed border (border-strong).
    final border = Path()..addRRect(rrect.deflate(0.75));
    final paint = Paint()
      ..color = const Color(0x29FFFFFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final metric in border.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += 11; // 6 dash + 5 gap
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
