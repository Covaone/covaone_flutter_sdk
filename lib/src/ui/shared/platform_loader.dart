import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A platform-aware loading indicator.
///
/// Renders a [CupertinoActivityIndicator] on iOS (black by default)
/// and a [CircularProgressIndicator] on all other platforms.
///
/// [color] — tint colour applied to the indicator on both platforms.
/// [strokeWidth] — stroke width for the Android [CircularProgressIndicator].
/// [size] — explicit diameter; drives `radius` on iOS and wraps the Android
///   indicator in a fixed-size [SizedBox]. When null, each indicator uses
///   its own intrinsic default size.
class PlatformLoader extends StatelessWidget {
  final Color? color;
  final double strokeWidth;
  final double? size;

  const PlatformLoader({
    super.key,
    this.color,
    this.strokeWidth = 4.0,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoActivityIndicator(
        color: color ?? Colors.black,
        radius: size != null ? size! / 2 : 10.0,
      );
    }

    final indicator = CircularProgressIndicator(
      color: color,
      strokeWidth: strokeWidth,
    );

    if (size != null) {
      return SizedBox.square(dimension: size, child: indicator);
    }
    return indicator;
  }
}
