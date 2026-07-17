import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import '../shared/covaone_theme.dart';

/// Generic empty-state widget shown when there is no content to display
/// (e.g. no conversations yet).
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    this.title = 'Empty Conversation',
    this.subtitle = 'Start a conversation and we\'ll get back to you.',
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      buildWhen: (prev, curr) => prev.themeColor != curr.themeColor,
      builder: (context, state) {
        final themeColor = state.themeColor;
        final bgColor = themeColor.withValues(alpha: 0.08);
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inbox_outlined,
                      size: 44,
                      color: themeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(title,
                    style: CovaoneTheme.subheadStyle(),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: CovaoneTheme.captionStyle(),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}
