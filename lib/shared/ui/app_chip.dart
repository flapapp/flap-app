import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      label: Text(label),
      selectedColor: AppColors.accentSoft,
      checkmarkColor: AppColors.accentPrimary,
      side: const BorderSide(color: AppColors.borderSubtle),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
      backgroundColor: AppColors.bgElevated,
    );
  }
}
