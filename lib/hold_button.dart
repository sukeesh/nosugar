import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Press and hold to commit. Fills left to right while held, with haptic ticks
/// that get stronger toward the end. Releasing early drains it back.
/// VoiceOver / TalkBack users get a plain tap action instead.
class HoldButton extends StatefulWidget {
  const HoldButton({super.key, required this.label, required this.onComplete, this.duration = const Duration(milliseconds: 1600)});
  final String label;
  final VoidCallback onComplete;
  final Duration duration;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)
    ..addListener(_tick)
    ..addStatusListener(_status);
  int _lastTick = 0;
  bool _held = false;

  void _tick() {
    final step = (_c.value * 10).floor();
    if (_held && step > _lastTick) {
      step < 7 ? HapticFeedback.selectionClick() : HapticFeedback.lightImpact();
    }
    _lastTick = step;
    setState(() {});
  }

  void _status(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      _held = false;
      widget.onComplete();
      _c.value = 0;
    }
  }

  void _down() {
    _held = true;
    _c.forward();
  }

  void _up() {
    if (!_held) return;
    _held = false;
    _c.animateBack(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onComplete,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: AnimatedScale(
          scale: _held ? 0.97 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 64,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: C.gold,
              shadows: [BoxShadow(color: C.gold.withValues(alpha: 0.2 + 0.35 * v), blurRadius: 30 + 30 * v)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: const ColoredBox(color: Color(0xFFFFE3A8)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: C.ink, size: 22),
                    const SizedBox(width: 8),
                    Text(_held ? 'Keep holding…' : widget.label, style: T.body(17, color: C.ink, weight: FontWeight.w600, height: 1.2)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
