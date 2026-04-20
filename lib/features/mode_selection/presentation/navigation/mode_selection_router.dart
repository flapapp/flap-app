import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../router/app_router.dart';
import '../../domain/entities/mode_navigation_target.dart';

extension ModeSelectionRouterX on BuildContext {
  void pushModeTarget(ModeNavigationTarget target) {
    switch (target) {
      case ModeNavigationTarget.matches:
        router.push(MatchesRoute());
        return;
      case ModeNavigationTarget.videoMain:
        router.push(VideoMainRoute());
        return;
      case ModeNavigationTarget.teams:
        router.push(const TeamHubRoute());
        return;
      case ModeNavigationTarget.notifications:
        router.push(const NotificationsRoute());
        return;
      case ModeNavigationTarget.profile:
        router.push(const ProfileRoute());
        return;
    }
  }
}
