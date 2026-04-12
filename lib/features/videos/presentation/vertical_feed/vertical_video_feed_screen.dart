import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/features/videos/domain/entities/library_video.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/features/videos/presentation/vertical_feed/widgets/vertical_feed_video_page.dart';
import 'package:flap_app/utils/i18n.dart';

/// Full-screen vertical video feed; lives under [VideoMainScreen] body (no nested [Scaffold]).
class VerticalVideoFeedScreen extends StatefulWidget {
  const VerticalVideoFeedScreen({
    super.key,
    this.forUserId,
    this.prepareVideos,
    this.scopeKey,
  });

  /// Passed to [VideosRepository.watchLibraryVideos] (`null` = entire library).
  final String? forUserId;

  /// Optional filter/sort (e.g. [VideoMainScreen]'s `_filterAndSortVideoDocs`).
  final List<LibraryVideo> Function(List<LibraryVideo> raw)? prepareVideos;

  /// When this changes (e.g. All ↔ Trending), the page index resets to 0.
  final String? scopeKey;

  @override
  State<VerticalVideoFeedScreen> createState() => _VerticalVideoFeedScreenState();
}

class _VerticalVideoFeedScreenState extends State<VerticalVideoFeedScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  Stream<List<LibraryVideo>>? _libraryStream;
  String? _streamForUserId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant VerticalVideoFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forUserId != oldWidget.forUserId) {
      _libraryStream = null;
      _streamForUserId = null;
      _resetToFirstPage();
    } else if (widget.scopeKey != oldWidget.scopeKey) {
      _resetToFirstPage();
    }
  }

  void _resetToFirstPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _currentIndex = 0);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Stream<List<LibraryVideo>> _feedStream(BuildContext context) {
    final uid = widget.forUserId;
    if (_streamForUserId != uid) {
      _streamForUserId = uid;
      _libraryStream = null;
    }
    return _libraryStream ??=
        context.read<VideosRepository>().watchLibraryVideos(forUserId: uid, limit: 400);
  }

  double _bottomOverlayPadding(BuildContext context) {
    // Tab shell already clears the bottom bar; only respect system insets here.
    return MediaQuery.paddingOf(context).bottom;
  }

  static bool _excludeFromFeed(LibraryVideo v) {
    final title = v.title.trim();
    final description = v.description.trim();
    if (title == 'Відео створювача' ||
        title == 'Відео челенджу' ||
        title == 'Challenge video' ||
        description == 'Відео челенджу' ||
        description == 'Challenge video') {
      return true;
    }
    return false;
  }

  static List<LibraryVideo> _defaultPrepare(List<LibraryVideo> raw) {
    final list = raw
        .where((v) => v.videoUrl.trim().isNotEmpty)
        .where((v) => !_excludeFromFeed(v))
        .toList();
    list.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return list;
  }

  List<LibraryVideo> _prepare(List<LibraryVideo> raw) {
    final fn = widget.prepareVideos ?? _defaultPrepare;
    return fn(raw).where((v) => v.videoUrl.trim().isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = _bottomOverlayPadding(context);

    return ColoredBox(
      color: FlapTheme.pitch,
      child: StreamBuilder<List<LibraryVideo>>(
        stream: _feedStream(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: FlapTheme.accent),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      I18n.inline('Не вдалося завантажити відео', 'Could not load videos'),
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _libraryStream = null),
                      child: Text(I18n.inline('Спробувати знову', 'Try again')),
                    ),
                  ],
                ),
              ),
            );
          }

          final videos = _prepare(snapshot.data ?? []);

          if (videos.isNotEmpty) {
            final safeIndex = _currentIndex.clamp(0, videos.length - 1);
            if (safeIndex != _currentIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _currentIndex = safeIndex);
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(safeIndex);
                }
              });
            }
          }

          if (videos.isEmpty) {
            return Center(
              child: Text(
                I18n.inline('Поки немає відео у стрічці', 'No videos in the feed yet'),
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          final displayIndex =
              videos.isEmpty ? 0 : _currentIndex.clamp(0, videos.length - 1);

          return PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: videos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final hold = (index - displayIndex).abs() <= 1;
              final video = videos[index];
              return VerticalFeedVideoPage(
                key: ValueKey(video.id),
                video: video,
                isActive: index == displayIndex,
                shouldHoldPlayer: hold,
                bottomOverlayPadding: bottomPad,
              );
            },
          );
        },
      ),
    );
  }
}
