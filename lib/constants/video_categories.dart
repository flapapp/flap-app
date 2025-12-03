import 'package:flutter/material.dart';

import '../utils/i18n.dart';

class VideoCategoryDefinition {
  final String id;
  final String labelUk;
  final String labelEn;
  final String descriptionUk;
  final String descriptionEn;
  final Color color;
  final List<String> keywords;
  final bool showInQuickFilters;

  const VideoCategoryDefinition({
    required this.id,
    required this.labelUk,
    required this.labelEn,
    required this.descriptionUk,
    required this.descriptionEn,
    required this.color,
    this.keywords = const [],
    this.showInQuickFilters = false,
  });

  String label() => I18n.inline(labelUk, labelEn);

  String description() => (descriptionUk.isEmpty && descriptionEn.isEmpty)
      ? ''
      : I18n.inline(descriptionUk, descriptionEn);
}

const List<VideoCategoryDefinition> kVideoCategories = [
  VideoCategoryDefinition(
    id: 'goal',
    labelUk: 'Гол',
    labelEn: 'Goal',
    descriptionUk: 'Фініші, хет-трики та вирішальні удари',
    descriptionEn: 'Finishes, hat-tricks and clutch goals',
    color: Color(0xFFFF7043),
    keywords: ['goal', 'гол', 'finish', 'удар', 'shot'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    id: 'shot_power',
    labelUk: 'Сила удару',
    labelEn: 'Shot power',
    descriptionUk: 'Постріли здалеку, рикошети, удари гарматою',
    descriptionEn: 'Long-range rockets and powerful drives',
    color: Color(0xFFD84315),
    keywords: ['shot power', 'power', 'сила', 'постріл', 'rocket'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    id: 'pass',
    labelUk: 'Пас',
    labelEn: 'Pass',
    descriptionUk: 'Комбінована гра, ассисти та стінки',
    descriptionEn: 'Combination play, assists and one-twos',
    color: Color(0xFF66BB6A),
    keywords: ['pass', 'пас', 'assist', 'комбінація'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    id: 'long_pass',
    labelUk: 'Довгий пас',
    labelEn: 'Long pass',
    descriptionUk: 'Переводи, навіси, діагоналі',
    descriptionEn: 'Switches of play, crosses and diagonals',
    color: Color(0xFF26C6DA),
    keywords: ['long pass', 'довг', 'cross', 'навіс', 'diag'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    id: 'dribble',
    labelUk: 'Дриблінг',
    labelEn: 'Dribbling',
    descriptionUk: 'Фінти, слаломи, обводки',
    descriptionEn: 'Skills, slaloms and ankle breakers',
    color: Color(0xFFAB47BC),
    keywords: ['dribble', 'дрибл', 'skill', 'фінт'],
  ),
  VideoCategoryDefinition(
    id: 'tackle',
    labelUk: 'Підкат',
    labelEn: 'Tackle',
    descriptionUk: 'Відбори, перехоплення, блоки',
    descriptionEn: 'Ball recoveries, interceptions, blocks',
    color: Color(0xFF795548),
    keywords: ['tackle', 'підкат', 'відбір', 'interception'],
  ),
  VideoCategoryDefinition(
    id: 'penalty',
    labelUk: 'Пенальті',
    labelEn: 'Penalty',
    descriptionUk: 'Удари й серії 11‑метрових',
    descriptionEn: 'Spot kicks and shootouts',
    color: Color(0xFFFFC107),
    keywords: ['penalty', 'пеналь', '11'],
  ),
  VideoCategoryDefinition(
    id: 'save',
    labelUk: 'Сейв',
    labelEn: 'Save',
    descriptionUk: 'Героичні сейви воротарів',
    descriptionEn: 'Heroic goalkeeper saves',
    color: Color(0xFF42A5F5),
    keywords: ['save', 'сейв', 'keeper', 'goalkeep', 'воротар'],
    showInQuickFilters: true,
  ),
  VideoCategoryDefinition(
    id: 'wall',
    labelUk: 'Стіна / стандарт',
    labelEn: 'Wall / set-piece',
    descriptionUk: 'Організація стандартів, стінки, бар’єри',
    descriptionEn: 'Set-piece walls and defensive organisation',
    color: Color(0xFF455A64),
    keywords: ['wall', 'стінк', 'barrier', 'free kick wall', 'set piece'],
  ),
  VideoCategoryDefinition(
    id: 'strategy',
    labelUk: 'Стратегія',
    labelEn: 'Strategy',
    descriptionUk: 'Тактичні розбори, побудова атаки чи оборони',
    descriptionEn: 'Tactical builds, schemes and analysis',
    color: Color(0xFF26A69A),
    keywords: ['strategy', 'стратег', 'тактик', 'scheme'],
  ),
  VideoCategoryDefinition(
    id: 'freestyle',
    labelUk: 'Фрістайл',
    labelEn: 'Freestyle',
    descriptionUk: 'Трюки, жонглювання та шоу',
    descriptionEn: 'Tricks, juggling and showtime',
    color: Color(0xFFFFCA28),
    keywords: ['freestyle', 'трюк', 'show'],
  ),
  VideoCategoryDefinition(
    id: 'technique',
    labelUk: 'Техніка (класика)',
    labelEn: 'Technique (legacy)',
    descriptionUk: 'Спадщина попередніх категорій',
    descriptionEn: 'Legacy upload category',
    color: Color(0xFF5C6BC0),
    keywords: ['technique', 'технік'],
  ),
  VideoCategoryDefinition(
    id: 'physics',
    labelUk: 'Фізика (класика)',
    labelEn: 'Physics (legacy)',
    descriptionUk: 'Силові вправи та кардіо',
    descriptionEn: 'Legacy physical drills',
    color: Color(0xFFEC407A),
    keywords: ['physics', 'фіз'],
  ),
  VideoCategoryDefinition(
    id: 'teamplay',
    labelUk: 'Командна гра (класика)',
    labelEn: 'Teamplay (legacy)',
    descriptionUk: 'Старі командні категорії',
    descriptionEn: 'Legacy teamplay category',
    color: Color(0xFF26A69A),
    keywords: ['team', 'команд'],
  ),
  VideoCategoryDefinition(
    id: 'other',
    labelUk: 'Інше',
    labelEn: 'Other',
    descriptionUk: 'Все, що не вписується в попередні категорії',
    descriptionEn: 'Anything that doesn\'t fit other groups',
    color: Color(0xFF90A4AE),
    keywords: ['other', 'інше'],
  ),
];

final Map<String, VideoCategoryDefinition> _videoCategoriesById = {
  for (final category in kVideoCategories) category.id: category,
};

VideoCategoryDefinition? videoCategoryById(String id) =>
    _videoCategoriesById[id];

VideoCategoryDefinition? detectVideoCategory(String raw) {
  final normalized = raw.toLowerCase().trim();
  if (_videoCategoriesById.containsKey(normalized)) {
    return _videoCategoriesById[normalized];
  }

  for (final category in kVideoCategories) {
    if (category.keywords.any((kw) => normalized.contains(kw.toLowerCase()))) {
      return category;
    }
  }
  return null;
}

String normalizeVideoCategoryValue(String raw) =>
    detectVideoCategory(raw)?.id ?? raw.toLowerCase();

Color videoCategoryColor(String raw) =>
    detectVideoCategory(raw)?.color ?? const Color(0xFF5C6BC0);

String videoCategoryLabel(String raw) =>
    detectVideoCategory(raw)?.label() ?? raw;

List<VideoCategoryDefinition> quickVideoCategories() =>
    kVideoCategories.where((c) => c.showInQuickFilters).toList();


