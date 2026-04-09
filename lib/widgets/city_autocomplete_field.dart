import 'package:flutter/material.dart';

import 'package:flap_app/utils/city_catalog.dart';
import 'package:flap_app/utils/i18n.dart';

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
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        return CityCatalog.suggest(
          value.text,
          includeAll: includeAllOption,
          minChars: 2,
        );
      },
      onSelected: (String v) {
        controller.text = v;
        onSelected?.call(v);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        if (textEditingController.text != controller.text) {
          textEditingController.text = controller.text;
          textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: textEditingController.text.length),
          );
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          style: style,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint ?? I18n.inline('Введіть 2+ літери', 'Type 2+ letters'),
            labelStyle: labelStyle,
            prefixIcon: prefixIcon,
            filled: filled,
            fillColor: fillColor,
            border: border,
            enabledBorder: enabledBorder,
            focusedBorder: focusedBorder,
          ),
          onChanged: (v) {
            controller.text = v;
            onSelected?.call(v);
          },
          validator: (value) {
            final v = (value ?? '').trim();
            if (requiredField && v.isEmpty) {
              return I18n.inline('Оберіть місто зі списку', 'Select city from suggestions');
            }
            if (v.isEmpty) return null;
            if (!CityCatalog.isAllowed(v, includeAll: includeAllOption)) {
              return I18n.inline(
                'Оберіть місто зі списку підказок',
                'Please choose a city from suggestions',
              );
            }
            return null;
          },
        );
      },
    );
  }
}