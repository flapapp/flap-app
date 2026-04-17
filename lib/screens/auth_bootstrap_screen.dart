import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../services/intro_seen_storage.dart';

/// First route after app start. Chooses guest vs authenticated entry and
/// replaces the stack so no “wrong” screen flashes longer than one frame.
@RoutePage()
class AuthBootstrapScreen extends StatefulWidget {
  const AuthBootstrapScreen({super.key});

  @override
  State<AuthBootstrapScreen> createState() => _AuthBootstrapScreenState();
}

class _AuthBootstrapScreenState extends State<AuthBootstrapScreen> {
  bool _didRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_didRoute) return;
    _didRoute = true;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          user = await FirebaseAuth.instance
              .authStateChanges()
              .first
              .timeout(const Duration(seconds: 2), onTimeout: () => null);
        } catch (_) {
          user = FirebaseAuth.instance.currentUser;
        }
      }
    } catch (_) {
      user = null;
    }

    if (!mounted) return;

    if (user != null) {
      await context.router.replaceAll([const ModeSelectionRoute()]);
    } else {
      final introDone = await IntroSeenStorage.hasCompletedIntro();
      if (!mounted) return;
      if (introDone) {
        await context.router.replaceAll([const WelcomeRoute()]);
      } else {
        await context.router.replaceAll([const IntroVideoRoute()]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
