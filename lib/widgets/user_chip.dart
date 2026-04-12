import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flap_app/core/media/flap_cached_image.dart';
import 'package:flap_app/utils/i18n.dart';

class UserChip extends StatelessWidget {
  final String userId;
  final String? name;
  final String? avatarUrl;
  final double size;
  final bool showName;
  final VoidCallback? onTap;

  const UserChip({
    super.key,
    required this.userId,
    this.name,
    this.avatarUrl,
    this.size = 32,
    this.showName = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return _buildContent(context, displayName: name ?? I18n.inline('Користувач', 'User'), resolvedAvatarUrl: avatarUrl ?? '');
    }

    if (name != null && avatarUrl != null) {
      return _buildContent(context, displayName: name!, resolvedAvatarUrl: avatarUrl!);
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchProfileRow(userId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? <String, dynamic>{};
        final displayName = name ??
            (data['display_name'] ??
                    data['name'] ??
                    data['email']?.toString().split('@').first ??
                    I18n.inline('Користувач', 'User'))
                .toString();
        final resolvedAvatarUrl =
            avatarUrl ?? (data['avatar_url'] ?? data['avatar'] ?? '').toString();
        return _buildContent(context, displayName: displayName, resolvedAvatarUrl: resolvedAvatarUrl);
      },
    );
  }

  static Future<Map<String, dynamic>?> _fetchProfileRow(String id) async {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('display_name, name, surname, email, avatar_url')
          .eq('id', id)
          .maybeSingle();
      return row != null ? Map<String, dynamic>.from(row) : null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildContent(BuildContext context, {required String displayName, required String resolvedAvatarUrl}) {
    final navigate = onTap ?? () {
      if (userId.isEmpty) return;
      Navigator.pushNamed(
        context,
        '/player-profile',
        arguments: {'playerId': userId, 'playerName': displayName},
      );
    };

    return GestureDetector(
      onTap: navigate,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: const Color(0xFF4caf50),
            backgroundImage:
                resolvedAvatarUrl.isNotEmpty ? flapCachedImageProvider(resolvedAvatarUrl) : null,
            child: resolvedAvatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: TextStyle(color: Colors.white, fontSize: (size / 2) - 2, fontWeight: FontWeight.w600),
                  )
                : null,
          ),
          if (showName) ...[
            const SizedBox(width: 8),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
