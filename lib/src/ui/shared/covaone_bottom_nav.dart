import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/session/session_bloc.dart';
import 'covaone_theme.dart';

/// Three-tab bottom navigation bar: Home / Messages / FAQs.
class CovaoneBottomNav extends StatelessWidget {
  const CovaoneBottomNav({super.key});

  static const _inactiveColor = Color(0xFFB8BEC8);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      buildWhen: (prev, curr) => prev.themeColor != curr.themeColor,
      builder: (context, sessionState) {
        final activeColor = sessionState.themeColor;
        return BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (prev, curr) => prev.currentTab != curr.currentTab,
          builder: (context, state) {
            final tab = state.currentTab;
            return Container(
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0F0F5), width: 1.2)),
              ),
              child: Row(
                children: [
                  _NavItem(
                    iconType: _NavIconType.home,
                    label: 'Home',
                    isActive: tab == ChatTab.home,
                    activeColor: activeColor,
                    onTap: () => context
                        .read<ChatBloc>()
                        .add(const ChatTabChangedEvent(tab: ChatTab.home)),
                  ),
                  _NavItem(
                    iconType: _NavIconType.messages,
                    label: 'Messages',
                    isActive: tab == ChatTab.conversations,
                    activeColor: activeColor,
                    onTap: () => context.read<ChatBloc>().add(
                        const ChatTabChangedEvent(tab: ChatTab.conversations)),
                  ),
                  _NavItem(
                    iconType: _NavIconType.faq,
                    label: 'FAQs',
                    isActive: tab == ChatTab.faq,
                    activeColor: activeColor,
                    onTap: () => context
                        .read<ChatBloc>()
                        .add(const ChatTabChangedEvent(tab: ChatTab.faq)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final _NavIconType iconType;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.iconType,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? activeColor : CovaoneBottomNav._inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active indicator pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: isActive ? 28 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: CustomPaint(
                key: ValueKey('${iconType}_$isActive'),
                size: const Size(22, 22),
                painter: _NavIconPainter(
                  type: iconType,
                  color: color,
                  active: isActive,
                ),
              ),
            ),

            const SizedBox(height: 3),
            Text(label, style: CovaoneTheme.labelStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Icon types ────────────────────────────────────────────────────────────────

enum _NavIconType { home, messages, faq }

// ── Custom icon painter ───────────────────────────────────────────────────────

class _NavIconPainter extends CustomPainter {
  final _NavIconType type;
  final Color color;
  final bool active;

  _NavIconPainter({required this.type, required this.color, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case _NavIconType.home:
        _drawHome(canvas, size);
      case _NavIconType.messages:
        _drawMessages(canvas, size);
      case _NavIconType.faq:
        _drawFaq(canvas, size);
    }
  }

  Paint _strokePaint(double strokeW) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeW
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _fillPaint() => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  // ── Home ──────────────────────────────────────────────────────────────────

  void _drawHome(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    if (active) {
      // Filled house silhouette
      final house = Path()
        ..moveTo(w * 0.5, h * 0.02)       // roof peak
        ..lineTo(w * 0.02, h * 0.49)      // left eave
        ..lineTo(w * 0.17, h * 0.49)      // chimney base left
        ..lineTo(w * 0.17, h * 0.96)      // left wall bottom
        ..lineTo(w * 0.83, h * 0.96)      // right wall bottom
        ..lineTo(w * 0.83, h * 0.49)      // chimney base right
        ..lineTo(w * 0.98, h * 0.49)      // right eave
        ..close();
      canvas.drawPath(house, _fillPaint());

      // Door cutout (white)
      final doorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final doorPath = Path()
        ..addRRect(RRect.fromRectAndCorners(
          Rect.fromLTWH(w * 0.37, h * 0.62, w * 0.26, h * 0.34),
          topLeft: Radius.circular(w * 0.07),
          topRight: Radius.circular(w * 0.07),
        ));
      canvas.drawPath(doorPath, doorPaint);
    } else {
      final sw = w * 0.088;
      final p = _strokePaint(sw);

      // Roof (open triangle)
      final roof = Path()
        ..moveTo(w * 0.5, h * 0.04)
        ..lineTo(w * 0.04, h * 0.5)
        ..lineTo(w * 0.96, h * 0.5)
        ..close();
      canvas.drawPath(roof, p);

      // Left + right walls
      canvas.drawLine(Offset(w * 0.19, h * 0.5), Offset(w * 0.19, h * 0.95), p);
      canvas.drawLine(Offset(w * 0.81, h * 0.5), Offset(w * 0.81, h * 0.95), p);

      // Floor
      canvas.drawLine(Offset(w * 0.19, h * 0.95), Offset(w * 0.81, h * 0.95), p);

      // Door
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(w * 0.37, h * 0.63, w * 0.26, h * 0.32),
          topLeft: Radius.circular(w * 0.07),
          topRight: Radius.circular(w * 0.07),
        ),
        _strokePaint(sw * 0.85),
      );
    }
  }

  // ── Messages (chat bubble) ─────────────────────────────────────────────────

  void _drawMessages(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final r = w * 0.17;

    // Bubble body (rounded rect)
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h * 0.74),
      Radius.circular(r),
    );

    if (active) {
      // Filled bubble
      final bubblePath = Path()..addRRect(bubbleRect);
      // Add tail at bottom-left
      bubblePath
        ..moveTo(w * 0.14, h * 0.74)
        ..lineTo(w * 0.04, h * 0.97)
        ..lineTo(w * 0.38, h * 0.74);
      canvas.drawPath(bubblePath, _fillPaint());

      // Three dots inside (white)
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final dotY = h * 0.35;
      final dotR = w * 0.075;
      canvas.drawCircle(Offset(w * 0.27, dotY), dotR, dotPaint);
      canvas.drawCircle(Offset(w * 0.5, dotY), dotR, dotPaint);
      canvas.drawCircle(Offset(w * 0.73, dotY), dotR, dotPaint);
    } else {
      final sw = w * 0.088;
      final p = _strokePaint(sw);

      // Bubble outline
      canvas.drawRRect(bubbleRect, p);

      // Tail
      final tailPaint = _fillPaint();
      final tailPath = Path()
        ..moveTo(w * 0.15, h * 0.74)
        ..lineTo(w * 0.05, h * 0.97)
        ..lineTo(w * 0.38, h * 0.74)
        ..close();
      canvas.drawPath(tailPath, tailPaint);

      // Two lines inside representing text
      canvas.drawLine(
          Offset(w * 0.22, h * 0.29), Offset(w * 0.78, h * 0.29), _strokePaint(sw * 0.75));
      canvas.drawLine(
          Offset(w * 0.22, h * 0.48), Offset(w * 0.62, h * 0.48), _strokePaint(sw * 0.75));
    }
  }

  // ── FAQ (open book) ────────────────────────────────────────────────────────

  void _drawFaq(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    if (active) {
      final p = _fillPaint();

      // Left page
      final leftPage = Path()
        ..moveTo(w * 0.5, h * 0.06)
        ..lineTo(w * 0.1, h * 0.13)
        ..lineTo(w * 0.1, h * 0.9)
        ..lineTo(w * 0.5, h * 0.84)
        ..close();
      canvas.drawPath(leftPage, p);

      // Right page
      final rightPage = Path()
        ..moveTo(w * 0.5, h * 0.06)
        ..lineTo(w * 0.9, h * 0.13)
        ..lineTo(w * 0.9, h * 0.9)
        ..lineTo(w * 0.5, h * 0.84)
        ..close();
      canvas.drawPath(rightPage, p);

      // White spine line
      final spinePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.065
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.5, h * 0.06), Offset(w * 0.5, h * 0.84), spinePaint);

      // White page lines
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.18, h * 0.35), Offset(w * 0.43, h * 0.33), linePaint);
      canvas.drawLine(Offset(w * 0.18, h * 0.5), Offset(w * 0.43, h * 0.49), linePaint);
      canvas.drawLine(Offset(w * 0.57, h * 0.35), Offset(w * 0.82, h * 0.33), linePaint);
      canvas.drawLine(Offset(w * 0.57, h * 0.5), Offset(w * 0.82, h * 0.49), linePaint);
    } else {
      final sw = w * 0.085;
      final p = _strokePaint(sw);

      // Left page outline
      final leftPage = Path()
        ..moveTo(w * 0.5, h * 0.06)
        ..lineTo(w * 0.1, h * 0.14)
        ..lineTo(w * 0.1, h * 0.9)
        ..lineTo(w * 0.5, h * 0.84);
      canvas.drawPath(leftPage, p);

      // Right page outline
      final rightPage = Path()
        ..moveTo(w * 0.5, h * 0.06)
        ..lineTo(w * 0.9, h * 0.14)
        ..lineTo(w * 0.9, h * 0.9)
        ..lineTo(w * 0.5, h * 0.84);
      canvas.drawPath(rightPage, p);

      // Spine
      canvas.drawLine(Offset(w * 0.5, h * 0.06), Offset(w * 0.5, h * 0.84), p);

      // Page lines
      final lp = _strokePaint(sw * 0.65);
      canvas.drawLine(Offset(w * 0.18, h * 0.36), Offset(w * 0.43, h * 0.34), lp);
      canvas.drawLine(Offset(w * 0.18, h * 0.51), Offset(w * 0.43, h * 0.5), lp);
      canvas.drawLine(Offset(w * 0.57, h * 0.36), Offset(w * 0.82, h * 0.34), lp);
      canvas.drawLine(Offset(w * 0.57, h * 0.51), Offset(w * 0.82, h * 0.5), lp);
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.color != color || old.active != active || old.type != type;
}
