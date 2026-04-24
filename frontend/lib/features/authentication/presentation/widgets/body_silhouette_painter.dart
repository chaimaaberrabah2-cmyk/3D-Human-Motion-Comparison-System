import 'package:flutter/material.dart';

/// Draws a highly stylized glowing vector outline of a human body, adjusting
/// its shape based on gender, height, and weight.
class BodySilhouettePainter extends CustomPainter {
  final bool isMale;
  final double heightScale; // 0.0 to 1.0
  final double weightScale; // 0.0 to 1.0
  final bool isNeonActive;
  final Color baseColor;

  BodySilhouettePainter({
    required this.isMale,
    required this.heightScale,
    required this.weightScale,
    this.isNeonActive = true,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    final verticalStretch = 0.65 + (heightScale * 0.35); // 0.65 to 1.0
    final drawAreaHeight = size.height * verticalStretch;
    
    // Weight dictates how thick the torso and limbs get.
    final weightFactor = weightScale; // 0.0 to 1.0

    // Define anchor points 
    final centerX = size.width / 2;
    final baseY = size.height - 25.0; // Rest on the ground
    final topY = baseY - drawAreaHeight;

    // Head proportions
    final headRadius = drawAreaHeight * 0.055;
    
    // Body Widths
    double shoulderW;
    double waistW;
    double hipW;
    double thighW;
    double calfW;
    double armW;

    if (isMale) {
      // Male Base proportions
      shoulderW = size.width * 0.38 + (weightFactor * 50);
      waistW = size.width * 0.22 + (weightFactor * 60);
      hipW = size.width * 0.24 + (weightFactor * 50);
      thighW = 32.0 + (weightFactor * 25);
      calfW = 20.0 + (weightFactor * 15);
      armW = 16.0 + (weightFactor * 15);
    } else {
      // Female Base proportions (Hourglass)
      shoulderW = size.width * 0.30 + (weightFactor * 40);
      waistW = size.width * 0.18 + (weightFactor * 55);
      hipW = size.width * 0.32 + (weightFactor * 65);
      thighW = 35.0 + (weightFactor * 35); // Women carry more lower weight
      calfW = 18.0 + (weightFactor * 15);
      armW = 14.0 + (weightFactor * 15);
    }

    final path = _buildRealisticPath(
      centerX: centerX,
      topY: topY,
      baseY: baseY,
      headRadius: headRadius,
      shoulderW: shoulderW,
      waistW: waistW,
      hipW: hipW,
      thighW: thighW,
      calfW: calfW,
      armW: armW,
      isMale: isMale,
      heightTotal: drawAreaHeight,
    );

    if (isNeonActive) {
      canvas.drawPath(path, glowPaint);
    }
    canvas.drawPath(path, paint);
  }

  Path _buildRealisticPath({
    required double centerX,
    required double topY,
    required double baseY,
    required double headRadius,
    required double shoulderW,
    required double waistW,
    required double hipW,
    required double thighW,
    required double calfW,
    required double armW,
    required bool isMale,
    required double heightTotal,
  }) {
    final Path p = Path();

    // Body segments purely defined by proportional heights
    final headCenterY = topY + headRadius;
    final neckY = headCenterY + headRadius * 1.2;
    final shoulderY = neckY + heightTotal * (isMale ? 0.05 : 0.06);
    final chestY = shoulderY + heightTotal * 0.12;
    final waistY = shoulderY + heightTotal * 0.28;
    final hipY = waistY + heightTotal * 0.12;
    final crotchY = hipY + heightTotal * 0.08;
    final kneeY = crotchY + heightTotal * 0.20;
    final ankleY = baseY - heightTotal * 0.05;

    // 1. HEAD (Oval, slightly taller than wide)
    p.addOval(Rect.fromCenter(
      center: Offset(centerX, headCenterY), 
      width: headRadius * 1.8, 
      height: headRadius * 2.2
    ));

    // 2. NECK
    p.moveTo(centerX - headRadius * 0.4, neckY);
    p.lineTo(centerX + headRadius * 0.4, neckY);

    // 3. MAIN BODY CONTOUR (Left and Right symmetric loops)
    Path outline = Path();
    
    // -- LEFT SIDE --
    outline.moveTo(centerX, neckY);
    
    // Neck to Shoulder (slope)
    outline.quadraticBezierTo(
      centerX - shoulderW * 0.2, neckY, 
      centerX - shoulderW / 2, shoulderY
    );
    
    // Shoulder to Armpit
    outline.quadraticBezierTo(
      centerX - shoulderW / 2 - 10, shoulderY + 20, 
      centerX - shoulderW / 2 + (isMale ? 15 : 20), chestY
    );

    // Armpit (Chest) to Waist
    outline.cubicTo(
      centerX - shoulderW / 2 + 10, chestY + 20, 
      centerX - waistW / 2 - (isMale ? 5 : 10), waistY - 20, 
      centerX - waistW / 2, waistY
    );

    // Waist to Hip 
    outline.cubicTo(
      centerX - waistW / 2 - 5, waistY + 20, 
      centerX - hipW / 2, hipY - 20, 
      centerX - hipW / 2, hipY
    );

    // Hip down outer thigh to knee
    outline.cubicTo(
      centerX - hipW / 2, hipY + 40,
      centerX - thighW * 1.2, kneeY - 30,
      centerX - thighW, kneeY
    );

    // Outer knee to ankle
    outline.quadraticBezierTo(
      centerX - calfW * 1.2, (kneeY + ankleY) / 2, 
      centerX - calfW, ankleY
    );

    // Left Foot
    outline.quadraticBezierTo(
      centerX - calfW - 15, baseY, 
      centerX - 5, baseY
    );

    // Inner ankle to inner knee
    outline.lineTo(centerX - 10, kneeY);

    // Inner knee to crotch
    outline.quadraticBezierTo(
      centerX - thighW * 0.3, (kneeY + crotchY) / 2, 
      centerX - 2, crotchY
    );

    // -- RIGHT SIDE (Mirror) --
    outline.lineTo(centerX + 2, crotchY);

    // Crotch to inner knee
    outline.quadraticBezierTo(
      centerX + thighW * 0.3, (kneeY + crotchY) / 2, 
      centerX + 10, kneeY
    );

    // Inner knee to inner ankle
    outline.lineTo(centerX + 5, baseY);

    // Right Foot
    outline.quadraticBezierTo(
      centerX + calfW + 15, baseY, 
      centerX + calfW, ankleY
    );

    // Outer ankle to outer knee
    outline.quadraticBezierTo(
      centerX + calfW * 1.2, (kneeY + ankleY) / 2, 
      centerX + thighW, kneeY
    );

    // Outer knee to hip
    outline.cubicTo(
      centerX + thighW * 1.2, kneeY - 30,
      centerX + hipW / 2, hipY + 40,
      centerX + hipW / 2, hipY
    );

    // Hip to waist
    outline.cubicTo(
      centerX + hipW / 2, hipY - 20, 
      centerX + waistW / 2 + 5, waistY + 20, 
      centerX + waistW / 2, waistY
    );

    // Waist to Armpit (Chest)
    outline.cubicTo(
      centerX + waistW / 2 + (isMale ? 5 : 10), waistY - 20, 
      centerX + shoulderW / 2 - 10, chestY + 20, 
      centerX + shoulderW / 2 - (isMale ? 15 : 20), chestY
    );

    // Armpit to Shoulder
    outline.quadraticBezierTo(
      centerX + shoulderW / 2 + 10, shoulderY + 20, 
      centerX + shoulderW / 2, shoulderY
    );

    // Shoulder to neck
    outline.quadraticBezierTo(
      centerX + shoulderW * 0.2, neckY, 
      centerX, neckY
    );

    // 4. ARMS
    final armPath = Path();
    final armLength = heightTotal * 0.40;
    
    // Left Arm
    final leftShoulderX = centerX - shoulderW / 2;
    armPath.moveTo(leftShoulderX, shoulderY);
    
    // Outer left arm
    armPath.quadraticBezierTo(
      leftShoulderX - armW * 2, shoulderY + armLength * 0.4, 
      leftShoulderX - armW * 1.5, shoulderY + armLength
    );
    // Left hand
    armPath.quadraticBezierTo(
      leftShoulderX - armW * 1.5 - 10, shoulderY + armLength + 20, 
      leftShoulderX - armW * 0.5, shoulderY + armLength
    );
    // Inner left arm
    armPath.quadraticBezierTo(
      leftShoulderX - armW, shoulderY + armLength * 0.4, 
      centerX - shoulderW / 2 + (isMale ? 15 : 20), chestY // back to armpit
    );

    // Right Arm 
    final rightShoulderX = centerX + shoulderW / 2;
    armPath.moveTo(rightShoulderX, shoulderY);
    
    // Outer right arm
    armPath.quadraticBezierTo(
      rightShoulderX + armW * 2, shoulderY + armLength * 0.4, 
      rightShoulderX + armW * 1.5, shoulderY + armLength
    );
    // Right hand
    armPath.quadraticBezierTo(
      rightShoulderX + armW * 1.5 + 10, shoulderY + armLength + 20, 
      rightShoulderX + armW * 0.5, shoulderY + armLength
    );
    // Inner right arm
    armPath.quadraticBezierTo(
      rightShoulderX + armW, shoulderY + armLength * 0.4, 
      centerX + shoulderW / 2 - (isMale ? 15 : 20), chestY // back to armpit
    );

    p.addPath(outline, Offset.zero);
    p.addPath(armPath, Offset.zero);

    return p;
  }

  @override
  bool shouldRepaint(covariant BodySilhouettePainter oldDelegate) {
    return oldDelegate.isMale != isMale ||
           oldDelegate.heightScale != heightScale ||
           oldDelegate.weightScale != weightScale ||
           oldDelegate.isNeonActive != isNeonActive ||
           oldDelegate.baseColor != baseColor;
  }
}
