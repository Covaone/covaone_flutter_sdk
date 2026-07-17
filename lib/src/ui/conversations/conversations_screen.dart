import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../../data/models/message_model.dart';
import '../../data/models/session_model.dart';
import '../shared/empty_state.dart';
import '../shared/platform_loader.dart';
import '../shared/covaone_theme.dart';
import 'conversation_row.dart';

/// Conversations tab — shows the active session as a single conversation row,
/// or an empty state when there are no messages yet.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Text('Conversations', style: CovaoneTheme.headingStyle()),
        ),

        Expanded(
          child: BlocBuilder<SessionBloc, SessionState>(
            builder: (context, state) {
              // Still initialising — show a brief spinner.
              if (state is SessionInitial || state is SessionLoading) {
                return const Center(child: PlatformLoader());
              }

              // No profile yet or explicit error → no conversations to show.
              if (state is SessionProfileFormVisible || state is SessionError) {
                return const EmptyState(
                  title: 'No Conversations Yet',
                  subtitle:
                      'Send us a message and we\'ll get back to you shortly.',
                );
              }

              // Session is fully loaded — also watch ChatBloc so the last-message
              // preview tracks WebSocket / send / fetch updates in real time.
              if (state is SessionLoaded) {
                return BlocBuilder<ChatBloc, ChatState>(
                  buildWhen: (prev, curr) =>
                      prev.messages != curr.messages ||
                      prev.sessionId != curr.sessionId,
                  builder: (context, chatState) {
                    final messages =
                        _messagesForPreview(state.session, chatState);
                    final hasMessages = messages.isNotEmpty;

                    if (!hasMessages) {
                      return const EmptyState(
                        title: 'No Conversations Yet',
                        subtitle:
                            'Send us a message and we\'ll get back to you shortly.',
                      );
                    }

                    final sessionForRow =
                        state.session.copyWith(messages: messages);

                    return ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      children: [
                        ConversationRow(
                          session: sessionForRow,
                          sessionState: state,
                          onTap: () => context
                              .read<ChatBloc>()
                              .add(const OpenChatEvent(isNew: false)),
                        ),
                      ],
                    );
                  },
                );
              }

              // Fallback (should not be reached).
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}

/// Prefers live [ChatBloc] messages for the active session so the row preview
/// stays current; falls back to [SessionModel.messages] before chat is hydrated.
List<MessageModel> _messagesForPreview(
  SessionModel session,
  ChatState chatState,
) {
  if (chatState.sessionId.isNotEmpty &&
      chatState.sessionId == session.sessionId) {
    if (chatState.messages.length >= session.messages.length) {
      return chatState.messages;
    }
  }
  return session.messages;
}
