import 'package:flutter/material.dart';
import '../../data/models/faq_model.dart';
import '../shared/covaone_theme.dart';

/// Full-width tappable FAQ entry row.
class FaqRow extends StatelessWidget {
  final FaqModel faq;
  final VoidCallback onTap;

  const FaqRow({super.key, required this.faq, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    faq.title,
                    style: CovaoneTheme.bodyStyle()
                        .copyWith(color: const Color(0xFF333333)),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFCCCCCC), size: 20),
              ],
            ),
          ),
          const Divider(
              height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }
}
