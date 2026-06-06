import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/flap_tokens.dart';

/// Shared Flap UI primitives (the "kit" from the design's `kit.jsx`).

/// Square glass icon button (`.iconbtn`). Optional unread [dot] (`.bell .dot`).
class FlapIconButton extends StatelessWidget {
  const FlapIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.iconSize = 20,
    this.dot = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool dot;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final radius = size >= 42 ? FlapRadii.iconButton : 11.0;
    Widget button = Material(
      color: const Color(0x0DFFFFFF), // rgba(255,255,255,.05)
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: FlapColors.border),
          ),
          child: Icon(icon, size: iconSize, color: FlapColors.text),
        ),
      ),
    );

    if (dot) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: 8,
            right: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: FlapColors.green,
                shape: BoxShape.circle,
                border: Border.all(color: FlapColors.bg, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Stat pill used inside the hero (`.statpill`): big condensed value + caption.
class FlapStatPill extends StatelessWidget {
  const FlapStatPill({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.valueColor = FlapColors.text,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF), // rgba(255,255,255,.04)
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: valueColor),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.cond(
                    fontSize: 21,
                    height: 1,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: FlapColors.muted,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header row with title + optional "see all" action (`.section-h`).
class FlapSectionHeader extends StatelessWidget {
  const FlapSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(2, 22, 2, 12),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: FlapText.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.16,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: FlapText.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FlapColors.greenBright,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Result-form chip (W/D/L) used in the hero's "Last 5" strip (`.res`).
class FlapResultChip extends StatelessWidget {
  const FlapResultChip({super.key, required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (result) {
      case 'W':
        bg = const Color(0x334CAF50);
        fg = FlapColors.greenBright;
      case 'D':
        bg = const Color(0x2EE7C25A);
        fg = FlapColors.gold;
      case 'L':
        bg = const Color(0x29E06464);
        fg = FlapColors.red;
      default:
        bg = const Color(0x14FFFFFF);
        fg = FlapColors.muted;
    }
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        result == '-' ? '–' : result,
        style: FlapText.cond(fontSize: 13, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

/// A bottom-nav destination.
class FlapNavItem {
  const FlapNavItem({required this.icon, required this.label, required this.id});
  final IconData icon;
  final String label;
  final String id;
}

/// Floating glass bottom navigation bar with a centre create-FAB
/// (`.bottomnav` / `.navitem` / `.fab`).
class FlapBottomNav extends StatelessWidget {
  const FlapBottomNav({
    super.key,
    required this.activeId,
    required this.items,
    required this.onSelect,
    required this.onCreate,
    this.createTooltip,
  });

  final String activeId;
  final List<FlapNavItem> items;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;
  final String? createTooltip;

  @override
  Widget build(BuildContext context) {
    // FAB sits in the middle of the destination list.
    final mid = (items.length / 2).floor();
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i == mid) children.add(_fab(context));
      children.add(Expanded(child: _navItem(items[i])));
    }

    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00070A08), Color(0xEB070A08)],
          stops: [0.0, 0.38],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Blurred glass bar (clipped to rounded corners).
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xDB101410), // rgba(16,20,16,.86)
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: FlapColors.border),
                      ),
                    ),
                  ),
                ),
              ),
              // Destinations + raised FAB, drawn over the bar (un-clipped).
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(FlapNavItem item) {
    final on = item.id == activeId;
    final color = on ? FlapColors.greenBright : FlapColors.muted2;
    return InkWell(
      onTap: () => onSelect(item.id),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: FlapText.sora(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fab(BuildContext context) {
    final fab = GestureDetector(
      onTap: onCreate,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: FlapColors.primaryButton,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: FlapColors.green.withValues(alpha: 0.6),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 26, color: FlapColors.onGreen),
      ),
    );
    // Raise the FAB so it pops above the bar (design: margin-top:-18px).
    return Transform.translate(
      offset: const Offset(0, -18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: createTooltip != null
            ? Tooltip(message: createTooltip!, child: fab)
            : fab,
      ),
    );
  }
}

/// A subtle shimmer that sweeps a highlight across its [child] — wrap skeleton
/// shapes in it for loading placeholders (use instead of a spinner).
class FlapShimmer extends StatefulWidget {
  const FlapShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<FlapShimmer> createState() => _FlapShimmerState();
}

class _FlapShimmerState extends State<FlapShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.0 - 2 * (1 - t), 0),
              end: Alignment(1.0 + 2 * t, 0),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x16FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// A single skeleton placeholder block (`FlapColors.surface`-ish tone).
class FlapSkeletonBox extends StatelessWidget {
  const FlapSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
