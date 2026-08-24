import 'package:flutter/material.dart';
import '../core/motion.dart';

/// One-shot fade + slide-up entrance for a widget that should animate in
/// once when it first appears, and never again -- built purely from
/// implicit animation widgets (no `AnimationController`, nothing to
/// dispose). Starts hidden/offset below its final position, then flips to
/// visible on the first post-frame callback after mount (optionally
/// delayed, for a small stagger between sibling sections). Because the
/// visible flag never flips back, a later parent rebuild that reuses this
/// same widget at the same tree position (Flutter matches by type+position,
/// not by object identity) does not replay the animation.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.delay > Duration.zero) {
        await Future.delayed(widget.delay);
      }
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = resolveMotion(context, Motion.sectionEntrance);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: duration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        duration: duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
