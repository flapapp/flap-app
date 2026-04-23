import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../utils/city_catalog.dart';

class CityAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool requiredField;
  final bool includeAllOption;
  final ValueChanged<String>? onSelected;
  final InputBorder? border;
  final InputBorder? enabledBorder;
  final InputBorder? focusedBorder;
  final TextStyle? style;
  final TextStyle? labelStyle;
  final Widget? prefixIcon;
  final Color? fillColor;
  final bool filled;

  const CityAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.requiredField = false,
    this.includeAllOption = false,
    this.onSelected,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.style,
    this.labelStyle,
    this.prefixIcon,
    this.fillColor,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final options = CityCatalog.cities(includeAll: includeAllOption);
    return FormField<String>(
      initialValue: controller.text.trim(),
      validator: (value) {
        final v = (value ?? '').trim();
        if (requiredField && v.isEmpty) {
          return tr('il_0683014b0c');
        }
        if (v.isEmpty) return null;
        if (!CityCatalog.isAllowed(v, includeAll: includeAllOption)) {
          return tr('il_b1bcd0130d');
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownMenu<String>(
              controller: controller,
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              expandedInsets: EdgeInsets.zero,
              leadingIcon: prefixIcon,
              hintText: hint ?? label,
              textStyle: style,
              inputDecorationTheme: InputDecorationTheme(
                labelStyle: labelStyle,
                filled: filled,
                fillColor: fillColor,
                border: border,
                enabledBorder: enabledBorder,
                focusedBorder: focusedBorder,
              ),
              dropdownMenuEntries: options
                  .map(
                    (city) => DropdownMenuEntry<String>(
                      value: city,
                      label: city,
                    ),
                  )
                  .toList(growable: false),
              onSelected: (v) {
                final value = (v ?? '').trim();
                controller.text = value;
                state.didChange(value);
                if (v != null) {
                  onSelected?.call(v);
                }
              },
            ),
            if (state.errorText != null && state.errorText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}