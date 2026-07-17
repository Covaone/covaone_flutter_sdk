import 'package:flutter/material.dart';
import '../../../core/emoji_list.dart';

/// Scrollable emoji picker that slides in above the input bar.
class EmojiPickerOverlay extends StatelessWidget {
  final void Function(String emoji) onEmojiSelected;

  const EmojiPickerOverlay({super.key, required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: kCovaoneEmojis
                    .map((e) => GestureDetector(
                          onTap: () => onEmojiSelected(e),
                          child: Text(e,
                              style: const TextStyle(fontSize: 22)),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
