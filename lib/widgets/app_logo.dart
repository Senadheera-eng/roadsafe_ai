import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({Key? key, this.size = 40}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
