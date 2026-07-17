import 'package:flutter/material.dart';
import 'covaone_theme.dart';

/// Reusable in-panel app bar with a back arrow on the left and an optional
/// title on the right (or centre). Does NOT interact with the host Navigator.
class CovaoneAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Color? backgroundColor;

  const CovaoneAppBar({
    super.key,
    this.title = '',
    this.onBack,
    this.actions,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: backgroundColor ?? Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Back arrow
          if (onBack != null || Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: const Color(0xFF333333),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: CovaoneTheme.subheadStyle(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
