import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/session/session_bloc.dart';
import '../../core/di.dart';
import '../../data/models/broadcast_model.dart';
import '../../services/audio_service.dart';
import '../shared/covaone_theme.dart';
import 'broadcast_content_view.dart';

/// Floating popup above the FAB, shown when a `"Widget"` category broadcast
/// has not been viewed yet.
///
/// - Plays a notification sound on first render.
/// - Tapping the card opens a full-screen sheet with the full broadcast.
/// - The X button marks the broadcast as viewed (removing the popup).
class WidgetBroadcastPopup extends StatefulWidget {
  final BroadcastModel broadcast;
  final VoidCallback onClose;

  const WidgetBroadcastPopup({
    super.key,
    required this.broadcast,
    required this.onClose,
  });

  @override
  State<WidgetBroadcastPopup> createState() => _WidgetBroadcastPopupState();
}

class _WidgetBroadcastPopupState extends State<WidgetBroadcastPopup> {
  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  @override
  void initState() {
    super.initState();
    CovaoneDI.sl<AudioService>().playMessageNotification();
  }

  void _openBroadcastSheet() {
    final sessionBloc = context.read<SessionBloc>();
    final themeColor = sessionBloc.state.themeColor;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) => BlocProvider.value(
        value: sessionBloc,
        child: _BroadcastSheet(
          broadcast: widget.broadcast,
          themeColor: themeColor,
          onDismiss: () {
            Navigator.of(sheetContext).pop();
            widget.onClose();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final themeColor = state.themeColor;
        final preview = _stripHtml(widget.broadcast.description);

        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F0F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent strip
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.campaign_rounded,
                              size: 18,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New announcement',
                                  style: CovaoneTheme.labelStyle(
                                    color: themeColor,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.broadcast.title,
                                  style: CovaoneTheme.subheadStyle(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: widget.onClose,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          preview,
                          style: CovaoneTheme.captionStyle().copyWith(
                            color: const Color(0xFF666666),
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _openBroadcastSheet,
                          style: TextButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Read announcement',
                            style: CovaoneTheme.subheadStyle(
                              color: Colors.white,
                            ).copyWith(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .slideY(
              begin: 0.35,
              end: 0,
              duration: 320.ms,
              curve: Curves.easeOutCubic,
            )
            .fadeIn(duration: 280.ms);
      },
    );
  }
}

class _BroadcastSheet extends StatelessWidget {
  final BroadcastModel broadcast;
  final Color themeColor;
  final VoidCallback onDismiss;

  const _BroadcastSheet({
    required this.broadcast,
    required this.themeColor,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F5F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DCE3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8, topPadding > 0 ? 4 : 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF555555),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Announcement',
                        textAlign: TextAlign.center,
                        style: CovaoneTheme.subheadStyle(),
                      ),
                    ),
                    TextButton(
                      onPressed: onDismiss,
                      child: Text(
                        'Done',
                        style: CovaoneTheme.subheadStyle(
                          color: themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BroadcastContentView(
                  broadcast: broadcast,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
