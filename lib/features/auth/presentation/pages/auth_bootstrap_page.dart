import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/progress/progress_status.dart';
import '../../../../router/app_router.dart';
import '../../../../router/post_auth_navigation.dart';
import '../../domain/entities/startup_destination.dart';
import '../bloc/auth_bloc.dart';

/// First route after app start. Chooses guest vs authenticated entry and
/// replaces the stack so no “wrong” screen flashes longer than one frame.
@RoutePage()
class AuthBootstrapScreen extends StatefulWidget {
  const AuthBootstrapScreen({super.key});

  @override
  State<AuthBootstrapScreen> createState() => _AuthBootstrapScreenState();
}

class _AuthBootstrapScreenState extends State<AuthBootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthEvent.bootstrapRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current.bootstrapProgress == ProgressStatus.success &&
          current.bootstrapDestination != null,
      listener: (context, state) {
        final destination = state.bootstrapDestination!;
        switch (destination) {
          case StartupDestination.authenticated:
            resolvePostAuthInitialRoute().then((route) {
              if (!context.mounted) return;
              context.router.replaceAll([route]);
            });
          case StartupDestination.guestWelcome:
            context.router.replaceAll([const WelcomeRoute()]);
          case StartupDestination.guestIntro:
            context.router.replaceAll([const IntroVideoRoute()]);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (p, c) =>
            p.bootstrapProgress != c.bootstrapProgress ||
            p.bootstrapFailure != c.bootstrapFailure,
        builder: (context, state) {
          if (state.bootstrapProgress == ProgressStatus.failure &&
              state.bootstrapFailure != null) {
            final failure = state.bootstrapFailure!;
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        failure.when(
                          cache: () => tr('startup_storage_error'),
                          network: (m) => m ?? tr('startup_network_error'),
                          unexpected: (m) => m ?? tr('startup_failed'),
                          auth: (code, m) => m ?? code,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context
                            .read<AuthBloc>()
                            .add(const AuthEvent.bootstrapRequested()),
                        child: Text(tr('try_again')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const Scaffold(
            body: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
