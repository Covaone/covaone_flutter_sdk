import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../data/models/message_model.dart';
import '../../shared/platform_loader.dart';
import '../../shared/covaone_theme.dart';
import 'typing_dots.dart';

/// Left-aligned chat bubble for agent / system messages.
///
/// Pass [isTyping] == true to render the animated typing indicator instead of
/// message content.
class AgentMessageBubble extends StatelessWidget {
  final MessageModel? message;
  final bool isTyping;

  const AgentMessageBubble({
    super.key,
    this.message,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: isTyping ? const TypingDots() : _buildContent(),
            ),
            if (!isTyping && message != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  _formatTime(message!.timeCreated),
                  style: CovaoneTheme.captionStyle(),
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .slideX(begin: -0.3, end: 0, duration: 200.ms, curve: Curves.easeOut)
        .fadeIn(duration: 200.ms);
  }

  Widget _buildContent() {
    final msg = message;
    if (msg == null) return const SizedBox.shrink();

    if (msg.hasAttachment && msg.fileUrl != null) {
      if (msg.isImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: msg.fileUrl!,
            width: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 120,
              color: const Color(0xFFE5E7EB),
              child: const Center(child: PlatformLoader()),
            ),
            errorWidget: (_, __, ___) => _fileRow(msg),
          ),
        );
      }
      return _fileRow(msg);
    }

    return SelectableText(
      _processText(msg.message),
      style: CovaoneTheme.bodyStyle(color: const Color(0xFF1A1A1A)),
    );
  }

  Widget _fileRow(MessageModel msg) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file_outlined,
            color: Color(0xFF6B7280), size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            msg.fileUrl != null
                ? msg.fileUrl!.split('/').last
                : 'Attachment',
            style: CovaoneTheme.bodyStyle(),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _processText(String text) =>
      text.replaceAll('\\n', '\n').replaceAll('\r\n', '\n');

  static String _formatTime(DateTime utc) =>
      DateFormat('h:mm a').format(utc.toLocal());
}
