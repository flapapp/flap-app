import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/utils/i18n.dart';

@RoutePage()
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Widget _buildLanguageButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
              )
            : null,
        color: selected ? null : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? Colors.white70 : Colors.white24,
          width: 1.4,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF4caf50).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D3D2A),
              FlapTheme.pitch,
              Color(0xFF0A2E22),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Image.asset(
                        'assets/logo/flap_logo.jpg',
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'FLAP',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 8,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: I18n.language,
                    builder: (context, lang, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLanguageButton(
                          label: 'Українська',
                          selected: lang == 'uk',
                          onTap: () => I18n.setLanguage('uk'),
                        ),
                        const SizedBox(width: 12),
                        _buildLanguageButton(
                          label: 'English',
                          selected: lang == 'en',
                          onTap: () => I18n.setLanguage('en'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<String>(
                    valueListenable: I18n.language,
                    builder: (context, lang, _) => Text(
                      'Feel Like A Pro\n${I18n.t('feel_like_a_pro')}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4caf50).withOpacity(0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () {
                              context.pushRoute(LoginRoute());
                            },
                            child: ValueListenableBuilder<String>(
                              valueListenable: I18n.language,
                              builder: (context, lang, _) => Text(
                                I18n.t('login'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () {
                              context.pushRoute(RegisterRoute());
                            },
                            child: ValueListenableBuilder<String>(
                              valueListenable: I18n.language,
                              builder: (context, lang, _) => Text(
                                I18n.t('register'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
