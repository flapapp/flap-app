import 'package:flutter/material.dart';

/// Reusable tappable badge for any place we show a team crest/logo.
class TeamLogoButton extends StatelessWidget {
  final String? teamId;
  final String teamName;
  final String? logoUrl;
  final double size;
  final double borderRadius;
  final bool circular;
  final VoidCallback? onTap;

  const TeamLogoButton({
    super.key,
    required this.teamId,
    required this.teamName,
    this.logoUrl,
    this.size = 40,
    this.borderRadius = 12,
    this.circular = true,
    this.onTap,
  });

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    final id = teamId;
    if (id == null || id.isEmpty) return;
    Navigator.pushNamed(
      context,
      '/team-details',
      arguments: {
        'teamId': id,
        'teamName': teamName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = teamName.isNotEmpty
        ? teamName.characters.first.toUpperCase()
        : 'T';
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(circular ? size : borderRadius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF0E1A2B),
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(placeholder),
              )
            : _fallback(placeholder),
      ),
    );

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: avatar,
    );
  }

  Widget _fallback(String placeholder) {
    return Center(
      child: Text(
        placeholder,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}





