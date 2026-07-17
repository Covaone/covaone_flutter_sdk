import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/session/session_bloc.dart';
import '../../../core/chat_controller.dart';
import '../../shared/covaone_theme.dart';

/// Gradient banner at the top of the Home tab.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key});

  static const _avatarUrls = [
    'https://i.pravatar.cc/80?img=3',
    'https://i.pravatar.cc/80?img=12',
    'https://i.pravatar.cc/80?img=25',
  ];

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 465;

    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final themeColor = state.themeColor;

        return ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: isNarrow ? (MediaQuery.of(context).padding.top + 20) : 28,
              left: 22,
              right: 22,
              bottom: 52,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _darken(themeColor, 0.08),
                  themeColor,
                  _lighten(themeColor, 0.06),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  top: -30,
                  right: -30,
                  child: _DecorativeCircle(size: 120, opacity: 0.07),
                ),
                Positioned(
                  bottom: 10,
                  left: -20,
                  child: _DecorativeCircle(size: 90, opacity: 0.06),
                ),
                Positioned(
                  top: 20,
                  right: 60,
                  child: _DecorativeCircle(size: 50, opacity: 0.08),
                ),

                // Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: close button + optional avatars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Online badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4ADE80),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4ADE80)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'We\'re online',
                                style:
                                    CovaoneTheme.labelStyle(color: Colors.white)
                                        .copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),

                        if (isNarrow)
                          GestureDetector(
                            onTap: CovaoneChatController.close,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          )
                        else
                          _AvatarRow(avatarUrls: HeroHeader._avatarUrls),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Greeting
                    Text(
                      'Hey There 👋',
                      style: CovaoneTheme.headingStyle(color: Colors.white)
                          .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'How can we help you today?',
                      style: CovaoneTheme.bodyStyle(
                              color: Colors.white.withValues(alpha: 0.80))
                          .copyWith(fontSize: 14.5),
                    ),

                    const SizedBox(height: 20),

                    // Avatar row on narrow (smaller, inline)
                    if (isNarrow)
                      _AvatarRow(avatarUrls: HeroHeader._avatarUrls),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
}

// ── Wave clipper ──────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 18,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 36,
      size.width,
      size.height - 14,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}

// ── Decorative circle ─────────────────────────────────────────────────────────

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

// ── Avatar row ────────────────────────────────────────────────────────────────

class _AvatarRow extends StatelessWidget {
  final List<String> avatarUrls;

  const _AvatarRow({required this.avatarUrls});

  @override
  Widget build(BuildContext context) {
    const avatarSize = 34.0;
    const overlap = 20.0;
    final totalWidth = avatarSize + (avatarUrls.length - 1) * overlap + 8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: avatarSize,
          width: totalWidth,
          child: Stack(
            children: avatarUrls.asMap().entries.map((e) {
              return Positioned(
                left: e.key * overlap,
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      e.value,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white24,
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Support team',
          style: CovaoneTheme.labelStyle(
                  color: Colors.white.withValues(alpha: 0.75))
              .copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
