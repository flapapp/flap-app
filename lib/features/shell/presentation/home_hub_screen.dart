import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:flap_app/features/videos/presentation/screens/video_main_screen.dart';

/// Home tab: videos and challenges only (same as the former Watch tab).
@RoutePage()
class HomeHubScreen extends StatelessWidget {
  /// Same semantics as [VideoMainScreen.myContent] for deep links from profile.
  final String? myContent;

  const HomeHubScreen({super.key, this.myContent});

  @override
  Widget build(BuildContext context) {
    return VideoMainScreen(
      key: ValueKey<String>('home-${myContent ?? ''}'),
      myContent: myContent,
    );
  }
}
