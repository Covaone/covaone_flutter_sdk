import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/chat/chat_bloc.dart';
import '../../../blocs/session/session_bloc.dart';
import '../../shared/covaone_theme.dart';

/// "Send us a Message" tappable card that opens the chat screen.
class SendMessageCta extends StatelessWidget {
  const SendMessageCta({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final themeColor = state.themeColor;
        final darkColor = _darken(themeColor, 0.08);

        return GestureDetector(
          onTap: () => context
              .read<ChatBloc>()
              .add(const OpenChatEvent(isNew: true)),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [themeColor, darkColor],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white.withValues(alpha: 0.1),
                highlightColor: Colors.white.withValues(alpha: 0.05),
                onTap: () => context
                    .read<ChatBloc>()
                    .add(const OpenChatEvent(isNew: true)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      // Icon container
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: _ChatBubbleIcon(color: Colors.white, size: 22),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send us a Message',
                              style: CovaoneTheme.subheadStyle(
                                      color: Colors.white)
                                  .copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4ADE80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Typically reply instantly',
                                  style: CovaoneTheme.captionStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.75))
                                      .copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Arrow
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

// ── Custom chat bubble icon ───────────────────────────────────────────────────

class _ChatBubbleIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _ChatBubbleIcon({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ChatBubblePainter(color: color),
    );
  }
}

class _ChatBubblePainter extends CustomPainter {
  final Color color;
  _ChatBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final r = w * 0.18;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Main bubble body
    final bubblePath = Path();
    bubblePath.moveTo(r, 0);
    bubblePath.lineTo(w - r, 0);
    bubblePath.arcToPoint(Offset(w, r),
        radius: Radius.circular(r), clockwise: true);
    bubblePath.lineTo(w, h * 0.62);
    bubblePath.arcToPoint(Offset(w - r, h * 0.62 + r),
        radius: Radius.circular(r), clockwise: true);
    bubblePath.lineTo(w * 0.45, h * 0.62 + r);
    // Tail
    bubblePath.lineTo(w * 0.15, h * 0.98);
    bubblePath.lineTo(w * 0.38, h * 0.62 + r);
    bubblePath.lineTo(r, h * 0.62 + r);
    bubblePath.arcToPoint(Offset(0, h * 0.62),
        radius: Radius.circular(r), clockwise: true);
    bubblePath.lineTo(0, r);
    bubblePath.arcToPoint(Offset(r, 0),
        radius: Radius.circular(r), clockwise: true);
    bubblePath.close();

    canvas.drawPath(bubblePath, paint);

    // Dots
    final dotPaint = Paint()
      ..color = color == Colors.white
          ? const Color(0x66000000)
          : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final dotY = h * 0.3;
    final dotR = w * 0.07;
    canvas.drawCircle(Offset(w * 0.26, dotY), dotR, dotPaint);
    canvas.drawCircle(Offset(w * 0.5, dotY), dotR, dotPaint);
    canvas.drawCircle(Offset(w * 0.74, dotY), dotR, dotPaint);
  }

  @override
  bool shouldRepaint(_ChatBubblePainter old) => old.color != color;
}
