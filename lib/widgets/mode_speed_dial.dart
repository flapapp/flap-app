import 'package:flutter/material.dart';

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
    this.background = const Color(0xFF1F2535),
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
    this.createGradient = const [Color(0xFF4caf50), Color(0xFF66bb6a)],
  });

  @override
  State<ModeSpeedDial> createState() => _ModeSpeedDialState();
}

class _ModeSpeedDialState extends State<ModeSpeedDial>
    with SingleTickerProviderStateMixin {
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
      mainAxisSize: MainAxisSize.min,
      children: [
        ...widget.shortcuts.asMap().entries.map(
          (entry) {
            final action = entry.value;
            return AnimatedOpacity(
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
    return Container(
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
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 200),
          turns: _expanded ? 0.125 : 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
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
    return SizedBox(
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
    );
  }
}

