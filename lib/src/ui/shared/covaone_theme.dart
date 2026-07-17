import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Design tokens and text-style helpers for all Covaone UI components.
abstract final class CovaoneTheme {
  static const Color _defaultPrimary = Color(0xFF592C83);
  static const Color _activeGreen = Color(0xFF22BA93);

  /// Bundled Circular Std family (see package `pubspec.yaml` fonts).
  static const String fontFamily = 'Circular';
  static const String fontPackage = 'covaone_sdk';

  // ── Color ─────────────────────────────────────────────────────────────────

  static Color primaryColor(String? hex) {
    if (hex == null || hex.isEmpty) return _defaultPrimary;
    try {
      final cleaned = hex.replaceFirst('#', '');
      final value = int.parse(
          cleaned.length == 6 ? 'FF$cleaned' : cleaned,
          radix: 16);
      return Color(value);
    } catch (_) {
      return _defaultPrimary;
    }
  }

  static Color get activeTabColor => _activeGreen;

  // ── Typography (Circular) ─────────────────────────────────────────────────

  static TextStyle textStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        package: fontPackage,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle headingStyle({Color? color}) => textStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color ?? const Color(0xFF1A1A2E),
      );

  static TextStyle subheadStyle({Color? color}) => textStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color ?? const Color(0xFF333333),
      );

  static TextStyle bodyStyle({Color? color}) => textStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? const Color(0xFF555555),
      );

  static TextStyle captionStyle({Color? color}) => textStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? const Color(0xFF9E9E9E),
      );

  static TextStyle labelStyle({Color? color}) => textStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color ?? const Color(0xFF9E9E9E),
        letterSpacing: 0.2,
      );

  /// Theme data so descendant [Text] widgets inherit Circular by default.
  static ThemeData themeData({Color? primaryColor}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor ?? _defaultPrimary,
      ),
    );
    TextStyle circularize(TextStyle? style) => (style ?? const TextStyle()).copyWith(
          fontFamily: fontFamily,
          package: fontPackage,
        );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: circularize(base.textTheme.displayLarge),
        displayMedium: circularize(base.textTheme.displayMedium),
        displaySmall: circularize(base.textTheme.displaySmall),
        headlineLarge: circularize(base.textTheme.headlineLarge),
        headlineMedium: circularize(base.textTheme.headlineMedium),
        headlineSmall: circularize(base.textTheme.headlineSmall),
        titleLarge: circularize(base.textTheme.titleLarge),
        titleMedium: circularize(base.textTheme.titleMedium),
        titleSmall: circularize(base.textTheme.titleSmall),
        bodyLarge: circularize(base.textTheme.bodyLarge),
        bodyMedium: circularize(base.textTheme.bodyMedium),
        bodySmall: circularize(base.textTheme.bodySmall),
        labelLarge: circularize(base.textTheme.labelLarge),
        labelMedium: circularize(base.textTheme.labelMedium),
        labelSmall: circularize(base.textTheme.labelSmall),
      ),
      primaryTextTheme: base.primaryTextTheme.copyWith(
        bodyLarge: circularize(base.primaryTextTheme.bodyLarge),
        bodyMedium: circularize(base.primaryTextTheme.bodyMedium),
        titleLarge: circularize(base.primaryTextTheme.titleLarge),
      ),
    );
  }

  // ── Decorations ───────────────────────────────────────────────────────────

  static BoxDecoration cardDecoration({double radius = 12}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration panelDecoration(bool isNarrow) => const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 100,
            offset: Offset(0, -8),
          ),
        ],
      );

  // ── Relative time ─────────────────────────────────────────────────────────

  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(dt);
  }
}
