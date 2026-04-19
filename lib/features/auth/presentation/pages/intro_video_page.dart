import 'dart:math';
import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/progress/progress_status.dart';
import '../../../../router/app_router.dart';
import '../bloc/auth_bloc.dart';

@RoutePage()
class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  bool _navigated = false;
  bool _imageReady = false;
  bool _precacheStarted = false;
  late final FocusNode _focusNode;
  late final String _startupImage;
  static const List<String> _startupImages = [
    'assets/startup/start_1.png',
    'assets/startup/start_2.png',
    'assets/startup/start_3.png',
    'assets/startup/start_4.png',
    'assets/startup/start_5.png',
    'assets/startup/start_6.png',
    'assets/startup/start_7.png',
    'assets/startup/start_8.png',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _startupImage = _startupImages[Random().nextInt(_startupImages.length)];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthEvent.introGateCheckRequested());
    });
  }

  void _startPrecacheIfNeeded() {
    if (_precacheStarted || !mounted) return;
    _precacheStarted = true;
    precacheImage(AssetImage(_startupImage), context).whenComplete(() {
      if (mounted) {
        setState(() => _imageReady = true);
      }
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _navigateToWelcome() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.read<AuthBloc>().add(const AuthEvent.introMarkCompletedRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.introGateProgress != current.introGateProgress ||
          previous.introShouldSkipToWelcome != current.introShouldSkipToWelcome ||
          previous.introMarkProgress != current.introMarkProgress,
      listener: (context, state) {
        if (state.introGateProgress == ProgressStatus.success &&
            state.introShouldSkipToWelcome == true) {
          context.router.replace(const WelcomeRoute());
          return;
        }
        if (state.introGateProgress == ProgressStatus.success &&
            state.introShouldSkipToWelcome == false) {
          _startPrecacheIfNeeded();
        }
        if (state.introMarkProgress == ProgressStatus.success) {
          context.router.replace(const WelcomeRoute());
        }
        if (state.introMarkProgress == ProgressStatus.failure &&
            state.introMarkFailure != null) {
          _navigated = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.introMarkFailure.toString())),
          );
        }
        if (state.introGateProgress == ProgressStatus.failure &&
            state.introGateFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.introGateFailure.toString())),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (p, c) =>
            p.introGateProgress != c.introGateProgress ||
            p.introMarkProgress != c.introMarkProgress,
        builder: (context, state) {
          final gateLoading =
              state.introGateProgress == ProgressStatus.loading;
          final gateFailed =
              state.introGateProgress == ProgressStatus.failure;
          final markLoading =
              state.introMarkProgress == ProgressStatus.loading;
          if (gateLoading) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            );
          }
          if (gateFailed) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.introGateFailure?.toString() ??
                            tr('il_ab827e3fe1'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.read<AuthBloc>().add(
                              const AuthEvent.introGateCheckRequested(),
                            ),
                        child: Text(tr('il_942087cc2d')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final media = MediaQuery.of(context);
          return Scaffold(
            backgroundColor: Colors.black,
            body: KeyboardListener(
              focusNode: _focusNode,
              onKeyEvent: (event) {
                if (event is KeyDownEvent) _navigateToWelcome();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _navigateToWelcome,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_imageReady)
                      Image.asset(
                        _startupImage,
                        fit: BoxFit.cover,
                      )
                    else
                      const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white70),
                        ),
                      ),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black26, Colors.black87],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: media.padding.bottom + 34,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Feel Like A Pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tr('il_94d0378bbe'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: media.padding.top + 16,
                      right: 16,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black45,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: markLoading ? null : _navigateToWelcome,
                        child: Text(tr('il_31fbef1625')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
