import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:flap_app/core/router/app_router.dart';

/// Indices for [MainShellScreen] tab router (4 routes; the bar also has a center create slot).
abstract final class FlapMainTab {
  static const int home = 0;
  static const int matches = 1;
  static const int teams = 2;
  static const int profile = 3;
}

/// Switches an existing tab router or navigates to [MainShellRoute] focused on [index].
void flapOpenMainTab(
  BuildContext context,
  int index, {
  MatchesRoute? matchesRoute,
  HomeHubRoute? homeHubRoute,
}) {
  final i = index.clamp(0, 3);
  PageRouteInfo routeFor(int tab) {
    switch (tab) {
      case FlapMainTab.home:
        return homeHubRoute ?? HomeHubRoute();
      case FlapMainTab.matches:
        return matchesRoute ?? MatchesRoute();
      case FlapMainTab.teams:
        return const TeamHubRoute();
      case FlapMainTab.profile:
        return AppProfileRoute();
      default:
        return HomeHubRoute();
    }
  }

  try {
    AutoTabsRouter.of(context).setActiveIndex(i);
  } catch (_) {
    context.router.navigate(MainShellRoute(children: [routeFor(i)]));
  }
}
