import 'package:flutter/material.dart';

class EduSpaceLogoPainter extends CustomPainter {
  final Color color;
  EduSpaceLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Draw graduation cap top (diamond)
    final capPath = Path();
    capPath.moveTo(w * 0.5, h * 0.25); // top
    capPath.lineTo(w * 0.82, h * 0.38); // right
    capPath.lineTo(w * 0.5, h * 0.51); // bottom
    capPath.lineTo(w * 0.18, h * 0.38); // left
    capPath.close();
    canvas.drawPath(capPath, paint);

    // Draw cap base (hat band)
    final basePath = Path();
    basePath.moveTo(w * 0.36, h * 0.44);
    basePath.quadraticBezierTo(w * 0.5, h * 0.51, w * 0.64, h * 0.44);
    basePath.lineTo(w * 0.64, h * 0.53);
    basePath.quadraticBezierTo(w * 0.5, h * 0.60, w * 0.36, h * 0.53);
    basePath.close();
    canvas.drawPath(basePath, paint);

    // Draw tassel line
    final tasselPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;

    final tasselPath = Path();
    tasselPath.moveTo(w * 0.5, h * 0.38);
    tasselPath.lineTo(w * 0.76, h * 0.41);
    tasselPath.lineTo(w * 0.79, h * 0.54);
    canvas.drawPath(tasselPath, tasselPaint);

    // Tassel ball
    canvas.drawCircle(Offset(w * 0.79, h * 0.56), w * 0.025, paint);

    // Draw open book pages
    // Left page
    final leftPage = Path();
    leftPage.moveTo(w * 0.5, h * 0.66);
    leftPage.quadraticBezierTo(w * 0.35, h * 0.60, w * 0.20, h * 0.61);
    leftPage.lineTo(w * 0.20, h * 0.67);
    leftPage.quadraticBezierTo(w * 0.35, h * 0.66, w * 0.5, h * 0.74);
    leftPage.close();
    canvas.drawPath(leftPage, paint);

    // Right page
    final rightPage = Path();
    rightPage.moveTo(w * 0.5, h * 0.66);
    rightPage.quadraticBezierTo(w * 0.65, h * 0.60, w * 0.80, h * 0.61);
    rightPage.lineTo(w * 0.80, h * 0.67);
    rightPage.quadraticBezierTo(w * 0.65, h * 0.66, w * 0.5, h * 0.74);
    rightPage.close();
    canvas.drawPath(rightPage, paint);

    // Book cover outline (thickness underneath)
    final coverPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;

    final coverPath = Path();
    coverPath.moveTo(w * 0.22, h * 0.71);
    coverPath.quadraticBezierTo(w * 0.36, h * 0.77, w * 0.5, h * 0.80);
    coverPath.quadraticBezierTo(w * 0.64, h * 0.77, w * 0.78, h * 0.71);
    canvas.drawPath(coverPath, coverPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EduSpaceLogo extends StatelessWidget {
  final double size;
  final bool isWhiteBackground; // true: green logo on white circle, false: white logo on green circle
  final Color? customCircleColor;
  final Color? customLogoColor;

  const EduSpaceLogo({
    super.key,
    this.size = 120,
    this.isWhiteBackground = false,
    this.customCircleColor,
    this.customLogoColor,
  });

  @override
  Widget build(BuildContext context) {
    final circleColor = customCircleColor ?? 
        (isWhiteBackground ? Colors.white : const Color(0xFF1E7431));
    final logoColor = customLogoColor ?? 
        (isWhiteBackground ? const Color(0xFF1E7431) : Colors.white);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: size * 0.08,
            offset: Offset(0, size * 0.03),
          )
        ],
      ),
      padding: EdgeInsets.all(size * 0.10),
      child: CustomPaint(
        painter: EduSpaceLogoPainter(color: logoColor),
      ),
    );
  }
}
