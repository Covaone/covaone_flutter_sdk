import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../blocs/session/session_bloc.dart';
import '../../data/models/broadcast_model.dart';
import '../shared/covaone_theme.dart';

/// Polished broadcast body used by the detail screen and widget popup sheet.
class BroadcastContentView extends StatelessWidget {
  final BroadcastModel broadcast;
  final ScrollController? scrollController;

  const BroadcastContentView({
    super.key,
    required this.broadcast,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final themeColor = state.themeColor;

        return Container(
          color: const Color(0xFFF4F5F7),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BroadcastHero(
                  broadcast: broadcast,
                  themeColor: themeColor,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (broadcast.title.isNotEmpty) ...[
                        Text(
                          broadcast.title,
                          style: CovaoneTheme.headingStyle().copyWith(
                            fontSize: 22,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _MetaRow(
                        broadcast: broadcast,
                        themeColor: themeColor,
                      ),
                      const SizedBox(height: 18),
                      _ContentCard(
                        description: broadcast.description,
                        themeColor: themeColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BroadcastHero extends StatelessWidget {
  final BroadcastModel broadcast;
  final Color themeColor;

  const _BroadcastHero({
    required this.broadcast,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (broadcast.image != null && broadcast.image!.isNotEmpty) {
      return Stack(
        children: [
          CachedNetworkImage(
            imageUrl: broadcast.image!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (_, __) => _GradientHero(themeColor: themeColor),
            errorWidget: (_, __, ___) => _GradientHero(themeColor: themeColor),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF4F5F7).withValues(alpha: 0),
                    const Color(0xFFF4F5F7),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _GradientHero(themeColor: themeColor);
  }
}

class _GradientHero extends StatelessWidget {
  final Color themeColor;

  const _GradientHero({required this.themeColor});

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _darken(themeColor, 0.1),
            themeColor,
            _lighten(themeColor, 0.08),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -24,
            right: -18,
            child: _DecorativeCircle(size: 110, opacity: 0.08),
          ),
          const Positioned(
            bottom: -10,
            left: -20,
            child: _DecorativeCircle(size: 80, opacity: 0.06),
          ),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorativeCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final BroadcastModel broadcast;
  final Color themeColor;

  const _MetaRow({
    required this.broadcast,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MetaChip(
          icon: Icons.schedule_rounded,
          label: CovaoneTheme.relativeTime(broadcast.timeCreated),
          background: const Color(0xFFECEEF2),
          foreground: const Color(0xFF5C6370),
        ),
        _MetaChip(
          icon: Icons.notifications_active_rounded,
          label: _categoryLabel(broadcast.broadcastCategory),
          background: themeColor.withValues(alpha: 0.12),
          foreground: themeColor,
        ),
      ],
    );
  }

  String _categoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'widget':
        return 'Announcement';
      case 'in-app':
      case 'app':
        return 'Update';
      default:
        return category;
    }
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: CovaoneTheme.labelStyle(color: foreground)
                .copyWith(fontWeight: FontWeight.w600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final String description;
  final Color themeColor;

  const _ContentCard({
    required this.description,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Html(
        data: description,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(15),
            lineHeight: const LineHeight(1.7),
            fontFamily: 'Circular',
            color: const Color(0xFF3D4450),
          ),
          'p': Style(
            margin: Margins.only(bottom: 14),
          ),
          'b': Style(
            fontWeight: FontWeight.w700,
            fontSize: FontSize(15.5),
            color: themeColor,
            display: Display.block,
            margin: Margins.only(top: 18, bottom: 6),
          ),
          'strong': Style(
            fontWeight: FontWeight.w700,
            fontSize: FontSize(15.5),
            color: themeColor,
            display: Display.block,
            margin: Margins.only(top: 18, bottom: 6),
          ),
          'h1': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A2E),
            margin: Margins.only(top: 8, bottom: 10),
          ),
          'h2': Style(
            fontSize: FontSize(16.5),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A2E),
            margin: Margins.only(top: 16, bottom: 8),
          ),
          'h3': Style(
            fontSize: FontSize(15.5),
            fontWeight: FontWeight.w700,
            color: themeColor,
            margin: Margins.only(top: 14, bottom: 6),
          ),
          'ul': Style(
            margin: Margins.only(bottom: 14, left: 8),
            padding: HtmlPaddings.only(left: 16),
          ),
          'ol': Style(
            margin: Margins.only(bottom: 14, left: 8),
            padding: HtmlPaddings.only(left: 16),
          ),
          'li': Style(
            margin: Margins.only(bottom: 6),
            lineHeight: const LineHeight(1.6),
          ),
          'a': Style(
            color: themeColor,
            textDecoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
        },
      ),
    );
  }
}
