import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/features/shell/presentation/shell_create_expandable_fab.dart';
import 'package:flap_app/features/teams/domain/repositories/teams_repository.dart';
import 'package:flap_app/features/teams/presentation/screens/team_create_screen.dart';
import 'package:flap_app/utils/i18n.dart';

/// Primary signed-in shell: Home, Matches, Create (center slot), Teams, Profile.
@RoutePage()
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  static const int _middleNavIndex = 2;
  static const double _navBarHeight = 72;

  bool _createMenuOpen = false;

  final PersistentTabController _tabController = PersistentTabController();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// [TabsRouter] uses 4 tabs; persistent bar uses 5 slots (create at index 2).
  int _persistentIndexForRouter(int routerIndex) {
    return routerIndex < _middleNavIndex ? routerIndex : routerIndex + 1;
  }

  int _routerIndexForPersistent(int persistentIndex) {
    assert(persistentIndex != _middleNavIndex);
    return persistentIndex < _middleNavIndex
        ? persistentIndex
        : persistentIndex - 1;
  }

  void _closeCreateMenu() {
    if (_createMenuOpen) {
      setState(() => _createMenuOpen = false);
    }
  }

  void _closeCreateThen(Future<void> Function() action) {
    setState(() => _createMenuOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await action();
    });
  }

  Future<void> _openTeamCreate() async {
    final user = AppAuthContext.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Увійдіть, щоб створити команду.', 'Sign in to create a team.'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final teams = await context.read<TeamsRepository>().fetchUserTeams(user.id);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeamCreateScreen(existingTeams: teams.length),
      ),
    );
  }

  void _scheduleSyncTabWithRouter(int routerIndex) {
    final persistent = _persistentIndexForRouter(routerIndex);
    if (_tabController.index == persistent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_tabController.index != persistent) {
        _tabController.jumpToTab(persistent);
      }
    });
  }

  static const Color _createOrange = Color(0xFFFF6B35);

  /// Inline with other tabs (not the raised style15 disc).
  static Widget _createTabBarButton() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _createOrange,
        boxShadow: [
          BoxShadow(
            color: _createOrange.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
    );
  }

  List<PersistentBottomNavBarItem> _navItems() {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.home_rounded, size: 24),
        inactiveIcon: const Icon(Icons.home_outlined, size: 24),
        title: I18n.inline('Головна', 'Home'),
        activeColorPrimary: FlapTheme.accent,
        inactiveColorPrimary: FlapTheme.onDarkMuted,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.sports_soccer, size: 24),
        inactiveIcon: const Icon(Icons.sports_soccer_outlined, size: 24),
        title: I18n.t('matches'),
        activeColorPrimary: FlapTheme.accent,
        inactiveColorPrimary: FlapTheme.onDarkMuted,
      ),
      PersistentBottomNavBarItem(
        onPressed: (_) {
          setState(() => _createMenuOpen = !_createMenuOpen);
        },
        icon: _createTabBarButton(),
        inactiveIcon: _createTabBarButton(),
        title: I18n.inline('Створити', 'Create'),
        activeColorPrimary: _createOrange,
        activeColorSecondary: Colors.white,
        inactiveColorPrimary: FlapTheme.onDarkMuted,
        iconSize: 24,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.groups_rounded, size: 24),
        inactiveIcon: const Icon(Icons.groups_outlined, size: 24),
        title: I18n.inline('Команди', 'Teams'),
        activeColorPrimary: FlapTheme.accent,
        inactiveColorPrimary: FlapTheme.onDarkMuted,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.person_rounded, size: 24),
        inactiveIcon: const Icon(Icons.person_outline_rounded, size: 24),
        title: I18n.inline('Профіль', 'Profile'),
        activeColorPrimary: FlapTheme.accent,
        inactiveColorPrimary: FlapTheme.onDarkMuted,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final overlayBottom = padding.bottom + _navBarHeight + 12;

    return AutoTabsRouter.builder(
      routes: [
        HomeHubRoute(),
        MatchesRoute(),
        const TeamHubRoute(),
        AppProfileRoute(),
      ],
      builder: (context, children, tabsRouter) {
        _scheduleSyncTabWithRouter(tabsRouter.activeIndex);

        return Scaffold(
          backgroundColor: FlapTheme.pitch,
          extendBody: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PersistentTabView(
                context,
                controller: _tabController,
                screens: [
                  children[0],
                  children[1],
                  const ColoredBox(
                    color: FlapTheme.pitch,
                    child: SizedBox.expand(),
                  ),
                  children[2],
                  children[3],
                ],
                items: _navItems(),
                backgroundColor: FlapTheme.surface.withValues(alpha: 0.94),
                navBarHeight: _navBarHeight,
                navBarStyle: NavBarStyle.style3,
                decoration: NavBarDecoration(
                  colorBehindNavBar: FlapTheme.pitch,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  useBackdropFilter: false,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                resizeToAvoidBottomInset: true,
                onItemSelected: (index) {
                  _closeCreateMenu();
                  if (index == _middleNavIndex) return;
                  tabsRouter.setActiveIndex(_routerIndexForPersistent(index));
                },
              ),
              if (_createMenuOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeCreateMenu,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: overlayBottom,
                  child: Center(
                    child: ShellCreateExpandableFab(
                      includeMainButton: false,
                      expanded: true,
                      onToggle: _closeCreateMenu,
                      onVideo: () => _closeCreateThen(() async {
                        await context.pushRoute(VideoUploadRoute());
                      }),
                      onChallenge: () => _closeCreateThen(() async {
                        await context.pushRoute(const ChallengeCreateRoute());
                      }),
                      onMatch: () => _closeCreateThen(() async {
                        await context.pushRoute(const CreateMatchRoute());
                      }),
                      onTeam: () => _closeCreateThen(_openTeamCreate),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
