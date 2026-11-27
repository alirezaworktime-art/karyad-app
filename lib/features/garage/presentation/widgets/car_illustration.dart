import 'package:material_ui/material_ui.dart';

import '../../../catalog/domain/body_type.dart';

/// Karyad's own flat side-view car drawing, one shape per body type, in
/// the user's car color. Deliberately generic: no maker logos or model
/// designs.
class CarIllustration extends StatelessWidget {
  const CarIllustration({
    super.key,
    required this.bodyType,
    required this.color,
    this.taxiSign = false,
    this.width = 240,
    this.semanticLabel,
  });

  final BodyType bodyType;
  final Color color;
  final bool taxiSign;
  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: SizedBox(
        width: width,
        height: width * 100 / 240,
        child: CustomPaint(
          painter: _CarPainter(
            bodyType: bodyType,
            color: color,
            taxiSign: taxiSign,
          ),
        ),
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  _CarPainter({
    required this.bodyType,
    required this.color,
    required this.taxiSign,
  });

  final BodyType bodyType;
  final Color color;
  final bool taxiSign;

  static const _wheel = Color(0xFF2A2340);
  static const _hub = Color(0xFFCFCBD9);
  static const _shadow = Color(0xFFD9D0EC);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 240, size.height / 100);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(122, 89), width: 208, height: 12),
      Paint()..color = _shadow,
    );

    if (taxiSign) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(108, 9, 34, 12),
          const Radius.circular(3),
        ),
        Paint()..color = _wheel,
      );
    }

    final body = _bodyPath();
    canvas.drawPath(body, Paint()..color = color);
    // A white car needs an outline to stand out from a light background.
    if (color.computeLuminance() > 0.85) {
      canvas.drawPath(
        body,
        Paint()
          ..color = const Color(0xFFC9BFE0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final glass = Paint()
      ..color = Color.lerp(color, Colors.white, 0.7)!.withValues(alpha: 0.95);
    for (final window in _windows()) {
      canvas.drawPath(window, glass);
    }

    final wheels = _wheels();
    for (final (center, radius) in wheels) {
      canvas.drawCircle(center, radius, Paint()..color = _wheel);
      canvas.drawCircle(center, radius * 0.4, Paint()..color = _hub);
    }
  }

  Path _bodyPath() => switch (bodyType) {
    BodyType.sedan =>
      Path()
        ..moveTo(20, 72)
        ..lineTo(20, 58)
        ..quadraticBezierTo(22, 50, 34, 48)
        ..lineTo(70, 44)
        ..lineTo(92, 26)
        ..quadraticBezierTo(98, 22, 108, 22)
        ..lineTo(150, 22)
        ..quadraticBezierTo(160, 22, 168, 30)
        ..lineTo(184, 44)
        ..lineTo(214, 48)
        ..quadraticBezierTo(224, 50, 224, 60)
        ..lineTo(224, 72)
        ..close(),
    BodyType.hatchback =>
      Path()
        ..moveTo(20, 72)
        ..lineTo(20, 56)
        ..quadraticBezierTo(22, 48, 34, 46)
        ..lineTo(66, 42)
        ..lineTo(88, 24)
        ..quadraticBezierTo(94, 20, 104, 20)
        ..lineTo(170, 20)
        ..quadraticBezierTo(180, 20, 186, 28)
        ..lineTo(200, 46)
        ..quadraticBezierTo(206, 50, 206, 60)
        ..lineTo(206, 72)
        ..close(),
    BodyType.suv =>
      Path()
        ..moveTo(20, 74)
        ..lineTo(20, 50)
        ..quadraticBezierTo(22, 40, 34, 38)
        ..lineTo(58, 36)
        ..lineTo(78, 16)
        ..quadraticBezierTo(84, 12, 94, 12)
        ..lineTo(186, 12)
        ..quadraticBezierTo(198, 12, 204, 22)
        ..lineTo(214, 40)
        ..quadraticBezierTo(222, 44, 222, 54)
        ..lineTo(222, 74)
        ..close(),
    BodyType.pickup =>
      Path()
        ..moveTo(20, 72)
        ..lineTo(20, 56)
        ..quadraticBezierTo(22, 48, 34, 46)
        ..lineTo(60, 44)
        ..lineTo(80, 24)
        ..quadraticBezierTo(86, 20, 96, 20)
        ..lineTo(128, 20)
        ..lineTo(128, 46)
        ..lineTo(222, 46)
        ..lineTo(222, 72)
        ..close(),
  };

  List<Path> _windows() => switch (bodyType) {
    BodyType.sedan => [
      Path()
        ..moveTo(100, 30)
        ..lineTo(86, 44)
        ..lineTo(127, 44)
        ..lineTo(127, 30)
        ..close(),
      Path()
        ..moveTo(133, 30)
        ..lineTo(133, 44)
        ..lineTo(176, 44)
        ..lineTo(164, 32)
        ..quadraticBezierTo(161, 30, 155, 30)
        ..close(),
    ],
    BodyType.hatchback => [
      Path()
        ..moveTo(96, 28)
        ..lineTo(82, 42)
        ..lineTo(132, 42)
        ..lineTo(132, 28)
        ..close(),
      Path()
        ..moveTo(138, 28)
        ..lineTo(138, 42)
        ..lineTo(190, 42)
        ..lineTo(180, 30)
        ..quadraticBezierTo(177, 28, 171, 28)
        ..close(),
    ],
    BodyType.suv => [
      Path()
        ..moveTo(86, 20)
        ..lineTo(70, 36)
        ..lineTo(134, 36)
        ..lineTo(134, 20)
        ..close(),
      Path()
        ..moveTo(140, 20)
        ..lineTo(140, 36)
        ..lineTo(206, 36)
        ..lineTo(198, 24)
        ..quadraticBezierTo(195, 20, 188, 20)
        ..close(),
    ],
    BodyType.pickup => [
      Path()
        ..moveTo(88, 28)
        ..lineTo(74, 42)
        ..lineTo(120, 42)
        ..lineTo(120, 28)
        ..close(),
    ],
  };

  List<(Offset, double)> _wheels() => switch (bodyType) {
    BodyType.sedan => [(const Offset(64, 74), 15), (const Offset(182, 74), 15)],
    BodyType.hatchback => [
      (const Offset(62, 74), 15),
      (const Offset(168, 74), 15),
    ],
    BodyType.suv => [(const Offset(66, 76), 17), (const Offset(180, 76), 17)],
    BodyType.pickup => [
      (const Offset(62, 74), 15),
      (const Offset(186, 74), 15),
    ],
  };

  @override
  bool shouldRepaint(_CarPainter old) =>
      old.bodyType != bodyType ||
      old.color != color ||
      old.taxiSign != taxiSign;
}
