import 'package:flutter/material.dart';
import '../../blocs/session/session_bloc.dart';
import '../../data/models/session_model.dart';
import '../shared/covaone_theme.dart';

/// A single conversation entry card.
class ConversationRow extends StatelessWidget {
  final SessionModel session;
  final SessionLoaded sessionState;
  final VoidCallback onTap;

  const ConversationRow({
    super.key,
    required this.session,
    required this.sessionState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String lastMessage;
    if (session.messages.isEmpty) {
      lastMessage = 'No messages yet';
    } else {
      final last = session.messages.last;
      if (last.isCallLog) {
        lastMessage = 'Incoming call';
      } else if (last.hasAttachment) {
        lastMessage = 'Attachment';
      } else {
        lastMessage = last.message;
      }
    }

    final initials = sessionState.initials;
    final themeColor = sessionState.themeColor;
    final supportName = session.configuration.supportName;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: CovaoneTheme.cardDecoration(),
        child: Row(
          children: [
            // Avatar circle with initials
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: CovaoneTheme.subheadStyle(color: themeColor)
                    .copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supportName, style: CovaoneTheme.subheadStyle()),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage,
                    style: CovaoneTheme.captionStyle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }
}
