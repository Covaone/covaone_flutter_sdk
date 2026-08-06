import 'package:flutter/material.dart';

import '../../shared/covaone_theme.dart';

/// App-bar overflow control for the chat screen.
///
/// Renders a soft circular trigger and a styled dropdown. Currently exposes a
/// single action — close conversation — which opens a confirmation sheet.
class ChatOverflowMenu extends StatelessWidget {
  final Color themeColor;
  final VoidCallback onCloseConversation;

  const ChatOverflowMenu({
    super.key,
    required this.themeColor,
    required this.onCloseConversation,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ChatMenuAction>(
      tooltip: 'More options',
      offset: const Offset(0, 44),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFF0F0F3)),
      ),
      padding: EdgeInsets.zero,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8E8EC)),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: Color(0xFF3D3D4A),
        ),
      ),
      onSelected: (action) {
        if (action == _ChatMenuAction.closeConversation) {
          onCloseConversation();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_ChatMenuAction>(
          value: _ChatMenuAction.closeConversation,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  size: 18,
                  color: Color(0xFFBE123C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Close conversation',
                      style: CovaoneTheme.bodyStyle(
                        color: const Color(0xFF1A1A2E),
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'End this chat session',
                      style: CovaoneTheme.captionStyle(
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ChatMenuAction { closeConversation }

/// Confirmation bottom sheet shown before ending a conversation.
Future<bool> showCloseConversationSheet(
  BuildContext context, {
  required Color themeColor,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFFE4E6),
                          themeColor.withValues(alpha: 0.12),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 28,
                      color: Color(0xFFBE123C),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Close this conversation?',
                    style: CovaoneTheme.headingStyle(
                      color: const Color(0xFF1A1A2E),
                    ).copyWith(fontSize: 17),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You’ll still be able to read past messages, but you won’t be able to send new ones. Start a new conversation anytime.',
                    style: CovaoneTheme.bodyStyle(
                      color: const Color(0xFF6B7280),
                    ).copyWith(height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBE123C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close conversation',
                        style: CovaoneTheme.bodyStyle(color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4B5563),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Keep chatting',
                        style: CovaoneTheme.bodyStyle(
                          color: const Color(0xFF4B5563),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}
