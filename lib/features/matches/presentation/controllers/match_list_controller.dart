import '../../data/models/match.dart';
import '../../domain/repositories/matches_repository.dart';

class MatchListFilters {
  const MatchListFilters({
    required this.selectedCity,
    required this.allCitiesLabel,
    required this.selectedLevel,
    required this.allLevelsLabel,
    required this.selectedTime,
    required this.anytimeLabel,
    required this.todayLabel,
    required this.tomorrowLabel,
    required this.weekLabel,
    required this.selectedSort,
    required this.searchQuery,
    required this.currentUserCity,
  });

  final String selectedCity;
  final String allCitiesLabel;
  final String selectedLevel;
  final String allLevelsLabel;
  final String selectedTime;
  final String anytimeLabel;
  final String todayLabel;
  final String tomorrowLabel;
  final String weekLabel;
  final String selectedSort;
  final String searchQuery;
  final String currentUserCity;
}

class MatchListController {
  const MatchListController(this._matchesRepository);

  final MatchesRepository _matchesRepository;

  Stream<List<Match>> getFilteredMatches(
    MatchListFilters filters, {
    required String Function(MatchLevel level) levelTextResolver,
  }) {
    return _matchesRepository.getAvailableMatches().map((matches) {
      final selectedCity = filters.selectedCity.trim();
      final filtered = matches.where((match) {
        if (selectedCity.isNotEmpty &&
            selectedCity != filters.allCitiesLabel &&
            match.city.trim().toLowerCase() != selectedCity.toLowerCase()) {
          return false;
        }

        if (filters.selectedLevel != filters.allLevelsLabel &&
            levelTextResolver(match.level) != filters.selectedLevel) {
          return false;
        }

        if (filters.selectedTime != filters.anytimeLabel) {
          final now = DateTime.now();
          final matchDate = match.date;
          final timeValue = filters.selectedTime;
          if (timeValue == filters.todayLabel) {
            if (!_isSameDay(matchDate, now)) return false;
          } else if (timeValue == filters.tomorrowLabel) {
            final tomorrow = now.add(const Duration(days: 1));
            if (!_isSameDay(matchDate, tomorrow)) return false;
          } else if (timeValue == filters.weekLabel) {
            final weekEnd = now.add(const Duration(days: 7));
            if (matchDate.isBefore(now) || matchDate.isAfter(weekEnd)) {
              return false;
            }
          }
        }

        if (filters.searchQuery.isNotEmpty) {
          final query = filters.searchQuery.toLowerCase();
          return match.title.toLowerCase().contains(query) ||
              match.description.toLowerCase().contains(query) ||
              match.location.toLowerCase().contains(query) ||
              match.city.toLowerCase().contains(query);
        }
        return true;
      }).toList();

      filtered.sort((a, b) {
        if (a.isUnplayedByTimeout != b.isUnplayedByTimeout) {
          return a.isUnplayedByTimeout ? 1 : -1;
        }

        if (filters.selectedSort == 'my_city' &&
            filters.currentUserCity.trim().isNotEmpty) {
          final aMine = a.city.trim().toLowerCase() ==
              filters.currentUserCity.trim().toLowerCase();
          final bMine = b.city.trim().toLowerCase() ==
              filters.currentUserCity.trim().toLowerCase();
          if (aMine != bMine) {
            return bMine ? 1 : -1;
          }
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return filtered;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
