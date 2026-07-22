import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../blocs/broadcast/broadcast_bloc.dart';
import '../../../blocs/session/session_bloc.dart';
import '../../../data/models/broadcast_model.dart';
import '../../broadcast/broadcast_detail_screen.dart';
import '../../shared/covaone_theme.dart';
import '../../shared/platform_loader.dart';

/// Renders the broadcast list (or loading/empty states) on the Home tab.
class BroadcastList extends StatelessWidget {
  const BroadcastList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BroadcastBloc, BroadcastState>(
      builder: (context, state) {
        if (state is BroadcastLoading || state is BroadcastInitial) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: PlatformLoader()),
          );
        }

        if (state is BroadcastError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(state.message, style: CovaoneTheme.captionStyle()),
          );
        }

        if (state is BroadcastLoaded) {
          if (state.inAppBroadcasts.isEmpty) {
            return _ContactEmailFallback();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Text(
                      'Latest Updates',
                      style: CovaoneTheme.captionStyle().copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: const Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: const Color(0xFFF0F0F0),
                      ),
                    ),
                  ],
                ),
              ),
              ...state.inAppBroadcasts.map((b) => _BroadcastRow(broadcast: b)),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ── Individual row ────────────────────────────────────────────────────────────

class _BroadcastRow extends StatelessWidget {
  final BroadcastModel broadcast;

  const _BroadcastRow({required this.broadcast});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context
            .read<BroadcastBloc>()
            .add(FetchSingleBroadcastEvent(broadcastId: broadcast.broadcastId));

        Navigator.of(context).pushNamed(
          '/broadcast-detail',
          arguments: BroadcastDetailScreen(broadcastId: broadcast.broadcastId),
        );
      },
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Optional thumbnail
                if (broadcast.image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: broadcast.image!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFEEEEEE),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFEEEEEE),
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Text block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        broadcast.title,
                        style: CovaoneTheme.subheadStyle(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CovaoneTheme.relativeTime(broadcast.timeCreated),
                        style: CovaoneTheme.captionStyle(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFCCCCCC), size: 20),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16,
              color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }
}

// ── Fallback when broadcasts list is empty and no email registered ────────────

class _ContactEmailFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final email = state is SessionLoaded
            ? state.session.configuration.contactEmail
            : '';
        final themeColor = state.themeColor;

        if (email.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () async {
              final uri = Uri(scheme: 'mailto', path: email);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                // Fallback if the host app omitted LSApplicationQueriesSchemes.
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: CovaoneTheme.cardDecoration(),
              child: Row(
                children: [
                  Icon(Icons.mail_outline_rounded, color: themeColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mail us directly',
                            style: CovaoneTheme.subheadStyle()),
                        Text(email, style: CovaoneTheme.captionStyle()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
