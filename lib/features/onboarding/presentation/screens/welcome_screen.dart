import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/core/theme/app_colors.dart';
import 'package:flap_app/core/theme/app_spacing.dart';
import 'package:flap_app/shared/ui/app_button.dart';
import 'package:flap_app/shared/ui/app_card.dart';
import 'package:flap_app/shared/ui/app_chip.dart';
import 'package:flap_app/shared/ui/app_scaffold.dart';
import 'package:flap_app/utils/i18n.dart';

@RoutePage()
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      safeArea: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/logo/flap_logo.jpg', fit: BoxFit.cover),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('FLAP', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: AppSpacing.xs),
                ValueListenableBuilder<String>(
                  valueListenable: I18n.language,
                  builder: (context, lang, _) => Text(
                    'Feel Like A Pro\n${I18n.t('feel_like_a_pro')}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: ValueListenableBuilder<String>(
                    valueListenable: I18n.language,
                    builder: (context, lang, _) => Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppChip(
                          label: 'Українська',
                          selected: lang == 'uk',
                          onTap: () => I18n.setLanguage('uk'),
                        ),
                        AppChip(
                          label: 'English',
                          selected: lang == 'en',
                          onTap: () => I18n.setLanguage('en'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ValueListenableBuilder<String>(
                  valueListenable: I18n.language,
                  builder: (context, lang, _) => AppButton(
                    label: I18n.t('login'),
                    onPressed: () => context.pushRoute(LoginRoute()),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ValueListenableBuilder<String>(
                  valueListenable: I18n.language,
                  builder: (context, lang, _) => AppButton(
                    label: I18n.t('register'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.pushRoute(RegisterRoute()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
