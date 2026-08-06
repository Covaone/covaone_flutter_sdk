import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/session/session_bloc.dart';
import '../../shared/platform_loader.dart';
import '../../shared/covaone_theme.dart';

/// Shown at the bottom of the chat when the conversation has been closed.
/// Provides a "New Conversation" button that creates a fresh session.
class ClosedConversationBanner extends StatefulWidget {
  const ClosedConversationBanner({super.key});

  @override
  State<ClosedConversationBanner> createState() =>
      _ClosedConversationBannerState();
}

class _ClosedConversationBannerState extends State<ClosedConversationBanner> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionBloc, SessionState>(
      listenWhen: (_, curr) =>
          curr is SessionLoaded || curr is SessionError,
      listener: (context, state) {
        if (mounted) setState(() => _loading = false);

        if (state is SessionLoaded && state.session.isOpen) {
          // New session created — the ChatScreen will reflect the new state
          // automatically via BlocBuilder.
        } else if (state is SessionError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, sessionState) {
        final themeColor = sessionState.themeColor;
        final softTint = themeColor.withValues(alpha: 0.08);
        final darkColor = Color.lerp(themeColor, Colors.black, 0.12)!;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                softTint,
                Colors.white,
              ],
            ),
            border: const Border(
              top: BorderSide(color: Color(0xFFF0F0F3)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: softTint, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 26,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Conversation closed',
                  style: CovaoneTheme.subheadStyle(
                    color: const Color(0xFF1A1A2E),
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Thanks for chatting. If you need more help, start a new conversation below.',
                  style: CovaoneTheme.captionStyle(
                    color: const Color(0xFF6B7280),
                  ).copyWith(height: 1.4, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [themeColor, darkColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _startNew(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const PlatformLoader(
                              color: Colors.white,
                              strokeWidth: 2,
                              size: 18,
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'New conversation',
                                  style: CovaoneTheme.bodyStyle(
                                    color: Colors.white,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startNew(BuildContext context) {
    setState(() => _loading = true);
    context.read<SessionBloc>().add(const NewConversationEvent());
  }
}
