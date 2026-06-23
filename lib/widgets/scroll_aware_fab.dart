import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Animated wrapper that slides/fades a floating action button out of view.
///
/// Pair it with [ScrollAwareFabMixin]: the mixin owns the [ValueListenable]
/// that this widget watches and flips it from scroll direction. Keeping the
/// animation here means every screen hides its FAB identically.
class ScrollAwareFab extends StatelessWidget {
  const ScrollAwareFab({
    super.key,
    required this.visible,
    required this.child,
  });

  /// `true` while the FAB should be shown (user is scrolling up / idle).
  final ValueListenable<bool> visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, show, _) {
        return AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          // Slide down past the bottom edge when hidden.
          offset: show ? Offset.zero : const Offset(0, 2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: show ? 1 : 0,
            child: IgnorePointer(ignoring: !show, child: child),
          ),
        );
      },
    );
  }
}

/// Adds consistent "hide the FAB on scroll-down, show it on scroll-up"
/// behaviour to any screen [State].
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ScrollAwareFabMixin {
///   Widget build(BuildContext context) => Scaffold(
///     body: scrollAwareBody(myScrollableBody),
///     floatingActionButton: scrollAwareFab(FloatingActionButton(...)),
///   );
/// }
/// ```
mixin ScrollAwareFabMixin<T extends StatefulWidget> on State<T> {
  final ValueNotifier<bool> fabVisible = ValueNotifier<bool>(true);

  @override
  void dispose() {
    fabVisible.dispose();
    super.dispose();
  }

  /// Flips [fabVisible] based on the user's vertical scroll direction. Returns
  /// `false` so the notification keeps bubbling to other listeners.
  bool _handleScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.metrics.axis == Axis.vertical) {
      switch (notification.direction) {
        case ScrollDirection.reverse: // content moving up → scrolling down
          if (fabVisible.value) fabVisible.value = false;
          break;
        case ScrollDirection.forward: // content moving down → scrolling up
          if (!fabVisible.value) fabVisible.value = true;
          break;
        case ScrollDirection.idle:
          break;
      }
    }
    return false;
  }

  /// Wrap a screen's scrollable region so its scroll drives the FAB.
  Widget scrollAwareBody(Widget body) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: body,
    );
  }

  /// Wrap the FAB so it animates with the scroll direction.
  Widget scrollAwareFab(Widget fab) {
    return ScrollAwareFab(visible: fabVisible, child: fab);
  }
}
