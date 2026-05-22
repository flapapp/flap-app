import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/city_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_date.dart';
import '../../domain/entities/mode_navigation_target.dart';
import '../../domain/entities/mode_news_icon_kind.dart';
import '../../domain/entities/mode_news_item.dart';
import 'mode_dashboard_remote_datasource.dart';

class ModeDashboardRemoteDataSourceImpl implements ModeDashboardRemoteDataSource {
  ModeDashboardRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  String _profileDisplayName(Map<String, dynamic>? row) {
    if (row == null) {
      return tr('player');
    }
    final dn = row['display_name']?.toString().trim();
    if (dn != null && dn.isNotEmpty) {
      return dn;
    }
    final f = row['first_name']?.toString() ?? '';
    final l = row['last_name']?.toString() ?? '';
    final combined = '$f $l'.trim();
    if (combined.isNotEmpty) {
      return combined;
    }
    return tr('player');
  }

  Future<Map<String, dynamic>?> _profileRow(String userId) async {
    return _client
        .from('profiles')
        .select('display_name,first_name,last_name')
        .eq('id', userId)
        .maybeSingle();
  }

  DateTime _ts(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final v = asDateTimeOrNull(row[k]);
      if (v != null) {
        return v;
      }
    }
    return DateTime.now();
  }

  @override
  Future<ModeNewsItem?> fetchLatestMatchHighlight() async {
    try {
      final row = await _client
          .from('matches')
          .select(
            'id,title,status,scheduled_at,updated_at,created_at,organizer_id,city',
          )
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      final organizerId = row['organizer_id'] as String?;
      final org = organizerId != null ? await _profileRow(organizerId) : null;
      final organizer = _profileDisplayName(org);
      final matchTitle = (row['title'] ?? tr('il_25f50629be')).toString();
      final status = (row['status'] ?? 'open').toString();

      late final String subtitleKey;
      late final Map<String, String> subtitleNamedArgs;

      if (status == 'finished') {
        final fx = await _client
            .from('match_fixtures')
            .select('home_score,away_score')
            .eq('match_id', row['id'] as String)
            .eq('status', 'finished')
            .order('finished_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final hs = (fx?['home_score'] as num?)?.toInt();
        final as = (fx?['away_score'] as num?)?.toInt();
        if (hs != null && as != null) {
          subtitleKey = 'mode_news_match_subtitle_finished_score';
          subtitleNamedArgs = {
            'organizer': organizer,
            'matchTitle': matchTitle,
            'home': '$hs',
            'away': '$as',
          };
        } else {
          final t = _scheduledLabel(row['scheduled_at']);
          subtitleKey = 'mode_news_match_subtitle_created_kickoff';
          subtitleNamedArgs = {
            'organizer': organizer,
            'matchTitle': matchTitle,
            'time': t,
          };
        }
      } else {
        final t = _scheduledLabel(row['scheduled_at']);
        subtitleKey = 'mode_news_match_subtitle_open_kickoff';
        subtitleNamedArgs = {
          'organizer': organizer,
          'matchTitle': matchTitle,
          'time': t,
        };
      }

      return ModeNewsItem(
        titleRaw: matchTitle,
        subtitleKey: subtitleKey,
        subtitleNamedArgs: subtitleNamedArgs,
        iconKind: ModeNewsIconKind.soccer,
        accentArgb: 0xFF4caf50,
        timestamp: _ts(row, const ['updated_at', 'created_at']),
        navigationTarget: ModeNavigationTarget.matches,
        ctaLabelKey: 'il_100948655a',
      );
    } catch (_) {
      return null;
    }
  }

  String _scheduledLabel(dynamic raw) => formatLocalKickoffTime(raw);

  @override
  Future<ModeNewsItem?> fetchLatestVideoHighlight() async {
    try {
      final row = await _client
          .from('videos')
          .select('id,title,created_at,updated_at,user_id')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      final uid = row['user_id'] as String?;
      final authorRow = uid != null ? await _profileRow(uid) : null;
      final author = _profileDisplayName(authorRow);
      final rawTitle = row['title']?.toString().trim() ?? '';
      final title = rawTitle.isEmpty ? tr('il_3ef43ead3d') : rawTitle;
      return ModeNewsItem(
        titleRaw: title,
        subtitleKey: 'mode_news_video_subtitle',
        subtitleNamedArgs: {
          'author': author,
          'title': title,
        },
        iconKind: ModeNewsIconKind.video,
        accentArgb: 0xFFFF7043,
        timestamp: _ts(row, const ['created_at', 'updated_at']),
        navigationTarget: ModeNavigationTarget.videoMain,
        ctaLabelKey: 'il_9fedb611a8',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ModeNewsItem?> fetchLatestTeamHighlight() async {
    try {
      final row = await _client
          .from('teams')
          .select('id,name,city,created_at,updated_at')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      final teamName = (row['name'] ?? tr('il_1b9ed8eaa1')).toString();
      final rawCity = row['city']?.toString().trim() ?? '';
      final cityLabel =
          rawCity.isEmpty ? tr('il_3ec7dbf583') : localizeCity(rawCity);
      return ModeNewsItem(
        titleRaw: teamName,
        subtitleKey: 'mode_news_team_subtitle',
        subtitleNamedArgs: {'city': cityLabel},
        iconKind: ModeNewsIconKind.groups,
        accentArgb: 0xFF42a5f5,
        timestamp: _ts(row, const ['created_at', 'updated_at']),
        navigationTarget: ModeNavigationTarget.teams,
        ctaLabelKey: 'il_3d8889f3a9',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ModeNewsItem>> fetchRecentTeamJoins({int limit = 20}) async {
    try {
      final rows = await _client
          .from('team_members')
          .select('joined_at,user_id,team_id')
          .order('joined_at', ascending: false)
          .limit(limit);

      final list = rows as List<dynamic>;
      final out = <ModeNewsItem>[];
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final teamId = m['team_id'] as String?;
        final userId = m['user_id'] as String?;
        if (teamId == null || userId == null) {
          continue;
        }
        final teamRow = await _client
            .from('teams')
            .select('name')
            .eq('id', teamId)
            .maybeSingle();
        final userRow = await _profileRow(userId);
        final teamName = (teamRow?['name'] ?? tr('il_5985039f10')).toString();
        final userName = _profileDisplayName(userRow);
        out.add(
          ModeNewsItem(
            titleRaw: teamName,
            subtitleKey: 'mode_news_team_join_subtitle',
            subtitleNamedArgs: {'userName': userName},
            iconKind: ModeNewsIconKind.join,
            accentArgb: 0xFF26A69A,
            timestamp: _ts(m, const ['joined_at']),
            navigationTarget: ModeNavigationTarget.teams,
            ctaLabelKey: 'il_3d8889f3a9',
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
