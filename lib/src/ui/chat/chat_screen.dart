import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../../core/config.dart';
import '../../core/di.dart';
import '../shared/shimmer_line.dart';
import '../shared/covaone_app_bar.dart';
import 'widgets/closed_conversation_banner.dart';
import 'widgets/lead_capture_form.dart';
import 'widgets/message_input_bar.dart';
import 'widgets/messages_list.dart';
import 'widgets/profile_setup_loader.dart';

/// Full chat screen. Pushed onto the local panel Navigator when the user taps
/// "Send us a Message" or a ConversationRow. Popped via [CloseChatEvent].
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  int _prevMessageCount = 0;
  late final bool _hasHostedUserProfile =
      CovaoneDI.sl<CovaoneConfig>().hasHostedUserProfile;
  bool _hostedProfileAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMessages();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _registerHostedProfileIfNeeded());
  }

  void _registerHostedProfileIfNeeded() {
    if (_hostedProfileAttempted || !_hasHostedUserProfile || !mounted) return;

    final sessionState = context.read<SessionBloc>().state;
    if (sessionState is! SessionProfileFormVisible) return;

    _hostedProfileAttempted = true;
    final config = CovaoneDI.sl<CovaoneConfig>();
    context.read<SessionBloc>().add(SetProfileEvent(
          email: config.hostedUserEmail!,
          name: config.hostedUserFullName!,
        ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final sessionId = context.read<ChatBloc>().state.sessionId;
      if (sessionId.isNotEmpty) {
        context
            .read<ChatBloc>()
            .add(SocketConnectEvent(sessionId: sessionId));
      }
    }
  }

  void _loadMessages() {
    final sessionState = context.read<SessionBloc>().state;
    String? sessionId;
    if (sessionState is SessionLoaded) {
      sessionId = sessionState.session.sessionId;
    } else if (sessionState is SessionProfileFormVisible) {
      sessionId = sessionState.session.sessionId;
    } else if (sessionState is SessionSettingProfile) {
      sessionId = sessionState.session.sessionId;
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      context
          .read<ChatBloc>()
          .add(FetchMessagesEvent(sessionId: sessionId));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionState>(
      listenWhen: (prev, curr) =>
          (curr is SessionProfileFormVisible && curr.profileError != null) ||
          (prev is! SessionProfileFormVisible &&
              curr is SessionProfileFormVisible &&
              _hasHostedUserProfile),
      listener: (context, state) {
        if (state is SessionProfileFormVisible) {
          if (state.profileError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.profileError!)),
            );
          } else {
            _registerHostedProfileIfNeeded();
          }
        }
      },
      child: BlocBuilder<SessionBloc, SessionState>(
        builder: (context, sessionState) {
          final themeColor = sessionState.themeColor;

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: CovaoneAppBar(
              title: 'Messages',
              onBack: () =>
                  context.read<ChatBloc>().add(const CloseChatEvent()),
            ),
            body: BlocConsumer<ChatBloc, ChatState>(
              listenWhen: (prev, curr) =>
                  prev.messages.length != curr.messages.length ||
                  prev.isTyping != curr.isTyping,
              listener: (context, state) {
                final newCount =
                    state.messages.length + (state.isTyping ? 1 : 0);
                if (newCount > _prevMessageCount) {
                  _prevMessageCount = newCount;
                  _scrollToBottom();
                }
              },
              builder: (context, state) {
                if (state.isLoading) {
                  return const _MessagesLoadingShimmer();
                }

                return BlocBuilder<SessionBloc, SessionState>(
                  builder: (context, sState) {
                    final session = switch (sState) {
                      SessionLoaded(:final session) => session,
                      _ => null,
                    };
                    final hasProfile = session?.hasProfile ?? false;
                    final isOpen = session?.isOpen ?? true;
                    final isSettingProfile = sState is SessionSettingProfile;
                    final needsProfileCapture = sState is SessionProfileFormVisible;
                    final showLeadForm =
                        needsProfileCapture && !_hasHostedUserProfile;

                    return Column(
                      children: [
                        Expanded(
                          child: MessagesList(
                            scrollController: _scrollController,
                            themeColor: themeColor,
                          ),
                        ),
                        if (!isOpen)
                          const ClosedConversationBanner()
                        else ...[
                          if (isSettingProfile ||
                              (needsProfileCapture && _hasHostedUserProfile))
                            const ProfileSetupLoader(),
                          if (showLeadForm) const LeadCaptureForm(),
                          MessageInputBar(
                            enabled: hasProfile,
                            themeColor: themeColor,
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Chat loading shimmer ──────────────────────────────────────────────────────

/// Displays shimmer placeholders that mimic incoming/outgoing message bubbles
/// while the session is being re-fetched.
class _MessagesLoadingShimmer extends StatelessWidget {
  const _MessagesLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _AgentBubbleShimmer(widthFraction: 0.65),
        SizedBox(height: 10),
        _AgentBubbleShimmer(widthFraction: 0.45),
        SizedBox(height: 18),
        _UserBubbleShimmer(widthFraction: 0.55),
        SizedBox(height: 18),
        _AgentBubbleShimmer(widthFraction: 0.70),
        SizedBox(height: 10),
        _AgentBubbleShimmer(widthFraction: 0.40),
        SizedBox(height: 18),
        _UserBubbleShimmer(widthFraction: 0.35),
        SizedBox(height: 18),
        _AgentBubbleShimmer(widthFraction: 0.58),
      ],
    );
  }
}

class _AgentBubbleShimmer extends StatelessWidget {
  final double widthFraction;
  const _AgentBubbleShimmer({required this.widthFraction});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * widthFraction;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ShimmerBlock(width: 30, height: 30, borderRadius: 15),
        const SizedBox(width: 8),
        ShimmerBlock(width: maxWidth, height: 44, borderRadius: 12),
      ],
    );
  }
}

class _UserBubbleShimmer extends StatelessWidget {
  final double widthFraction;
  const _UserBubbleShimmer({required this.widthFraction});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * widthFraction;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ShimmerBlock(width: maxWidth, height: 44, borderRadius: 12),
      ],
    );
  }
}
