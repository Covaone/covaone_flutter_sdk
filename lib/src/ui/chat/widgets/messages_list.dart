import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../blocs/chat/chat_bloc.dart';
import '../../../blocs/session/session_bloc.dart';
import '../../../data/models/message_model.dart';
import 'agent_message_bubble.dart';
import 'message_bubble_factory.dart';

/// Scrollable message list backed by [ChatBloc].
///
/// A typing bubble is appended at the bottom while [ChatState.isTyping] is
/// true. The [scrollController] is managed by [ChatScreen] so it can animate
/// to the bottom on new messages.
class MessagesList extends StatelessWidget {
  final ScrollController scrollController;
  final Color themeColor;

  const MessagesList({
    super.key,
    required this.scrollController,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) =>
          prev.messages != curr.messages || prev.isTyping != curr.isTyping,
      builder: (context, chatState) {
        return BlocBuilder<SessionBloc, SessionState>(
          builder: (context, sessionState) {
            final msgs = chatState.messages;
            final showTyping = chatState.isTyping;
            final itemCount = msgs.length + (showTyping ? 1 : 0);

            if (itemCount == 0) {
              return const _EmptyChat();
            }

            // Build a flat list interleaving date separators between
            // messages that fall on different calendar days.
            final items = _buildItems(msgs, showTyping);

            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                if (item is DateTime) {
                  return _DateSeparator(date: item);
                }
                if (item == _typingMarker) {
                  return const AgentMessageBubble(isTyping: true);
                }
                return MessageBubbleFactory.build(
                    item as MessageModel, themeColor);
              },
            );
          },
        );
      },
    );
  }
}

/// Sentinel object used to represent the typing indicator in the flat list.
const Object _typingMarker = _TypingMarker();

class _TypingMarker {
  const _TypingMarker();
}

/// Builds a flat list interleaving [DateTime] date-separator markers between
/// [MessageModel] entries that fall on different calendar days.
List<Object> _buildItems(List<MessageModel> msgs, bool showTyping) {
  final items = <Object>[];
  DateTime? lastDate;
  for (final msg in msgs) {
    final local = msg.timeCreated.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (lastDate == null || day != lastDate) {
      items.add(day);
      lastDate = day;
    }
    items.add(msg);
  }
  if (showTyping) items.add(_typingMarker);
  return items;
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final String label;
    if (date == today) {
      label = 'Today';
    } else if (date == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No messages yet.\nSay hello! 👋',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        ),
      ),
    );
  }
}
