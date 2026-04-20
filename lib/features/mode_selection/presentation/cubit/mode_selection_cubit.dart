import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../app_locale_access.dart';
import '../../../../core/auth/app_auth.dart';
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

  Future<void> _updateGreetingFromProfile(String? uid) async {
    final phrase = _motivationPhrases[_random.nextInt(_motivationPhrases.length)];
    if (uid == null) {
      emit(
        state.copyWith(
          greetingText: bilingual(phrase.ua, phrase.en),
          ratingLineText: tr('il_70cd076bd7'),
        ),
      );
      return;
    }

    final profile = await _profileRepository.fetchUserProfile(uid);
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
        greetingText: bilingual(
          phrase.ua.replaceAll('{name}', name),
          phrase.en.replaceAll('{name}', name),
        ),
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

class _LocalizedPair {
  final String ua;
  final String en;
  const _LocalizedPair(this.ua, this.en);
}

final List<_MotivationPhrase> _motivationPhrases = _buildMotivationPhrases();

class _MotivationPhrase {
  final String ua;
  final String en;

  const _MotivationPhrase({
    required this.ua,
    required this.en,
  });
}

List<_MotivationPhrase> _buildMotivationPhrases() {
  const heads = [
    _LocalizedPair('Грай', 'Play'),
    _LocalizedPair('Тренуйся', 'Train'),
    _LocalizedPair('Створюй моменти', 'Create moments'),
    _LocalizedPair('Палаєш', 'Burn bright'),
    _LocalizedPair('Дихай грою', 'Breathe the game'),
    _LocalizedPair('Керуєш темпом', 'Command the tempo'),
  ];
  const tails = [
    _LocalizedPair('на повну — поле відповість.', 'at full volume — the pitch will answer.'),
    _LocalizedPair('без страху — FLAP прикриє тил.', 'fearless — FLAP guards your back.'),
    _LocalizedPair('як чемпіон щодня.', 'like a champion every day.'),
    _LocalizedPair('з холодною головою й гарячим серцем.', 'with a cool head and a blazing heart.'),
    _LocalizedPair('тут і зараз — без пауз.', 'here and now — no pauses.'),
    _LocalizedPair('на рівні свого майбутнього.', 'at the level of your future self.'),
    _LocalizedPair('з повнотою контролю.', 'with total control.'),
    _LocalizedPair('у ритмі міста.', 'in the rhythm of the city.'),
    _LocalizedPair('за межами комфорту.', 'beyond the comfort zone.'),
    _LocalizedPair('якщо хочеш легендарних цифр.', 'if you want legendary numbers.'),
  ];

  final result = <_MotivationPhrase>[];
  for (final head in heads) {
    for (final tail in tails) {
      result.add(
        _MotivationPhrase(
          ua: '${head.ua} ${tail.ua}',
          en: '${head.en} ${tail.en}',
        ),
      );
      if (result.length == 60) {
        return result;
      }
    }
  }
  return result;
}
