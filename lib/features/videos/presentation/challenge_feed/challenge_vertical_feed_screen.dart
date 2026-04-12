import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/features/videos/presentation/challenge_feed/challenge_feed_page.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/utils/i18n.dart';

/// Full-screen vertical challenge feed (mirrors [VerticalVideoFeedScreen] / All tab).
class ChallengeVerticalFeedScreen extends StatefulWidget {
  const ChallengeVerticalFeedScreen({
    super.key,
    this.onlyMine = false,
    this.scopeKey = 'all',
  });

  final bool onlyMine;
  final String scopeKey;

  @override
  State<ChallengeVerticalFeedScreen> createState() => _ChallengeVerticalFeedScreenState();
}

class _ChallengeVerticalFeedScreenState extends State<ChallengeVerticalFeedScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant ChallengeVerticalFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey || oldWidget.onlyMine != widget.onlyMine) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentIndex = 0);
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _bottomOverlayPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = _bottomOverlayPadding(context);

    return ColoredBox(
      color: FlapTheme.pitch,
      child: StreamBuilder<List<Challenge>>(
        stream: context.read<ChallengeRepository>().watchChallenges(limit: 100),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                I18n.inline('Помилка: ${snapshot.error}', 'Error: ${snapshot.error}'),
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: FlapTheme.accent));
          }

          var challenges = snapshot.data ?? [];
          if (widget.onlyMine) {
            final uid = AppAuthContext.userId;
            challenges = uid == null
                ? <Challenge>[]
                : challenges.where((c) => c.creatorId == uid).toList();
          }
          challenges = challenges.take(20).toList();

          if (challenges.isEmpty) {
            return Center(
              child: Text(
                I18n.inline('Поки що немає челенджів', 'No challenges yet'),
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          final displayIndex = _currentIndex.clamp(0, challenges.length - 1);

          return PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: challenges.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final hold = (index - displayIndex).abs() <= 1;
              final ch = challenges[index];
              return ChallengeFeedPage(
                key: ValueKey<String>('challenge-feed-${ch.id}'),
                challenge: ch,
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
