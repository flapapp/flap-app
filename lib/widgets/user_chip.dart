import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      return _buildContent(context, displayName: name ?? tr('il_b512d97e7c'), resolvedAvatarUrl: avatarUrl ?? '');
    }

    if (name != null && avatarUrl != null) {
      return _buildContent(context, displayName: name!, resolvedAvatarUrl: avatarUrl!);
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('profiles')
          .select('display_name,email,avatar_url')
          .eq('id', userId)
          .maybeSingle(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? <String, dynamic>{};
        final dn = data['display_name'] as String?;
        final em = data['email'] as String?;
        final displayName = name ??
            (dn?.isNotEmpty == true
                ? dn!
                : (em != null && em.contains('@')
                    ? em.split('@').first
                    : tr('il_b512d97e7c')));
        final resolvedAvatarUrl = avatarUrl ?? (data['avatar_url'] as String? ?? '');
        return _buildContent(
          context,
          displayName: displayName,
          resolvedAvatarUrl: resolvedAvatarUrl,
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, {required String displayName, required String resolvedAvatarUrl}) {
    final navigate = onTap ?? () {
      if (userId.isEmpty) return;
      context.router.push(
        PlayerProfileRoute(
          playerId: userId,
          playerName: displayName,
        ),
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
            backgroundImage: resolvedAvatarUrl.isNotEmpty ? NetworkImage(resolvedAvatarUrl) : null,
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



