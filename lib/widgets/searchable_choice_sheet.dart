import 'package:flutter/material.dart';

import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/utils/i18n.dart';

/// Fullscreen-ish modal with search field + scrollable list (country/city pickers).
Future<String?> showSearchableChoiceSheet({
  required BuildContext context,
  required String title,
  required List<String> items,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _SearchableSheetBody(
            title: title,
            items: items,
            selected: selected,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _SearchableSheetBody extends StatefulWidget {
  const _SearchableSheetBody({
    required this.title,
    required this.items,
    required this.selected,
    required this.scrollController,
  });

  final String title;
  final List<String> items;
  final String? selected;
  final ScrollController scrollController;

  @override
  State<_SearchableSheetBody> createState() => _SearchableSheetBodyState();
}

class _SearchableSheetBodyState extends State<_SearchableSheetBody> {
  late final TextEditingController _query;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _filtered = List<String>.from(widget.items);
    _query.addListener(_applyFilter);
  }

  void _applyFilter() {
    final q = _query.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<String>.from(widget.items);
      } else {
        _filtered = widget.items
            .where((e) => e.toLowerCase().contains(q))
            .toList(growable: false);
      }
    });
  }

  @override
  void dispose() {
    _query.removeListener(_applyFilter);
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlapTheme.pitch,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: TextField(
                  controller: _query,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: I18n.inline('Пошук…', 'Search…'),
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final item = _filtered[index];
                  final isSel = widget.selected != null &&
                      widget.selected == item;
                  return ListTile(
                    title: Text(
                      item,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isSel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check, color: Color(0xFF4caf50))
                        : null,
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
