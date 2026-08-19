import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MpIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  final String? semanticLabel;

  const MpIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$asset.svg',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}
