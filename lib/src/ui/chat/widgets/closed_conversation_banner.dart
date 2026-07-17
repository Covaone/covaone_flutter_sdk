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

        return Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('This conversation has been closed',
                  style: CovaoneTheme.subheadStyle(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'If you have further inquiries, feel free to initiate a new conversation.',
                style: CovaoneTheme.captionStyle(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _startNew(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const PlatformLoader(
                          color: Colors.white,
                          strokeWidth: 2,
                          size: 18,
                        )
                      : Text('New Conversation',
                          style: CovaoneTheme.bodyStyle(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
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
