import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen_sparkline.dart';
import 'package:flap_app/core/app_auth_context.dart';

@RoutePage()
class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);
  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final String? _uid = AppAuthContext.userId;
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
    if (_uid == null) return;
    try {
      // user
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid!).get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final history = List<Map<String, dynamic>>.from(data['ratingHistory'] ?? []);
      final now = DateTime.now();
      _history7 = history.where((h) {
        final ts = h['timestamp'];
        final dt = ts is Timestamp ? ts.toDate() : null;
        return dt != null && dt.isAfter(now.subtract(const Duration(days: 7)));
      }).toList()
        ..sort((a, b) {
          final at = a['timestamp'];
          final bt = b['timestamp'];
          if (at is Timestamp && bt is Timestamp) return at.compareTo(bt);
          return 0;
        });
      _history30 = history.where((h) {
        final ts = h['timestamp'];
        final dt = ts is Timestamp ? ts.toDate() : null;
        return dt != null && dt.isAfter(now.subtract(const Duration(days: 30)));
      }).toList()
        ..sort((a, b) {
          final at = a['timestamp'];
          final bt = b['timestamp'];
          if (at is Timestamp && bt is Timestamp) return at.compareTo(bt);
          return 0;
        });

      _counters = {
        'matchesPlayed': (data['matchesPlayed'] ?? 0) as num,
        'matchesWon': (data['wins'] ?? 0) as num,
        'videosUploaded': (data['videosUploaded'] ?? 0) as num,
      };

      // videos
      final vidsSnap = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: _uid)
          .limit(50)
          .get();
      final vids = vidsSnap.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        m['id'] = d.id;
        return m;
      }).toList();
      vids.sort((a, b) => ((b['views'] ?? 0) as int).compareTo((a['views'] ?? 0) as int));
      _topVideos = vids.take(5).toList();
    } finally {
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
        title: const Text('Статистика', style: TextStyle(color: Colors.white)),
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
                  _ratingBlock('Динаміка за 7 днів', _history7),
                  const SizedBox(height: 12),
                  _ratingBlock('Динаміка за 30 днів', _history30),
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
        Expanded(child: _counterCard('Матчі', _counters['matchesPlayed']!.toString(), Icons.sports_soccer, const Color(0xFF4caf50))),
        const SizedBox(width: 8),
        Expanded(child: _counterCard('Перемоги', _counters['matchesWon']!.toString(), Icons.emoji_events, const Color(0xFFFFC107))),
        const SizedBox(width: 8),
        Expanded(child: _counterCard('Відео', _counters['videosUploaded']!.toString(), Icons.videocam, const Color(0xFF2196F3))),
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
    final points = history.map<double>((h) => (h['overallRating'] ?? 0.0 as double).toDouble()).toList();
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
        const Text('Топ відео за переглядами', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
            child: const Text('Поки що немає відео', style: TextStyle(color: Colors.white70)),
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
                final title = (v['title'] ?? 'Відео') as String;
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





