import 'package:flutter/material.dart';

import 'widgets/broadcast_list.dart';
import 'widgets/hero_header.dart';
import 'widgets/send_message_cta.dart';

/// Home tab: gradient header, "Send us a Message" CTA, broadcast list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroHeader(),
          SendMessageCta(),
          SizedBox(height: 8),
          BroadcastList(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
