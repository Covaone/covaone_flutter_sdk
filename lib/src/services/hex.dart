import 'package:flutter/material.dart';
import 'package:covaone_sdk/covaone_sdk.dart';

Covaone covaone = Covaone.instance;

mixin AppResouces {
  final Color primaryColor =
      HexConvert.hColor(covaone.initializerModel.configuration?.color);
}

class HexConvert extends Color {
  static Color hColor(String? hex, {double? o}) {
    if (hex == null || hex.isEmpty) return null!;

    hex = hex.replaceFirst('#', '');

    final RegExp hexRegex = RegExp(r'^(?:[0-9a-fA-F]{3}){1,2}$');
    if (!hexRegex.hasMatch(hex)) return null!;

    if (hex.length == 3) {
      hex = hex.split('').map((char) => char + char).join('');
    }

    final int er = int.parse(hex, radix: 16);
    final int r = (er >> 16) & 255, g = (er >> 8) & 255, b = er & 255;

    return Color.fromRGBO(r, g, b, (o ?? 1));
  }

  HexConvert(final String? hexColor) : super(0);
}
