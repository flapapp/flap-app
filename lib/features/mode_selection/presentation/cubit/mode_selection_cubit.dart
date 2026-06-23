import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/auth/app_auth.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../profile/domain/repositories/match_participation_stats_repository.dart';
import '../../domain/entities/mode_hero_stats.dart';
import '../../domain/repositories/mode_news_repository.dart';
import 'mode_selection_state.dart';

class ModeSelectionCubit extends Cubit<ModeSelectionState> {
  ModeSelectionCubit(
    this._newsRepository,
    this._matchStatsRepository,
    this._profileRepository,
  ) : super(const ModeSelectionState()) {
    _init();
  }

  final ModeNewsRepository _newsRepository;
  final MatchParticipationStatsRepository _matchStatsRepository;
  final ProfileRepository _profileRepository;

  final Random _random = Random();

  void _init() {
    final uid = AppAuth.currentUserId;
    if (uid != null) {
      _loadProfileDocumentIfNeeded(uid);
      _primeHeroStats(uid);
    }
    _updateGreetingFromProfile(uid);
    loadNews();
  }

  /// One-time fetch; skips if [ModeSelectionState.profileDocument] is already set.
  Future<void> _loadProfileDocumentIfNeeded(String userId) async {
    if (state.profileDocument != null) return;
    final p = await _profileRepository.fetchUserProfile(userId);
    emit(state.copyWith(profileDocument: p?.document));
  }

  /// Forces a profile refetch (e.g. after editing profile elsewhere).
  Future<void> refreshProfileDocument() async {
    final uid = AppAuth.currentUserId;
    if (uid == null) return;
    final p = await _profileRepository.fetchUserProfile(uid);
    emit(state.copyWith(profileDocument: p?.document));
    await _updateGreetingFromProfile(uid, preloaded: p);
  }

  Future<void> loadNews() async {
    emit(state.copyWith(newsLoading: true));
    try {
      final items = await _newsRepository.loadFeed(limit: 3);
      emit(state.copyWith(newsItems: items, newsLoading: false));
    } catch (_) {
      emit(state.copyWith(newsItems: const [], newsLoading: false));
    }
  }

  Future<void> refreshGreeting() async {
    await _updateGreetingFromProfile(AppAuth.currentUserId);
  }

  Future<void> _updateGreetingFromProfile(
    String? uid, {
    UserProfile? preloaded,
  }) async {
    final keys =
        _motivationPhraseKeys[_random.nextInt(_motivationPhraseKeys.length)];
    final baseGreeting = '${tr(keys.headKey)} ${tr(keys.tailKey)}';
    String greetingForUser(String name) =>
        baseGreeting.replaceAll('{name}', name);

    // Show the greeting immediately — it's local string data and must not wait
    // on the profile/stats network calls below. Use the already-cached profile
    // name if we have one (the phrase itself doesn't depend on the network).
    final cachedName = (state.profileDocument?['displayName'] ??
            state.profileDocument?['authorName'] ??
            state.profileDocument?['name'] ??
            tr('player'))
        .toString();
    emit(state.copyWith(greetingText: greetingForUser(cachedName)));

    if (uid == null) {
      emit(state.copyWith(ratingLineText: tr('il_70cd076bd7')));
      return;
    }

    final profile = preloaded ?? await _profileRepository.fetchUserProfile(uid);
    final data = profile?.document;
    final name = data != null
        ? (data['displayName'] ??
                data['authorName'] ??
                data['name'] ??
                tr('player'))
            .toString()
        : tr('player');

    var ratingStr = '0.00';
    if (data != null) {
      final r = data['rating'];
      if (r is num) ratingStr = r.toDouble().toStringAsFixed(2);
    }
    var matchesStr = '0';
    try {
      final raw = await _matchStatsRepository.loadFinishedMatchStats(uid);
      matchesStr =
          '${ModeHeroStats.fromParticipationMap(raw).finishedMatchesPlayed}';
    } catch (_) {}

    emit(
      state.copyWith(
        greetingText: greetingForUser(name),
        ratingLineText: tr(
          'il_9ed771006a',
          namedArgs: {'rating': ratingStr, 'matches': matchesStr},
        ),
      ),
    );
  }

  String? _heroUserId;
  void _primeHeroStats(String uid) {
    if (_heroUserId == uid && state.heroStatsFuture != null) {
      return;
    }
    _heroUserId = uid;
    final fut = _matchStatsRepository
        .loadFinishedMatchStats(uid)
        .then(ModeHeroStats.fromParticipationMap);
    emit(state.copyWith(heroStatsFuture: fut));
  }

}

class _MotivationPhraseKeys {
  final String headKey;
  final String tailKey;
  const _MotivationPhraseKeys(this.headKey, this.tailKey);
}

final List<_MotivationPhraseKeys> _motivationPhraseKeys =
    _buildMotivationPhraseKeys();

List<_MotivationPhraseKeys> _buildMotivationPhraseKeys() {
  const headKeys = <String>[
    'mode_motivation_head_0',
    'mode_motivation_head_1',
    'mode_motivation_head_2',
    'mode_motivation_head_3',
    'mode_motivation_head_4',
    'mode_motivation_head_5',
  ];
  const tailKeys = <String>[
    'mode_motivation_tail_0',
    'mode_motivation_tail_1',
    'mode_motivation_tail_2',
    'mode_motivation_tail_3',
    'mode_motivation_tail_4',
    'mode_motivation_tail_5',
    'mode_motivation_tail_6',
    'mode_motivation_tail_7',
    'mode_motivation_tail_8',
    'mode_motivation_tail_9',
  ];

  final result = <_MotivationPhraseKeys>[];
  for (final headKey in headKeys) {
    for (final tailKey in tailKeys) {
      result.add(_MotivationPhraseKeys(headKey, tailKey));
      if (result.length >= 60) {
        return result;
      }
    }
  }
  return result;
}
