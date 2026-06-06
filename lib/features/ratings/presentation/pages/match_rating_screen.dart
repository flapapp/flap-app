import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../../theme/flap_tokens.dart';
import '../../domain/repositories/ratings_repository.dart';
import '../../../matches/data/models/match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flap_app/core/auth/app_auth.dart';

enum RatingMode { simple, advanced }

@RoutePage()
class MatchRatingScreen extends StatefulWidget {
  final Match match;
  
  const MatchRatingScreen({
    Key? key,
    required this.match,
  }) : super(key: key);

  @override
  _MatchRatingScreenState createState() => _MatchRatingScreenState();
}

class _MatchRatingScreenState extends State<MatchRatingScreen> {
  RatingsRepository get _ratingRepo => sl<RatingsRepository>();
  final SupabaseClient _sb = Supabase.instance.client;
  
  // Per-player scores
  Map<String, Map<String, double>> _playerRatings = {};
  
  // Rating criteria
  final List<String> _criteria = [
'technical',    // Technique
'physical',     // Physical
'tactical',     // Tactical
'teamwork',     // Team play
  ];
  
  List<String> get _criteriaLabels => [
    tr('il_76391b2aee'),
    tr('il_83191d2bd8'),
    tr('il_385d0084c8'),
    tr('il_55d3394671'),
  ];

  RatingMode _mode = RatingMode.advanced;
  final Map<String, double> _simpleRating = {}; // playerId -> 0..5
  final Set<String> _touched = {}; // players the user has actively rated

  IconData _criterionIcon(String criterion) {
    switch (criterion) {
      case 'technical':
        return Icons.sports_soccer;
      case 'physical':
        return Icons.local_fire_department;
      case 'tactical':
        return Icons.insights;
      case 'teamwork':
        return Icons.groups;
      default:
        return Icons.star_rounded;
    }
  }

  /// Tap-to-rate 1–5 star row (design `.stars`).
  Widget _stars(double value, ValueChanged<int> onTap, {double size = 26}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value.round();
        return GestureDetector(
          onTap: () => onTap(i + 1),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled ? FlapColors.gold : const Color(0x29FFFFFF),
            ),
          ),
        );
      }),
    );
  }
  
  
  Widget _modeSegment(String label, RatingMode mode) {
    final on = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? const Color(0x1AFFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: FlapText.sora(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: on ? FlapColors.text : FlapColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSubmitting = false;
  // User profile cache (displayName, photoUrl)
final Map<String, Map<String, String>> _userCache = {};

Future<Map<String, String>> _getUserProfile(String userId) async {
  if (_userCache.containsKey(userId)) {
    return _userCache[userId]!;
  }
  try {
    final row = await _sb
        .from('profiles')
        .select('display_name, avatar_url')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      _userCache[userId] = const {};
      return const {};
    }
final String displayName = (row['display_name'] as String?)?.trim() ?? '';
final String avatarUrl = (row['avatar_url'] as String?)?.trim() ?? '';
final profile = <String, String>{
  'displayName': displayName,
  'avatarUrl': avatarUrl,
};
_userCache[userId] = profile;
return profile;
  } catch (_) {
    _userCache[userId] = const {};
    return const {};
  }
}
  
    @override
void initState() {
  super.initState();
  
  // Load players regardless of match status
  // Status validated when saving ratings
  _initializeRatings();
}
  
    Future<void> _initializeRatings() async {
    // Initialize ratings for all players
    // Fallback to participants when teamA/teamB missing
    _playerRatings.clear();
    final currentUserId = AppAuth.currentUserId;
final participantsSet = widget.match.participants.toSet();
final allTeams = widget.match.allTeams;

List<String> basePlayers = [];
// Team matches list squad members via rosters; [participants] is often only the
// organizer. Intersecting with [participants] would drop every teammate.
var peersDerivedFromTeamRoster = false;

if (currentUserId != null && allTeams.isNotEmpty) {
  MatchTeamEntity? myTeam;
  try {
    myTeam = allTeams.firstWhere((team) => team.playerIds.contains(currentUserId));
  } catch (_) {
    myTeam = null;
  }

  if (myTeam != null) {
    basePlayers = myTeam.playerIds.where((id) => id != currentUserId).toList();
    peersDerivedFromTeamRoster = true;
  }
}

if (basePlayers.isEmpty) {
  basePlayers = widget.match.participants
      .where((id) => id != currentUserId)
      .toList();
  peersDerivedFromTeamRoster = false;
}

final playersToRate = peersDerivedFromTeamRoster
    ? basePlayers.toSet().toList()
    : basePlayers
          .where((id) => participantsSet.contains(id))
          .toSet()
          .toList();
final sanitizedPlayers = playersToRate.where((id) =>
  id != 'current_user_i' && id != 'current_user' && !id.startsWith('current_')
).toList();

// Exclude opponents already rated by this user (requires authenticated uid).
    final Set<String> alreadyRatedIds = {};
    if (currentUserId != null && currentUserId.isNotEmpty) {
      final existingRows = await _sb
          .from('match_player_ratings')
          .select('player_id')
          .eq('match_id', widget.match.id)
          .eq('rated_by', currentUserId);
      for (final d in existingRows as List<dynamic>) {
        final pid =
            ((d as Map<String, dynamic>)['player_id'] as String?) ?? '';
        if (pid.isNotEmpty) alreadyRatedIds.add(pid);
      }
    }

        for (final playerId in sanitizedPlayers) {
      if (currentUserId != null && playerId == currentUserId) {
        continue;
      }
      if (alreadyRatedIds.contains(playerId)) {
        continue;
      }
      _simpleRating[playerId] = 2.5;
      _playerRatings[playerId] = {};
      for (final criterion in _criteria) {
        _playerRatings[playerId]![criterion] = 2.5; // default mid rating
      }
    }
    setState(() {});
   
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlapColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: FlapColors.text,
        iconTheme: const IconThemeData(color: FlapColors.text),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('il_315b687966'),
              style: FlapText.sora(fontSize: 12, color: FlapColors.muted),
            ),
            Text(
              widget.match.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlapText.sora(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick / Detailed segmented toggle (design `.seg`).
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlapColors.border),
              ),
              child: Row(
                children: [
                  _modeSegment(tr('rating_quick'), RatingMode.simple),
                  _modeSegment(tr('rating_detailed'), RatingMode.advanced),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 4, 15, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _mode == RatingMode.simple
                    ? tr('rating_quick_hint')
                    : tr('rating_detailed_hint'),
                style: FlapText.sora(
                    fontSize: 12.5, color: FlapColors.muted, height: 1.4),
              ),
            ),
          ),

          Expanded(
            child: _playerRatings.isEmpty
                ? _buildEmptyRatingsState()
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: _playerRatings.length,
                    itemBuilder: (context, index) {
                      final playerId = _playerRatings.keys.elementAt(index);
                      final ratings = _playerRatings[playerId]!;
                      return _buildPlayerRatingCard(playerId, ratings);
                    },
                  ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00070A08), FlapColors.bg],
                stops: [0.0, 0.4],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 8, 15, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _playerRatings.isEmpty)
                        ? null
                        : _submitAllRatings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlapColors.green,
                      foregroundColor: FlapColors.onGreen,
                      disabledBackgroundColor: const Color(0x1A4CAF50),
                      disabledForegroundColor: FlapColors.muted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle:
                          FlapText.sora(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FlapColors.onGreen,
                            ),
                          )
                        : Text(_submitLabel()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _submitLabel() {
    final total = _playerRatings.length;
    final n = _touched.length;
    final base = tr('il_fa204511ae');
    return n > 0 ? '$base ($n/$total)' : base;
  }
  
  Widget _buildEmptyRatingsState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlapColors.border),
        ),
        child: Text(
          tr('il_432d30edd9'),
          style: FlapText.sora(color: FlapColors.muted, height: 1.4),
        ),
      ),
    );
  }
  
  // Player rating card
  Widget _buildPlayerRatingCard(String playerId, Map<String, double> ratings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x0BFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, String>>(
            future: _getUserProfile(playerId),
            builder: (context, snap) {
              final profile = snap.data ?? const {};
              final displayName = (profile['displayName'] ?? '').trim();
              final avatarUrl = (profile['avatarUrl'] ?? '').trim();
              final initials = (displayName.isNotEmpty
                      ? displayName
                          .split(' ')
                          .map((p) => p.isNotEmpty ? p[0] : '')
                          .take(2)
                          .join()
                      : playerId.substring(0, 2))
                  .toUpperCase();
              final name = displayName.isNotEmpty
                  ? displayName
                  : tr('il_9e4608e723', args: [
                      playerId.length > 8 ? playerId.substring(0, 8) : playerId
                    ]);
              return Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipOval(
                      child: avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _AvatarFallback(initials: initials),
                            )
                          : _AvatarFallback(initials: initials),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_mode == RatingMode.simple)
                    _stars(
                      _simpleRating[playerId] ?? 0,
                      (v) => setState(() {
                        _simpleRating[playerId] = v.toDouble();
                        _touched.add(playerId);
                      }),
                      size: 24,
                    ),
                ],
              );
            },
          ),
          if (_mode == RatingMode.advanced)
            ...List.generate(_criteria.length, (index) {
              final criterion = _criteria[index];
              final label = _criteriaLabels[index];
              final value = ratings[criterion] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(_criterionIcon(criterion),
                              size: 14, color: FlapColors.greenBright),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlapText.sora(
                                  fontSize: 12.5, color: FlapColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (value / 5).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [FlapColors.green, FlapColors.greenBright],
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _stars(
                      value,
                      (v) => setState(() {
                        _playerRatings[playerId]![criterion] = v.toDouble();
                        _touched.add(playerId);
                      }),
                      size: 18,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

    // Save all ratings
  Future<void> _submitAllRatings() async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      int successCount = 0;
      final List<String> failureMessages = [];
      final currentUserId = AppAuth.currentUserId;
      final idsToRate = _playerRatings.keys.where((id) => id != currentUserId).toList();
      final int totalCount = idsToRate.length;
      if (totalCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_d63bd4a9c8')),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      for (final playerId in idsToRate) {
        final ratings = _playerRatings[playerId]!;
        final double simple = _simpleRating[playerId] ?? 2.5;
        final Map<String, double> effectiveCriteria =
            (_mode == RatingMode.advanced)
                ? ratings
                : {'technical': simple, 'physical': simple, 'tactical': simple, 'teamwork': simple};
        try {
          await _ratingRepo.ratePlayerAfterMatch(
            matchId: widget.match.id,
            playerId: playerId,
            ratedBy: AppAuth.currentUserId!,
            criteria: effectiveCriteria,
          );
          successCount++;
          _playerRatings.remove(playerId);
          _simpleRating.remove(playerId);
        } catch (e) {
          final profile = _userCache[playerId] ?? const {};
          final playerName = (profile['displayName'] ?? '').toString().trim();
          failureMessages.add(
            '${playerName.isEmpty ? playerId : playerName}: ${_humanizeError(e)}',
          );
        }
      }
      setState(() {});

      if (successCount == totalCount) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_4641207a5f')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        final String headline = successCount == 0
            ? tr('il_b43497d860')
            : tr(
                'il_7e27449e19',
                namedArgs: {
                  'successCount': '$successCount',
                  'totalCount': '$totalCount',
                },
              );
        final String details = failureMessages.isNotEmpty ? '\n${failureMessages.first}' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$headline$details'),
            backgroundColor: successCount == 0 ? Colors.red : Colors.orange,
          ),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('il_051ce3d417', namedArgs: {'e': e.toString()}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  String _humanizeError(Object error) {
    final raw = error.toString();
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
  
  // Date formatting
  // ignore: unused_element
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return tr('il_adf8ee5f65', args: ['${difference.inDays}']);
    } else if (difference.inHours > 0) {
      return tr('il_7634d1849f', args: ['${difference.inHours}']);
    } else if (difference.inMinutes > 0) {
      return tr('il_e0b53645d6', args: ['${difference.inMinutes}']);
    } else {
      return tr('il_66f53417d3');
    }
  }
}
class _AvatarFallback extends StatelessWidget {
  final String initials;
  const _AvatarFallback({Key? key, required this.initials}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF616161),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
