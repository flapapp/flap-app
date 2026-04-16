import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/theme/app_colors.dart';
import 'package:flap_app/core/theme/app_spacing.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/utils/i18n.dart';

@RoutePage()
class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  bool _navigated = false;
  bool _imageReady = false;
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
    // precacheImage uses MediaQuery via context — must run after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(AssetImage(_startupImage), context).whenComplete(() {
        if (mounted) {
          setState(() => _imageReady = true);
        }
      });
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _navigateToWelcome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final isAuthenticated = AppAuthContext.repository?.currentUser != null;
    if (isAuthenticated) {
      context.replaceRoute(const MainShellRoute());
      return;
    }
    context.replaceRoute(const WelcomeRoute());
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (_) => _navigateToWelcome(),
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
                    color: AppColors.bgBase,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.textSecondary),
                    ),
                  ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                  bottom: media.padding.bottom + AppSpacing.xl,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                        'Feel Like A Pro',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    Text(
                      I18n.inline(
                        'Натисніть будь-яку клавішу або торкніться екрана',
                        'Press any key or tap anywhere to continue',
                      ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                    ),
                  ],
                ),
              ),
              Positioned(
                  top: media.padding.top + AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      backgroundColor: AppColors.bgHover.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: _navigateToWelcome,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(I18n.inline('Далі', 'Continue')),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

