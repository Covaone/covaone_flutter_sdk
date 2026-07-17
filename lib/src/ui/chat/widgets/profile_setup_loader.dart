import 'package:flutter/material.dart';

import '../../shared/platform_loader.dart';
import '../../shared/covaone_theme.dart';

/// Bottom-of-chat loading state shown while `POST /set-profile` is in flight.
class ProfileSetupLoader extends StatelessWidget {
  const ProfileSetupLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 20),
          const PlatformLoader(size: 28, strokeWidth: 2.5),
          const SizedBox(height: 12),
          Text(
            'Starting your conversation…',
            style: CovaoneTheme.captionStyle(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
