import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/call/call_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../../services/audio_service.dart';
import '../../core/di.dart';
import '../shared/covaone_theme.dart';

/// Full-panel overlay displayed when [CallStatus.ringing].
///
/// Matches the JS `showIncomingCallUI()` layout:
/// - Agent avatar (72 dp circle, theme colour, white initial)
/// - Agent name + "Incoming call" subtitle
/// - Decline (red) and Accept (green) buttons
///
/// The ringtone starts via [AudioService.playRingtone] in [CallBloc]
/// and is stopped automatically when either button is tapped.
class IncomingCallOverlay extends StatelessWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      buildWhen: (prev, curr) =>
          prev.agentName != curr.agentName || prev.status != curr.status,
      builder: (context, callState) {
        final themeColor =
            context.select<SessionBloc, Color>((b) => b.state is SessionLoaded
                ? (b.state as SessionLoaded).themeColor
                : CovaoneTheme.primaryColor(null));

        final agentName = callState.agentName ?? 'Support Agent';
        final initial = agentName.isNotEmpty
            ? agentName[0].toUpperCase()
            : 'A';

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
                    .scaleXY(begin: 0.5, end: 1, duration: 400.ms,
                        curve: Curves.elasticOut)
                    .fadeIn(duration: 300.ms),

                const SizedBox(height: 24),

                // ── Agent name ────────────────────────────────────────────
                Text(agentName, style: CovaoneTheme.headingStyle()),
                const SizedBox(height: 6),
                Text(
                  'Incoming call',
                  style: CovaoneTheme.bodyStyle(color: const Color(0xFF9E9E9E)),
                ),

                const SizedBox(height: 48),

                // ── Action buttons ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CallButton(
                      label: 'Decline',
                      icon: Icons.call_end_rounded,
                      backgroundColor: const Color(0xFFFF4D4D),
                      onTap: () {
                        CovaoneDI.sl<AudioService>().stopRingtone();
                        context.read<CallBloc>().add(const RejectCallEvent());
                      },
                    ),
                    const SizedBox(width: 32),
                    _CallButton(
                      label: 'Accept',
                      icon: Icons.call_rounded,
                      backgroundColor: const Color(0xFF22BA93),
                      onTap: () {
                        CovaoneDI.sl<AudioService>().stopRingtone();
                        context.read<CallBloc>().add(const AcceptCallEvent());
                      },
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
}

/// Circular call-action button with icon and label below.
class _CallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _CallButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
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
                  color: backgroundColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
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
