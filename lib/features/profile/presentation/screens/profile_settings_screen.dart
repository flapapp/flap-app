import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/theme/app_colors.dart';
import 'package:flap_app/core/theme/app_spacing.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/tournaments/presentation/screens/tournaments_screen.dart';
import 'package:flap_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:flap_app/shared/ui/app_button.dart';
import 'package:flap_app/shared/ui/app_card.dart';
import 'package:flap_app/shared/ui/app_scaffold.dart';
import 'package:flap_app/shared/ui/app_top_bar.dart';
import 'package:flap_app/utils/i18n.dart';
import 'profile_creation_screen.dart';
import 'package:flap_app/core/app_auth_context.dart';

@RoutePage()
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _isLoading = true;
  bool _saving = false;

  bool _notificationsEnabled = true;
  bool _autoplayVideos = true;
  bool _showOnlineStatus = true;
  bool _allowFriendRequests = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  Future<void> _loadSettings() async {
    final uid = AppAuthContext.userId;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final settings =
          await context.read<ProfileRepository>().fetchSettings(uid);
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = settings['notificationsEnabled'] ?? true;
        _autoplayVideos = settings['autoplayVideos'] ?? true;
        _showOnlineStatus = settings['showOnlineStatus'] ?? true;
        _allowFriendRequests = settings['allowFriendRequests'] ?? true;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    final uid = AppAuthContext.userId;
    if (uid == null || _saving) return;

    setState(() => _saving = true);
    try {
      await context.read<ProfileRepository>().mergeSettings(uid, {
        'notificationsEnabled': _notificationsEnabled,
        'autoplayVideos': _autoplayVideos,
        'showOnlineStatus': _showOnlineStatus,
        'allowFriendRequests': _allowFriendRequests,
      });

      await NotificationService().initialize();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Налаштування збережено', 'Settings saved')),
          backgroundColor: AppColors.bgElevated,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Не вдалося зберегти налаштування',
              'Unable to save settings',
            ),
          ),
          backgroundColor: AppColors.bgElevated,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileCreationScreen(isEditing: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppTopBar(title: I18n.t('settings')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            )
          : ListView(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xl,
              ),
              children: [
                _buildSectionTitle(
                  I18n.inline('Основні', 'General'),
                  I18n.inline(
                    'Керуйте базовими параметрами профілю',
                    'Manage basic profile preferences',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildNavigationTile(
                  icon: Icons.edit_rounded,
                  title: I18n.inline('Редагувати профіль', 'Edit profile'),
                  subtitle: I18n.inline(
                    'Змінити аватар і дані про себе',
                    'Change avatar and personal data',
                  ),
                  onTap: _openEditProfile,
                ),
                _buildNavigationTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Wallet',
                  subtitle: 'View balances and transactions',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    );
                  },
                ),
                _buildNavigationTile(
                  icon: Icons.emoji_events_rounded,
                  title: 'Tournaments',
                  subtitle: 'Create and manage tournaments',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TournamentsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildSectionTitle(
                  I18n.inline('Приватність та досвід', 'Privacy and experience'),
                  I18n.inline(
                    'Керуйте взаємодією, сповіщеннями та відображенням активності',
                    'Control notifications, interactions, and activity visibility',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildSwitchTile(
                  title:
                      I18n.inline('Увімкнути сповіщення', 'Enable notifications'),
                  subtitle: I18n.inline(
                    'Отримувати системні та соціальні сповіщення',
                    'Receive system and social notifications',
                  ),
                  value: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
                ),
                _buildSwitchTile(
                  title: I18n.inline('Автовідтворення відео', 'Autoplay videos'),
                  subtitle: I18n.inline(
                    'Автоматично запускати відео на екранах перегляду',
                    'Automatically start videos on viewing screens',
                  ),
                  value: _autoplayVideos,
                  onChanged: (value) => setState(() => _autoplayVideos = value),
                ),
                _buildSwitchTile(
                  title:
                      I18n.inline('Показувати онлайн-статус', 'Show online status'),
                  subtitle: I18n.inline(
                    'Дозволити іншим бачити вашу активність',
                    'Allow others to see your activity',
                  ),
                  value: _showOnlineStatus,
                  onChanged: (value) =>
                      setState(() => _showOnlineStatus = value),
                ),
                _buildSwitchTile(
                  title: I18n.inline(
                    'Дозволити запити в друзі',
                    'Allow friend requests',
                  ),
                  subtitle: I18n.inline(
                    'Інші гравці зможуть надсилати запити',
                    'Other players will be able to send requests',
                  ),
                  value: _allowFriendRequests,
                  onChanged: (value) =>
                      setState(() => _allowFriendRequests = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _saving
                      ? I18n.inline('Зберігаємо...', 'Saving...')
                      : I18n.t('save'),
                  onPressed: _saving ? null : _saveSettings,
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentSoft.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: AppColors.accentPrimary),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.accentPrimary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
