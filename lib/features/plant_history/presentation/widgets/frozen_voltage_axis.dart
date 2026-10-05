import 'package:flutter/material.dart';
import 'history_chart_painter.dart';

/// Prawa oś Y z napięciem baterii (V), wyrównana do pola wykresu.
class FrozenVoltageAxis extends StatelessWidget {
  const FrozenVoltageAxis({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _VoltageAxisPainter(color: Colors.grey.shade700));
  }
}

class _VoltageAxisPainter extends CustomPainter {
  const _VoltageAxisPainter({required this.color});

  final Color color;

  static const _step = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotTop = historyChartTopPadding;
    final plotBottom = size.height - historyChartBottomPadding;
    final plotHeight = plotBottom - plotTop;
    if (plotHeight <= 0) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, plotTop), Offset(0, plotBottom), paint);

    for (var v = 0.0; v <= historyVoltageAxisMax; v += _step) {
      final y = plotBottom - v / historyVoltageAxisMax * plotHeight;
      canvas.drawLine(Offset(0, y), Offset(4, y), paint);
      final tp = TextPainter(
        text: TextSpan(
          text: '${v.toInt()} V',
          style: TextStyle(color: color, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 6);
      tp.paint(canvas, Offset(6, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _VoltageAxisPainter oldDelegate) =>
      color != oldDelegate.color;
}
