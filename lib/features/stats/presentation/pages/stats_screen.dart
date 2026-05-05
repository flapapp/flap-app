import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../profile/presentation/widgets/sparkline_painter.dart';
import '../../domain/repositories/stats_repository.dart';
import 'package:flap_app/core/auth/app_auth.dart';

@RoutePage()
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsRepository get _statsRepo => sl<StatsRepository>();

  List<Map<String, dynamic>> _history7 = [];
  List<Map<String, dynamic>> _history30 = [];
  List<Map<String, dynamic>> _topVideos = [];
  Map<String, num> _counters = {
    'matchesPlayed': 0,
    'matchesWon': 0,
    'videosUploaded': 0,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final uid = AppAuth.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final snapshot = await _statsRepo.loadDashboard(uid);
      if (!mounted) return;
      setState(() {
        _history7 = snapshot.ratingHistory7d;
        _history30 = snapshot.ratingHistory30d;
        _topVideos = snapshot.topVideos;
        _counters = snapshot.counters;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('stats'), style: const TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _countersRow(),
                  const SizedBox(height: 16),
                  _ratingBlock(tr('stats_dynamics_7d'), _history7),
                  const SizedBox(height: 12),
                  _ratingBlock(tr('stats_dynamics_30d'), _history30),
                  const SizedBox(height: 16),
                  _topVideosBlock(),
                ],
              ),
            ),
    );
  }

  Widget _countersRow() {
    return Row(
      children: [
        Expanded(child: _counterCard(tr('stat_matches'), _counters['matchesPlayed']!.toString(), Icons.sports_soccer, const Color(0xFF4caf50))),
        const SizedBox(width: 8),
        Expanded(child: _counterCard(tr('stat_wins'), _counters['matchesWon']!.toString(), Icons.emoji_events, const Color(0xFFFFC107))),
        const SizedBox(width: 8),
        Expanded(child: _counterCard(tr('stat_videos_short'), _counters['videosUploaded']!.toString(), Icons.videocam, const Color(0xFF2196F3))),
      ],
    );
  }

  Widget _counterCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _ratingBlock(String title, List<Map<String, dynamic>> history) {
    final points = history.map<double>((h) {
      final raw = h['rating'] ?? h['overallRating'];
      return (raw as num?)?.toDouble() ?? 0.0;
    }).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              if (points.isNotEmpty)
                Text(points.last.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: 40, child: CustomPaint(painter: SparklinePainter(points))),
        ],
      ),
    );
  }

  Widget _topVideosBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('top_videos_by_views'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_topVideos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(tr('no_videos_yet'), style: const TextStyle(color: Colors.white70)),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _topVideos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final v = _topVideos[index];
                final thumb = (v['thumbnailUrl'] ?? '') as String;
                final title = (v['title'] ?? tr('video_fallback_title')) as String;
                final views = (v['views'] ?? 0).toString();
                return Container(
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: thumb.isNotEmpty
                            ? Image.network(thumb, width: 160, height: 110, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _videoThumbFallback(title))
                            : _videoThumbFallback(title),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.visibility, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(views, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _videoThumbFallback(String title) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
