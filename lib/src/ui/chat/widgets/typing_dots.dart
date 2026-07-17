import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animated three-dot typing indicator (agent is composing a reply).
class TypingDots extends StatelessWidget {
  const TypingDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0),
        const SizedBox(width: 4),
        _dot(1),
        const SizedBox(width: 4),
        _dot(2),
      ],
    );
  }

  Widget _dot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF9CA3AF),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1,
          end: 1.4,
          duration: 400.ms,
          delay: Duration(milliseconds: index * 150),
          curve: Curves.easeInOut,
        );
  }
}
