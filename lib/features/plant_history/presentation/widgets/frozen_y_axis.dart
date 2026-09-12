import 'package:flutter/material.dart';

class FrozenYAxis extends StatelessWidget {
  const FrozenYAxis({
    super.key,
    required this.topPadding,
    required this.bottomPadding,
    required this.wetCalibration,
    required this.dryCalibration,
  });

  final double topPadding;
  final double bottomPadding;
  final int wetCalibration;
  final int dryCalibration;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FrozenYAxisPainter(
        topPadding: topPadding,
        bottomPadding: bottomPadding,
        wetCalibration: wetCalibration,
        dryCalibration: dryCalibration,
        textColor: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _FrozenYAxisPainter extends CustomPainter {
  const _FrozenYAxisPainter({
    required this.topPadding,
    required this.bottomPadding,
    required this.wetCalibration,
    required this.dryCalibration,
    required this.textColor,
  });

  final double topPadding;
  final double bottomPadding;
  final int wetCalibration;
  final int dryCalibration;
  final Color textColor;

  static const _maxValue = 1024.0;
  static const _interval = 256.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotTop = topPadding;
    final plotBottom = size.height - bottomPadding;
    final plotHeight = plotBottom - plotTop;
    if (plotHeight <= 0) return;

    final axisX = size.width - 1;
    final axisPaint = Paint()
      ..color = textColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(axisX, plotTop), Offset(axisX, plotBottom), axisPaint);

    for (var value = 0.0; value <= _maxValue; value += _interval) {
      final y = plotBottom - (value / _maxValue * plotHeight);
      canvas.drawLine(Offset(axisX - 4, y), Offset(axisX, y), axisPaint);
      _drawLabel(canvas, size, value.toInt().toString(), y, textColor);
    }

    _drawCalibrationLabel(canvas, size, 'Mokro', wetCalibration, Colors.blue, plotTop, plotHeight);
    _drawCalibrationLabel(canvas, size, 'Sucho', dryCalibration, Colors.orange, plotTop, plotHeight);
  }

  void _drawLabel(Canvas canvas, Size size, String label, double centerY, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 6);
    textPainter.paint(canvas, Offset(size.width - 6 - textPainter.width, centerY - textPainter.height / 2));
  }

  void _drawCalibrationLabel(
    Canvas canvas,
    Size size,
    String label,
    int value,
    Color color,
    double plotTop,
    double plotHeight,
  ) {
    if (value < 0 || value > _maxValue) return;
    final y = plotTop + (1 - value / _maxValue) * plotHeight;
    _drawLabel(canvas, size, label, y, color);
  }

  @override
  bool shouldRepaint(covariant _FrozenYAxisPainter oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        bottomPadding != oldDelegate.bottomPadding ||
        wetCalibration != oldDelegate.wetCalibration ||
        dryCalibration != oldDelegate.dryCalibration ||
        textColor != oldDelegate.textColor;
  }
}