import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../theme/flap_tokens.dart';
import '../features/auth/presentation/widgets/auth_widgets.dart';

@RoutePage()
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribe to the active locale so this whole screen re-localizes the
    // instant the language is switched. `tr()` does not register a dependency
    // on the locale, and auto_route caches this page, so without this read the
    // static text would stay in the old language until the route is rebuilt.
    context.locale;
    return Scaffold(
      backgroundColor: FlapColors.bg,
      body: Stack(
        children: [
          // Background ambience: green radial glow at top fading into the bg.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -1.0),
                  radius: 1.0,
                  colors: [Color(0x2E4CAF50), Color(0x00070A08)],
                  stops: [0.0, 0.5],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar — language toggle (right).
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [AuthLangToggle()],
                  ),
                ),
                // Logo, vertically centered in the free space.
                Expanded(child: Center(child: _logo())),
                // Hero copy.
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthEyebrow(tr('auth_eyebrow_welcome')),
                      const SizedBox(height: 13),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${tr('auth_hero_a')}\n'),
                            TextSpan(
                              text: tr('auth_hero_b'),
                              style: const TextStyle(
                                  color: FlapColors.greenBright),
                            ),
                          ],
                        ),
                        style: FlapText.cond(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: 0.3,
                        ).copyWith(),
                      ),
                      const SizedBox(height: 13),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 282),
                        child: Text(
                          tr('auth_welcome_sub'),
                          style: FlapText.sora(
                            color: FlapColors.muted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions.
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
                  child: Column(
                    children: [
                      AuthPrimaryButton(
                        label: tr('login'),
                        onTap: () => context.router.push(const LoginRoute()),
                      ),
                      const SizedBox(height: 12),
                      AuthGhostButton(
                        label: tr('register'),
                        onTap: () =>
                            context.router.push(const RegisterRoute()),
                      ),
                      const SizedBox(height: 12),
                      _legal(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: FlapColors.green.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/logo/flap_logo.jpg', fit: BoxFit.cover),
    );
  }

  Widget _legal() {
    return LegalAgreementText(
      prefix: tr('auth_legal_a'),
      connector: tr('auth_legal_and'),
      suffix: '.',
      textAlign: TextAlign.center,
      baseStyle: FlapText.sora(
        color: FlapColors.muted2,
        fontSize: 11.5,
        height: 1.5,
      ),
      linkStyle: FlapText.sora(
        color: FlapColors.muted,
        fontSize: 11.5,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
