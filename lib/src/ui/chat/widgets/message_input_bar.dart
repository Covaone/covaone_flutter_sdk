import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../blocs/chat/chat_bloc.dart';
import '../../shared/platform_loader.dart';
import '../../shared/covaone_theme.dart';
import 'emoji_picker_overlay.dart';

/// Message composition bar at the bottom of the chat screen.
///
/// Handles plain-text input, emoji picker, file attachment selection / preview,
/// and dispatches [SendTextMessageEvent] or [SendFileMessageEvent] to [ChatBloc].
class MessageInputBar extends StatefulWidget {
  final bool enabled;
  final Color themeColor;

  const MessageInputBar({
    super.key,
    required this.enabled,
    required this.themeColor,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showEmoji = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Attachment pick ──────────────────────────────────────────────────────────

  Future<void> _showAttachOptions() async {
    final choice = await showModalBottomSheet<_AttachSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: widget.themeColor),
              title: Text('Photo library', style: CovaoneTheme.bodyStyle()),
              onTap: () => Navigator.pop(ctx, _AttachSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: widget.themeColor),
              title: Text('Camera', style: CovaoneTheme.bodyStyle()),
              onTap: () => Navigator.pop(ctx, _AttachSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.folder_outlined, color: widget.themeColor),
              title: Text('Files', style: CovaoneTheme.bodyStyle()),
              onTap: () => Navigator.pop(ctx, _AttachSource.files),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _AttachSource.gallery:
        await _pickImage(ImageSource.gallery);
      case _AttachSource.camera:
        await _pickImage(ImageSource.camera);
      case _AttachSource.files:
        await _pickDocument();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      // Avoid requesting full photo-library access when PHPicker is enough.
      requestFullMetadata: false,
    );
    if (!mounted || image == null) return;

    final bytes = await image.readAsBytes();
    final name = image.name.isNotEmpty
        ? image.name
        : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    _selectAttachment(
      filename: name,
      bytes: bytes,
      mimeType: _guessMime(name),
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    _selectAttachment(
      filename: file.name,
      bytes: file.bytes!,
      mimeType: _guessMime(file.name),
    );
  }

  void _selectAttachment({
    required String filename,
    required List<int> bytes,
    required String mimeType,
  }) {
    context.read<ChatBloc>().add(FileSelectedEvent(
          filename: filename,
          base64Content: base64Encode(bytes),
          mimeType: mimeType,
          sizeBytes: bytes.length,
        ));
  }

  // ── Send ─────────────────────────────────────────────────────────────────────

  void _send(ChatState state) {
    if (state.isFileSelected) {
      context.read<ChatBloc>().add(SendFileMessageEvent(
            filename: state.selectedFileName!,
            base64Content: state.pendingFileBase64!,
            mimeType: state.pendingFileMime ?? 'application/octet-stream',
            sizeBytes: state.selectedFileSize ?? 0,
          ));
      return;
    }
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(SendTextMessageEvent(text: text));
    _textCtrl.clear();
    setState(() => _showEmoji = false);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _guessMime(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg',
      'zip': 'application/zip',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) =>
          prev.isFileSelected != curr.isFileSelected ||
          prev.isSending != curr.isSending,
      builder: (context, state) {
        return GestureDetector(
          onTap: () {
            // Tapping outside emoji picker closes it.
            if (_showEmoji) setState(() => _showEmoji = false);
          },
          behavior: HitTestBehavior.translucent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showEmoji && widget.enabled)
                EmojiPickerOverlay(
                  onEmojiSelected: (emoji) {
                    final pos = _textCtrl.selection.base.offset;
                    final text = _textCtrl.text;
                    final newText = pos < 0
                        ? text + emoji
                        : text.substring(0, pos) +
                            emoji +
                            text.substring(pos);
                    _textCtrl.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(
                          offset: (pos < 0 ? text.length : pos) +
                              emoji.length),
                    );
                  },
                ),
              Container(
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? Colors.white
                      : const Color(0xFFF3F4F6),
                  border: const Border(
                      top: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Opacity(
                  opacity: widget.enabled ? 1.0 : 0.5,
                  child: AbsorbPointer(
                    absorbing: !widget.enabled,
                    child: state.isFileSelected
                        ? _FilePreviewBar(
                            filename: state.selectedFileName ?? '',
                            sizeBytes: state.selectedFileSize ?? 0,
                            themeColor: widget.themeColor,
                            formatSize: _formatFileSize,
                            onRemove: () => context
                                .read<ChatBloc>()
                                .add(const FileClearedEvent()),
                            onSend: () => _send(state),
                            isSending: state.isSending,
                          )
                        : _TextInputRow(
                            textCtrl: _textCtrl,
                            focusNode: _focusNode,
                            showEmoji: _showEmoji,
                            themeColor: widget.themeColor,
                            isSending: state.isSending,
                            onToggleEmoji: () =>
                                setState(() => _showEmoji = !_showEmoji),
                            onPickFile: _showAttachOptions,
                            onSend: () => _send(state),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _AttachSource { gallery, camera, files }

// ── Text input row ─────────────────────────────────────────────────────────────

class _TextInputRow extends StatelessWidget {
  final TextEditingController textCtrl;
  final FocusNode focusNode;
  final bool showEmoji;
  final Color themeColor;
  final bool isSending;
  final VoidCallback onToggleEmoji;
  final VoidCallback onPickFile;
  final VoidCallback onSend;

  const _TextInputRow({
    required this.textCtrl,
    required this.focusNode,
    required this.showEmoji,
    required this.themeColor,
    required this.isSending,
    required this.onToggleEmoji,
    required this.onPickFile,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Emoji toggle
        IconButton(
          icon: Icon(
            showEmoji
                ? Icons.keyboard_alt_outlined
                : Icons.emoji_emotions_outlined,
            color: const Color(0xFF9CA3AF),
          ),
          onPressed: onToggleEmoji,
          splashRadius: 20,
        ),

        // Attachment
        IconButton(
          icon: const Icon(Icons.attach_file_rounded,
              color: Color(0xFF9CA3AF)),
          onPressed: onPickFile,
          splashRadius: 20,
        ),

        // Text field
        Expanded(
          child: TextField(
            controller: textCtrl,
            focusNode: focusNode,
            minLines: 1,
            maxLines: 5,
            autocorrect: false,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: CovaoneTheme.bodyStyle(),
            decoration: InputDecoration(
              hintText: 'Type a message',
              hintStyle: CovaoneTheme.captionStyle(),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),

        // Send
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 6),
          child: InkWell(
            onTap: isSending ? null : onSend,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: PlatformLoader(color: Colors.white, strokeWidth: 2, size: 20),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}


// ── File preview bar ───────────────────────────────────────────────────────────

class _FilePreviewBar extends StatelessWidget {
  final String filename;
  final int sizeBytes;
  final Color themeColor;
  final String Function(int) formatSize;
  final VoidCallback onRemove;
  final VoidCallback onSend;
  final bool isSending;

  const _FilePreviewBar({
    required this.filename,
    required this.sizeBytes,
    required this.themeColor,
    required this.formatSize,
    required this.onRemove,
    required this.onSend,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.cloud_upload_outlined,
                color: themeColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(filename,
                    style: CovaoneTheme.bodyStyle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(formatSize(sizeBytes),
                    style: CovaoneTheme.captionStyle()),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF9CA3AF), size: 20),
            onPressed: onRemove,
            splashRadius: 18,
          ),
          InkWell(
            onTap: isSending ? null : onSend,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: PlatformLoader(color: Colors.white, strokeWidth: 2, size: 20),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
