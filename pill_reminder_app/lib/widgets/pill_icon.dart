import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PillIcon extends StatelessWidget {
  final int colorIndex;
  final double size;

  const PillIcon({
    super.key,
    this.colorIndex = 0,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.pillColors[colorIndex % AppColors.pillColors.length];
    final darkerColor = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness - 0.15).clamp(0.0, 1.0))
        .toColor();

    return Container(
      width: size * 0.25,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.125),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, darkerColor],
          stops: const [0.5, 0.5],
        ),
      ),
    );
  }
}
