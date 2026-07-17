import 'package:flutter/material.dart';

import '../../../data/models/call_log_model.dart';
import '../../../data/models/message_model.dart';
import '../../shared/covaone_theme.dart';

/// Centered full-width card shown for call events in the message list.
class CallLogBubble extends StatelessWidget {
  final MessageModel message;

  const CallLogBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final log = CallLogModel.fromMessage(message);

    final (bgColor, iconColor, icon) = _palette(log.status); // CallOutcome

    final title = _title(message, log);
    final meta = _meta(log);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: iconColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: CovaoneTheme.subheadStyle(color: iconColor)
                          .copyWith(fontSize: 13)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta,
                        style: CovaoneTheme.captionStyle(
                            color: iconColor.withValues(alpha: 0.75))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  (Color bg, Color fg, IconData icon) _palette(CallOutcome outcome) {
    switch (outcome) {
      case CallOutcome.completed:
        return (
          const Color(0xFFE6FBF6),
          const Color(0xFF22BA93),
          Icons.phone_rounded
        );
      case CallOutcome.missed:
        return (
          const Color(0xFFFFF8E1),
          const Color(0xFFF59E0B),
          Icons.phone_missed_rounded
        );
      case CallOutcome.rejected:
        return (
          const Color(0xFFF3F4F6),
          const Color(0xFF9CA3AF),
          Icons.phone_disabled_rounded
        );
      case CallOutcome.failed:
        return (
          const Color(0xFFFEE2E2),
          const Color(0xFFEF4444),
          Icons.phone_disabled_rounded
        );
    }
  }

  String _title(MessageModel msg, CallLogModel log) {
    // Outbound from agent perspective == incoming to customer.
    if (msg.messageType == MessageType.CALL &&
        msg.authorType.toUpperCase() == 'HUMAN') {
      return 'Incoming call';
    }
    if (log.direction == 'outbound') return 'Incoming call';
    if (log.direction == 'inbound') return 'Outgoing call';
    return 'Call';
  }

  String _meta(CallLogModel log) {
    switch (log.status) {
      case CallOutcome.completed:
        if (log.durationSeconds > 0) return log.formattedDuration;
        if (log.summary != null) {
          final parts = log.summary!.split('·');
          return parts.length > 1 ? parts.skip(1).join('·').trim() : '';
        }
        return 'Ended';
      case CallOutcome.missed:
        return 'Missed call';
      case CallOutcome.rejected:
        return 'Declined';
      case CallOutcome.failed:
        return 'Call failed';
    }
  }
}
