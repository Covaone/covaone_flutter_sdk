import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/call/call_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../shared/covaone_theme.dart';

/// Full-panel overlay displayed when [CallStatus.active].
///
/// Matches the JS `showActiveCallUI()` layout:
/// - Agent avatar circle
/// - Agent name + live MM:SS timer
/// - Mute/Unmute toggle button and End-call button
///
/// The duration counter is driven by [CallState.durationSeconds], which
/// [CallBloc] increments every second via [Timer.periodic].
class ActiveCallOverlay extends StatelessWidget {
  const ActiveCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, callState) {
        final themeColor =
            context.select<SessionBloc, Color>((b) => b.state is SessionLoaded
                ? (b.state as SessionLoaded).themeColor
                : CovaoneTheme.primaryColor(null));

        final agentName = callState.agentName ?? 'Support Agent';
        final initial =
            agentName.isNotEmpty ? agentName[0].toUpperCase() : 'A';
        final timer = _formatDuration(callState.durationSeconds);

        return Positioned.fill(
          child: Container(
            color: const Color(0xF5FFFFFF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Avatar ────────────────────────────────────────────────
                CircleAvatar(
                  radius: 36,
                  backgroundColor: themeColor,
                  child: Text(
                    initial,
                    style: CovaoneTheme.headingStyle(color: Colors.white)
                        .copyWith(fontSize: 28),
                  ),
                )
                    .animate()
                    .scaleXY(
                        begin: 0.8,
                        end: 1,
                        duration: 300.ms,
                        curve: Curves.easeOut)
                    .fadeIn(duration: 200.ms),

                const SizedBox(height: 24),

                // ── Agent name ─────────────────────────────────────────────
                Text(agentName, style: CovaoneTheme.headingStyle()),
                const SizedBox(height: 8),

                // ── Live timer ─────────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    timer,
                    key: ValueKey(timer),
                    style: CovaoneTheme.subheadStyle(
                        color: const Color(0xFF9E9E9E)),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Action buttons ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActiveCallButton(
                      label: callState.isMuted ? 'Unmute' : 'Mute',
                      icon: callState.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      backgroundColor: const Color(0xFFEEEEEE),
                      foregroundColor: const Color(0xFF333333),
                      onTap: () =>
                          context.read<CallBloc>().add(const ToggleMuteEvent()),
                    ),
                    const SizedBox(width: 32),
                    _ActiveCallButton(
                      label: 'End call',
                      icon: Icons.call_end_rounded,
                      backgroundColor: const Color(0xFFFF4D4D),
                      foregroundColor: Colors.white,
                      onTap: () =>
                          context.read<CallBloc>().add(const HangupCallEvent()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Formats [seconds] as `MM:SS`.
  static String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Circular active-call button with icon and label below.
class _ActiveCallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _ActiveCallButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: foregroundColor, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: CovaoneTheme.captionStyle(color: const Color(0xFF555555)),
        ),
      ],
    );
  }
}
