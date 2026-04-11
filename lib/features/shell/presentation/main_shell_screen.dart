import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/utils/i18n.dart';

/// Primary signed-in shell: Home (feed + videos), Matches, Teams, Profile.
@RoutePage()
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AutoTabsRouter(
      routes: [
        HomeHubRoute(),
        MatchesRoute(),
        const TeamHubRoute(),
        AppProfileRoute(),
      ],
      transitionBuilder: (context, child, animation) =>
          FadeTransition(opacity: animation, child: child),
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        return Scaffold(
          backgroundColor: FlapTheme.pitch,
          body: child,
          bottomNavigationBar: NavigationBarTheme(
            data: theme.navigationBarTheme.copyWith(
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            ),
            child: NavigationBar(
              selectedIndex: tabsRouter.activeIndex,
              onDestinationSelected: tabsRouter.setActiveIndex,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: I18n.inline('Головна', 'Home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.sports_soccer_outlined),
                  selectedIcon: const Icon(Icons.sports_soccer),
                  label: I18n.t('matches'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups_outlined),
                  selectedIcon: const Icon(Icons.groups_rounded),
                  label: I18n.inline('Команди', 'Teams'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: I18n.inline('Профіль', 'Profile'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
