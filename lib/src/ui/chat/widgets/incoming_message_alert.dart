import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/session/session_bloc.dart';
import '../../../data/models/message_model.dart';
import '../../shared/covaone_theme.dart';

/// Sticky stacked message alerts shown when agent messages arrive while chat
/// is not open. Multiple messages render as a real deck — only the front card
/// swipes away, revealing the card beneath.
class IncomingMessageAlert extends StatelessWidget {
  final List<MessageModel> messages;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const IncomingMessageAlert({
    super.key,
    required this.messages,
    required this.onOpen,
    required this.onDismiss,
  });

  static const int _maxVisibleCards = 3;
  static const double _cardHeight = 88;
  static const double _peekPerCard = 10;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();

    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, sessionState) {
        final themeColor = sessionState.themeColor;
        final initials = sessionState is SessionLoaded
            ? sessionState.initials
            : (sessionState is SessionProfileFormVisible
                ? sessionState.session.configuration.initials
                : 'S');
        final safeInitials = initials.isEmpty ? 'S' : initials;

        // Oldest → newest among the visible deck slice.
        final visibleCount =
            messages.length.clamp(1, _maxVisibleCards).toInt();
        final visible = messages.sublist(messages.length - visibleCount);
        // Rear cards peek above the front card (not below / beside).
        final stackExtra = (visibleCount - 1) * _peekPerCard;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              height: _cardHeight + stackExtra,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Rear cards stay put while the front card peels away.
                  for (var i = 0; i < visible.length - 1; i++)
                    _DeckCard(
                      message: visible[i],
                      themeColor: themeColor,
                      initials: safeInitials,
                      depth: visible.length - 1 - i,
                      unreadCount: messages.length - (visible.length - 1 - i),
                      interactive: false,
                    ),
                  // Only the front (newest) card is dismissible.
                  Dismissible(
                    key: ValueKey('msg-alert-front-${visible.last.messageId}'),
                    direction: DismissDirection.startToEnd,
                    onDismissed: (_) => onDismiss(),
                    child: _DeckCard(
                      message: visible.last,
                      themeColor: themeColor,
                      initials: safeInitials,
                      depth: 0,
                      unreadCount: messages.length,
                      interactive: true,
                      titleOverride: _titleFor(messages.length),
                      onOpen: onOpen,
                      onDismiss: onDismiss,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _titleFor(int count) {
    if (count <= 1) return 'New message';
    return '$count new messages';
  }
}

class _DeckCard extends StatelessWidget {
  final MessageModel message;
  final Color themeColor;
  final String initials;
  final int depth;
  final int unreadCount;
  final bool interactive;
  final String? titleOverride;
  final VoidCallback? onOpen;
  final VoidCallback? onDismiss;

  const _DeckCard({
    required this.message,
    required this.themeColor,
    required this.initials,
    required this.depth,
    required this.unreadCount,
    required this.interactive,
    this.titleOverride,
    this.onOpen,
    this.onDismiss,
  });

  String get _preview {
    final text = message.message.trim();
    if (text.isEmpty) {
      return message.hasAttachment
          ? 'Sent an attachment'
          : 'New support message';
    }
    return text;
  }

  String get _title {
    if (titleOverride != null) return titleOverride!;
    return 'New message';
  }

  @override
  Widget build(BuildContext context) {
    final inset = depth * 8.0;
    final lift = depth * IncomingMessageAlert._peekPerCard;

    final card = Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: interactive ? onOpen : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: IncomingMessageAlert._cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            gradient: depth == 0
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color.lerp(Colors.white, themeColor, 0.035)!,
                    ],
                  )
                : null,
            border: Border.all(
              color: depth == 0
                  ? themeColor.withValues(alpha: 0.14)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: depth > 0
              // Rear cards only need to read as stacked paper; hide content
              // so it doesn't show through the top peek strip.
              ? const SizedBox.expand()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: _CardBody(
                    themeColor: themeColor,
                    initials: initials,
                    title: _title,
                    preview: _preview,
                    unreadCount: unreadCount,
                    showActions: interactive,
                    onDismiss: onDismiss,
                  ),
                ),
        ),
      ),
    );

    if (depth == 0) return card;

    return Positioned(
      left: inset,
      right: inset,
      bottom: lift,
      child: IgnorePointer(child: card),
    );
  }
}

class _CardBody extends StatelessWidget {
  final Color themeColor;
  final String initials;
  final String title;
  final String preview;
  final int unreadCount;
  final bool showActions;
  final VoidCallback? onDismiss;

  const _CardBody({
    required this.themeColor,
    required this.initials,
    required this.title,
    required this.preview,
    required this.unreadCount,
    required this.showActions,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    themeColor,
                    Color.lerp(themeColor, Colors.black, 0.18)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initials.length > 2 ? initials.substring(0, 2) : initials,
                style: CovaoneTheme.textStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (unreadCount > 1)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFE11D48).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: CovaoneTheme.textStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.45),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CovaoneTheme.textStyle(
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: CovaoneTheme.textStyle(
                  color: const Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.28,
                ),
              ),
            ],
          ),
        ),
        if (showActions)
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.black.withValues(alpha: 0.38),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: themeColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          )
        else
          const SizedBox(width: 40),
      ],
    );
  }
}
