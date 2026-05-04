import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen AR targeting reticle drawn on a [CustomPainter].
///
/// Shows four corner brackets that frame the scan area, a central crosshair,
/// and — while scanning — a rotating arc drawn with a glow blur effect.
class ScanReticle extends StatefulWidget {
  final Color color;
  final bool isScanning;

  const ScanReticle({
    super.key,
    required this.color,
    this.isScanning = false,
  });

  @override
  State<ScanReticle> createState() => _ScanReticleState();
}

class _ScanReticleState extends State<ScanReticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotController;

  @override
  void initState() {
    super.initState();
    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width:  220,
        height: 220,
        child: AnimatedBuilder(
          animation: _rotController,
          builder: (_, __) => CustomPaint(
            painter: _ReticlePainter(
              color:      widget.color,
              progress:   _rotController.value,
              isScanning: widget.isScanning,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color  color;
  final double progress;
  final bool   isScanning;

  const _ReticlePainter({
    required this.color,
    required this.progress,
    required this.isScanning,
  });

  static const double _cornerLen  = 28;
  static const double _strokeW    = 2.5;
  static const double _innerSize  = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect   = Rect.fromCenter(center: center, width: size.width, height: size.height);

    final solidPaint = Paint()
      ..color      = color
      ..strokeWidth = _strokeW
      ..style      = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color      = color.withOpacity(0.28)
      ..strokeWidth = _strokeW * 3.5
      ..style      = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    // Corner brackets (glow first, then solid on top)
    _drawCorners(canvas, rect, glowPaint);
    _drawCorners(canvas, rect, solidPaint);

    // Central crosshair square
    final crossPaint = Paint()
      ..color      = color.withOpacity(0.55)
      ..strokeWidth = 1.5
      ..style      = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromCenter(center: center, width: _innerSize, height: _innerSize),
      crossPaint,
    );

    // Scanning arc
    if (isScanning) {
      final arcRect   = Rect.fromCenter(
        center: center,
        width:  size.width  - 18,
        height: size.height - 18,
      );
      final startAngle = -math.pi / 2 + (2 * math.pi * progress);
      const sweepAngle = math.pi * 1.25;

      canvas.drawArc(
        arcRect, startAngle, sweepAngle, false,
        Paint()
          ..color       = color.withOpacity(0.22)
          ..strokeWidth = 7
          ..style       = PaintingStyle.stroke
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawArc(
        arcRect, startAngle, sweepAngle, false,
        Paint()
          ..color       = color.withOpacity(0.9)
          ..strokeWidth = 2.2
          ..style       = PaintingStyle.stroke,
      );
    }
  }

  void _drawCorners(Canvas canvas, Rect r, Paint p) {
    final l = r.left, t = r.top, b = r.bottom, rr = r.right;
    // Top-left
    canvas.drawLine(Offset(l, t + _cornerLen), Offset(l, t), p);
    canvas.drawLine(Offset(l, t), Offset(l + _cornerLen, t), p);
    // Top-right
    canvas.drawLine(Offset(rr - _cornerLen, t), Offset(rr, t), p);
    canvas.drawLine(Offset(rr, t), Offset(rr, t + _cornerLen), p);
    // Bottom-left
    canvas.drawLine(Offset(l, b - _cornerLen), Offset(l, b), p);
    canvas.drawLine(Offset(l, b), Offset(l + _cornerLen, b), p);
    // Bottom-right
    canvas.drawLine(Offset(rr - _cornerLen, b), Offset(rr, b), p);
    canvas.drawLine(Offset(rr, b), Offset(rr, b - _cornerLen), p);
  }

  @override
  bool shouldRepaint(_ReticlePainter old) =>
      old.color != color || old.progress != progress || old.isScanning != isScanning;
}
