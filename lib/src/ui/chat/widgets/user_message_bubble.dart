import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../data/models/message_model.dart';
import '../../shared/platform_loader.dart';
import '../../shared/covaone_theme.dart';

/// Right-aligned chat bubble for customer-originated messages.
class UserMessageBubble extends StatelessWidget {
  final MessageModel message;
  final Color themeColor;

  const UserMessageBubble({
    super.key,
    required this.message,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(2),
                ),
              ),
              child: _buildContent(),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 4),
              child: Text(
                _formatTime(message.timeCreated),
                style: CovaoneTheme.captionStyle(),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideX(begin: 0.3, end: 0, duration: 200.ms, curve: Curves.easeOut)
        .fadeIn(duration: 200.ms);
  }

  Widget _buildContent() {
    if (message.hasAttachment && message.fileUrl != null) {
      if (message.isImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: message.fileUrl!,
            width: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 120,
              color: Colors.white24,
            child: const Center(child: PlatformLoader(color: Colors.white)),
            ),
            errorWidget: (_, __, ___) => _fileRow(),
          ),
        );
      }
      return _fileRow();
    }

    return SelectableText(
      _processText(message.message),
      style: CovaoneTheme.bodyStyle(color: Colors.white),
    );
  }

  Widget _fileRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file_outlined,
            color: Colors.white70, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message.fileUrl != null
                ? message.fileUrl!.split('/').last
                : 'Uploaded File',
            style: CovaoneTheme.bodyStyle(color: Colors.white),
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
