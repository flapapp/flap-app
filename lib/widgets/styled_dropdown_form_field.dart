import 'package:flutter/material.dart';

class StyledDropdownFormField<T> extends StatelessWidget {
  const StyledDropdownFormField({
    super.key,
    required this.value,
    required this.labelText,
    required this.items,
    required this.itemBuilder,
    this.selectedItemBuilder,
    required this.onChanged,
    this.validator,
    this.backgroundColor = const Color(0x26FFFFFF),
    this.dropdownColor = const Color(0xFF1e7d32),
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    this.labelStyle,
    this.borderRadius = 15,
    this.style = const TextStyle(color: Colors.white),
  });

  final T? value;
  final String labelText;
  final List<T> items;
  final Widget Function(T item) itemBuilder;
  final Widget Function(T item)? selectedItemBuilder;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final Color backgroundColor;
  final Color dropdownColor;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? labelStyle;
  final double borderRadius;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        style: style,
        dropdownColor: dropdownColor,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle:
              labelStyle ?? TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: contentPadding,
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: itemBuilder(item),
              ),
            )
            .toList(),
        selectedItemBuilder: selectedItemBuilder == null
            ? null
            : (context) => items
                .map((item) => selectedItemBuilder!(item))
                .toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}
