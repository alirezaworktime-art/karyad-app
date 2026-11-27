import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme.dart';

/// The Karyad mark: an odometer arc with a check and an amber dot for the
/// next service, on a violet rounded square.
class KaryadLogo extends StatelessWidget {
  const KaryadLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'کاریاد',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _LogoPainter()),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 120, 120),
        const Radius.circular(30),
      ),
      Paint()..color = BrandColors.violet,
    );
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Arc centered (60,58), r=34, from bottom-left over the top to
    // bottom-right (135° → 405° in screen angles).
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(60, 58), radius: 34),
      math.pi * 3 / 4,
      math.pi * 3 / 2,
      false,
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(46, 64)
        ..lineTo(56, 74)
        ..lineTo(76, 50),
      stroke,
    );
    canvas.drawCircle(
      Offset(60 + 34 * math.cos(math.pi / 4), 58 + 34 * math.sin(math.pi / 4)),
      9.5,
      Paint()..color = BrandColors.amber,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
