import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/flap_tokens.dart';
import '../utils/city_catalog.dart';

/// Free-text city field with live autocomplete. The user may type ANY city
/// (custom values are allowed, not just the predefined catalog). After the
/// first two characters, matching catalog cities are surfaced in a dropdown;
/// when nothing matches, a "city not found" row is shown instead — the typed
/// value is still accepted.
class CityAutocompleteField extends StatefulWidget {
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

  /// Number of characters required before suggestions are shown.
  static const int minQueryChars = 2;

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
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final LayerLink _link = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlay;

  List<String> _suggestions = const [];
  bool _notFound = false;
  double _fieldWidth = 280;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _recompute(widget.controller.text);
      if (_suggestions.isNotEmpty || _notFound) _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _recompute(String value) {
    final q = value.trim();
    if (q.length < CityAutocompleteField.minQueryChars) {
      _suggestions = const [];
      _notFound = false;
      return;
    }
    _suggestions = CityCatalog.suggest(
      q,
      includeAll: widget.includeAllOption,
      minChars: CityAutocompleteField.minQueryChars,
    );
    // Don't flag "not found" when what's typed already exactly matches a city.
    _notFound = _suggestions.isEmpty &&
        !CityCatalog.isAllowed(q, includeAll: widget.includeAllOption);
  }

  void _onChanged(String value) {
    _recompute(value);
    if (_suggestions.isNotEmpty || _notFound) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
    _overlay?.markNeedsBuild();
    setState(() {});
  }

  void _select(String city) {
    widget.controller
      ..text = city
      ..selection = TextSelection.collapsed(offset: city.length);
    _removeOverlay();
    _focusNode.unfocus();
    widget.onSelected?.call(city);
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildOverlay(BuildContext context) {
    return Positioned(
      width: _fieldWidth,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 6),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 232),
              decoration: BoxDecoration(
                color: FlapColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FlapColors.borderStrong),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _notFound ? _notFoundRow() : _suggestionList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notFoundRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.search_off_rounded,
              color: FlapColors.muted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('city_not_found'),
              style: FlapText.sora(color: FlapColors.muted, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemCount: _suggestions.length,
      itemBuilder: (context, i) {
        final city = _suggestions[i];
        return InkWell(
          onTap: () => _select(city),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.location_city_rounded,
                    color: FlapColors.muted, size: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlapText.sora(color: FlapColors.text, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isFinite) {
            _fieldWidth = constraints.maxWidth;
          }
          return TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            style: widget.style,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            textInputAction: TextInputAction.done,
            onChanged: _onChanged,
            onFieldSubmitted: (value) {
              _removeOverlay();
              widget.onSelected?.call(value.trim());
            },
            validator: (value) {
              final v = (value ?? '').trim();
              if (widget.requiredField && v.isEmpty) {
                return tr('il_0683014b0c');
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: widget.label.isEmpty ? null : widget.label,
              hintText: widget.hint,
              labelStyle: widget.labelStyle,
              filled: widget.filled,
              fillColor: widget.fillColor,
              border: widget.border,
              enabledBorder: widget.enabledBorder,
              focusedBorder: widget.focusedBorder,
              prefixIcon: widget.prefixIcon,
            ),
          );
        },
      ),
    );
  }
}
