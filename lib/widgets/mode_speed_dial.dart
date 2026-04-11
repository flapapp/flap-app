import 'package:flutter/material.dart';

import 'package:flap_app/core/theme/flap_theme.dart';

class ModeDialAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;

  const ModeDialAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.background = FlapTheme.surfaceElevated,
    this.iconColor = Colors.white,
  });
}

class ModeSpeedDial extends StatefulWidget {
  final List<ModeDialAction> shortcuts;
  final VoidCallback onCreate;
  final String createTooltip;
  final List<Color> createGradient;

  const ModeSpeedDial({
    super.key,
    required this.shortcuts,
    required this.onCreate,
    required this.createTooltip,
    this.createGradient = const [FlapTheme.accent, FlapTheme.accentDim],
  });

  @override
  State<ModeSpeedDial> createState() => _ModeSpeedDialState();
}

class _ModeSpeedDialState extends State<ModeSpeedDial>
    with SingleTickerProviderStateMixin {
  static const double _labelWidth = 124;
  bool _expanded = false;

  void _toggleOrCreate() {
    if (!_expanded) {
      setState(() => _expanded = true);
      return;
    }
    setState(() => _expanded = false);
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...widget.shortcuts.asMap().entries.map(
          (entry) {
            final action = entry.value;
            return IgnorePointer(
              ignoring: !_expanded,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _expanded ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: _expanded ? Offset.zero : const Offset(0, 0.2),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ShortcutButton(action: action, onCollapse: _collapse),
                  ),
                ),
              ),
            );
          },
        ),
        _buildCreateButton(),
      ],
    );
  }

  void _collapse() {
    if (mounted) {
      setState(() => _expanded = false);
    }
  }

  Widget _buildCreateButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _expanded
              ? _ActionLabel(
                  key: const ValueKey('create-label'),
                  text: widget.createTooltip,
                  width: _labelWidth,
                )
              : const SizedBox.shrink(),
        ),
        if (_expanded) const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.createGradient),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.createGradient.first.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: Colors.transparent,
            elevation: 0,
            onPressed: _toggleOrCreate,
            tooltip: widget.createTooltip,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: _expanded ? 0.9 : 1.0,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final ModeDialAction action;
  final VoidCallback onCollapse;

  const _ShortcutButton({
    required this.action,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionLabel(text: action.tooltip, width: _ModeSpeedDialState._labelWidth),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: Material(
            color: action.background,
            shape: const CircleBorder(),
            elevation: 4,
            child: IconButton(
              tooltip: action.tooltip,
              icon: Icon(action.icon, color: action.iconColor),
              onPressed: () {
                onCollapse();
                action.onTap();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionLabel extends StatelessWidget {
  final String text;
  final double width;

  const _ActionLabel({
    super.key,
    required this.text,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FlapTheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

