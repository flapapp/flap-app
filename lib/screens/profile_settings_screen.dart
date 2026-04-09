import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../utils/i18n.dart';
import 'profile_creation_screen.dart';
import '../core/app_auth_context.dart';

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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = AppAuthContext.userId;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      final settings = Map<String, dynamic>.from(data['settings'] ?? <String, dynamic>{});
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
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'settings': {
          'notificationsEnabled': _notificationsEnabled,
          'autoplayVideos': _autoplayVideos,
          'showOnlineStatus': _showOnlineStatus,
          'allowFriendRequests': _allowFriendRequests,
        },
      }, SetOptions(merge: true));

      await NotificationService().initialize();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Налаштування збережено', 'Settings saved')),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Не вдалося зберегти налаштування', 'Unable to save settings')),
          backgroundColor: Colors.redAccent,
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
  return Scaffold(
    backgroundColor: const Color(0xFF0f0f23),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0f0f23),
      elevation: 0,
      title: Text(
        I18n.t('settings'),
        style: const TextStyle(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle(
                I18n.inline('Основні', 'General'),
                I18n.inline(
                  'Керуйте базовими параметрами профілю',
                  'Manage basic profile preferences',
                ),
              ),
              const SizedBox(height: 12),

              // NEW: edit profile entry
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  onTap: _openEditProfile,
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: Text(
                    I18n.inline('Редагувати профіль', 'Edit profile'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    I18n.inline(
                      'Змінити аватар і дані про себе',
                      'Change avatar and personal data',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                ),
              ),

              _buildSwitchTile(
                title: I18n.inline('Увімкнути сповіщення', 'Enable notifications'),
                subtitle: I18n.inline(
                  'Отримувати системні та соціальні сповіщення',
                  'Receive system and social notifications',
                ),
                value: _notificationsEnabled,
                onChanged: (value) => setState(() => _notificationsEnabled = value),
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
                title: I18n.inline('Показувати онлайн-статус', 'Show online status'),
                subtitle: I18n.inline(
                  'Дозволити іншим бачити вашу активність',
                  'Allow others to see your activity',
                ),
                value: _showOnlineStatus,
                onChanged: (value) => setState(() => _showOnlineStatus = value),
              ),
              _buildSwitchTile(
                title: I18n.inline('Дозволити запити в друзі', 'Allow friend requests'),
                subtitle: I18n.inline(
                  'Інші гравці зможуть надсилати запити',
                  'Other players will be able to send requests',
                ),
                value: _allowFriendRequests,
                onChanged: (value) => setState(() => _allowFriendRequests = value),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    disabledBackgroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _saving
                        ? I18n.inline('Зберігаємо...', 'Saving...')
                        : I18n.t('save'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF4caf50),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
