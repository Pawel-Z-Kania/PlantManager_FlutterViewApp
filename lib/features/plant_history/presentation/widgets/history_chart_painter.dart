import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/history_gap.dart';
import '../../domain/history_series.dart';
import '../../domain/history_time_ticks.dart';
import '../../domain/history_viewport.dart';

const historyChartTopPadding = 24.0;
const historyChartBottomPadding = 56.0;
const historyAdcMax = 1024.0;
const historyVoltageAxisMax = 8.0;

const _dotsVisiblePointLimit = 40;
const _labelStyle = TextStyle(fontSize: 9);
const _gapLabelStyle = TextStyle(
  color: Colors.white,
  fontSize: 10,
  fontWeight: FontWeight.bold,
);
const _tooltipStyle = TextStyle(color: Colors.white, fontSize: 10);

final _textCache = <(String, TextStyle), TextPainter>{};

TextPainter _text(String text, TextStyle style) {
  if (_textCache.length > 300) _textCache.clear();
  return _textCache.putIfAbsent(
    (text, style),
    () => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(),
  );
}

class HistoryChartPainter extends CustomPainter {
  HistoryChartPainter({
    required this.series,
    required this.viewport,
    required this.selectedTimeMs,
    required this.wetCalibration,
    required this.dryCalibration,
    required this.loadedFromMs,
    required this.nowMs,
    required this.textColor,
  }) : super(repaint: Listenable.merge([viewport, selectedTimeMs]));

  final HistorySeries series;
  final ValueListenable<HistoryViewport> viewport;
  final ValueListenable<double?> selectedTimeMs;
  final int wetCalibration;
  final int dryCalibration;
  final double loadedFromMs;
  final double nowMs;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      0,
      historyChartTopPadding,
      size.width,
      size.height - historyChartBottomPadding,
    );
    if (plot.width <= 1 || plot.height <= 1) return;

    final vp = viewport.value;
    final msPerPx = vp.spanMs / plot.width;
    double xOf(double t) => (t - vp.startMs) / msPerPx;
    double yAdc(double v) =>
        plot.bottom -
        math.max(0.0, math.min(v, historyAdcMax)) / historyAdcMax * plot.height;
    double yVolt(double v) =>
        plot.bottom -
        math.max(0.0, math.min(v, historyVoltageAxisMax)) /
            historyVoltageAxisMax *
            plot.height;

    final ticks = buildTimeTicks(
      startMs: vp.startMs,
      endMs: vp.endMs,
      msPerPixel: msPerPx,
    );

    canvas.save();
    canvas.clipRect(plot);

    _paintGrid(canvas, plot, ticks, xOf, yAdc);
    _paintUnloaded(canvas, plot, xOf(loadedFromMs), vp.startMs / msPerPx);
    _paintGaps(canvas, plot, vp, xOf);
    _paintCalibration(canvas, plot, yAdc);

    final lo = math.max(0, series.lowerBound(vp.startMs) - 1);
    final hi = math.min(series.length - 1, series.upperBound(vp.endMs));
    if (hi >= lo) {
      _paintVoltage(canvas, lo, hi, xOf, yVolt);
      _paintMoisture(canvas, plot, lo, hi, xOf, yAdc);
    }

    final nowX = xOf(nowMs);
    if (nowX >= plot.left && nowX <= plot.right) {
      canvas.drawLine(
        Offset(nowX, plot.top),
        Offset(nowX, plot.bottom),
        Paint()
          ..color = Colors.green.shade800.withValues(alpha: 0.8)
          ..strokeWidth = 2,
      );
    }

    _paintGapLabels(canvas, plot, vp, xOf);
    _paintCursor(canvas, plot, xOf, yAdc);

    canvas.restore();

    canvas.drawRect(
      plot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = textColor.withValues(alpha: 0.3),
    );
    _paintTimeLabels(canvas, size, plot, ticks, xOf);
  }

  void _paintGrid(
    Canvas canvas,
    Rect plot,
    List<TimeTick> ticks,
    double Function(double) xOf,
    double Function(double) yAdc,
  ) {
    final minor = Path();
    final major = Path();
    for (var v = 0.0; v <= historyAdcMax; v += 256) {
      _addDashedH(minor, plot.left, plot.right, yAdc(v));
    }
    for (final tick in ticks) {
      _addDashedV(
        tick.isDayStart ? major : minor,
        xOf(tick.timeMs),
        plot.top,
        plot.bottom,
      );
    }
    canvas.drawPath(
      minor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.blueGrey.withValues(alpha: 0.2),
    );
    canvas.drawPath(
      major,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.blueGrey.withValues(alpha: 0.35),
    );
  }

  // Zakres starszy niż załadowane dane: kreskowanie przesuwa się razem z treścią.
  void _paintUnloaded(
    Canvas canvas,
    Rect plot,
    double edgeX,
    double contentOffsetPx,
  ) {
    if (edgeX <= plot.left) return;
    final rect = Rect.fromLTRB(
      plot.left,
      plot.top,
      math.min(edgeX, plot.right),
      plot.bottom,
    );
    canvas.drawRect(
      rect,
      Paint()..color = Colors.blueGrey.withValues(alpha: 0.06),
    );

    const spacing = 12.0;
    final offset = contentOffsetPx % spacing;
    final hatch = Path();
    for (var x = rect.left - rect.height - offset; x < rect.right; x += spacing) {
      hatch
        ..moveTo(x, rect.bottom)
        ..lineTo(x + rect.height, rect.top);
    }
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawPath(
      hatch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.blueGrey.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  void _paintGaps(
    Canvas canvas,
    Rect plot,
    HistoryViewport vp,
    double Function(double) xOf,
  ) {
    final paint = Paint()..color = Colors.grey.withValues(alpha: 0.18);
    for (var g = 0; g < series.gapStartMs.length; g++) {
      if (series.gapEndMs[g] < vp.startMs) continue;
      if (series.gapStartMs[g] > vp.endMs) break;
      canvas.drawRect(
        Rect.fromLTRB(
          xOf(series.gapStartMs[g]),
          plot.top,
          xOf(series.gapEndMs[g]),
          plot.bottom,
        ),
        paint,
      );
    }
  }

  void _paintCalibration(
    Canvas canvas,
    Rect plot,
    double Function(double) yAdc,
  ) {
    void line(int value, Color color) {
      final path = Path();
      _addDashedH(path, plot.left, plot.right, yAdc(value.toDouble()), 5, 5);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.5),
      );
    }

    line(wetCalibration, Colors.blue);
    line(dryCalibration, Colors.orange);
  }

  void _paintVoltage(
    Canvas canvas,
    int lo,
    int hi,
    double Function(double) xOf,
    double Function(double) yVolt,
  ) {
    final line = Path();
    final isolated = <Offset>[];
    _trace(
      values: series.voltages,
      lo: lo,
      hi: hi,
      xOf: xOf,
      yOf: yVolt,
      line: line,
      isolated: isolated,
    );
    final color = Colors.grey.shade600;
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    final dotPaint = Paint()..color = color;
    for (final dot in isolated) {
      canvas.drawCircle(dot, 1.5, dotPaint);
    }
  }

  void _paintMoisture(
    Canvas canvas,
    Rect plot,
    int lo,
    int hi,
    double Function(double) xOf,
    double Function(double) yAdc,
  ) {
    final line = Path();
    final fill = Path();
    final isolated = <Offset>[];
    _trace(
      values: series.values,
      lo: lo,
      hi: hi,
      xOf: xOf,
      yOf: yAdc,
      line: line,
      fill: fill,
      baseline: plot.bottom,
      isolated: isolated,
    );
    final color = Colors.green.shade600;
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.1));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    final dotPaint = Paint()..color = color;
    if (hi - lo + 1 <= _dotsVisiblePointLimit) {
      for (var i = lo; i <= hi; i++) {
        canvas.drawCircle(Offset(xOf(series.times[i]), yAdc(series.values[i])), 2.5, dotPaint);
      }
    } else {
      for (final dot in isolated) {
        canvas.drawCircle(dot, 2.5, dotPaint);
      }
    }
  }

  // Jedna ścieżka dla wszystkich segmentów; NaN i luki przerywają linię.
  void _trace({
    required Float64List values,
    required int lo,
    required int hi,
    required double Function(double) xOf,
    required double Function(double) yOf,
    required Path line,
    required List<Offset> isolated,
    Path? fill,
    double baseline = 0,
  }) {
    var segmentCount = 0;
    var firstX = 0.0;
    var firstY = 0.0;
    var lastX = 0.0;

    void endSegment() {
      if (segmentCount == 1) isolated.add(Offset(firstX, firstY));
      if (fill != null && segmentCount >= 2) {
        fill
          ..lineTo(lastX, baseline)
          ..lineTo(firstX, baseline)
          ..close();
      }
      segmentCount = 0;
    }

    for (var i = lo; i <= hi; i++) {
      final v = values[i];
      if (v.isNaN) {
        endSegment();
        continue;
      }
      final x = xOf(series.times[i]);
      final y = yOf(v);
      if (segmentCount == 0) {
        line.moveTo(x, y);
        fill?.moveTo(x, y);
        firstX = x;
        firstY = y;
      } else {
        line.lineTo(x, y);
        fill?.lineTo(x, y);
      }
      lastX = x;
      segmentCount++;
      if (series.breaksAfter(i)) endSegment();
    }
    endSegment();
  }

  void _paintGapLabels(
    Canvas canvas,
    Rect plot,
    HistoryViewport vp,
    double Function(double) xOf,
  ) {
    for (var g = 0; g < series.gaps.length; g++) {
      final start = math.max(series.gapStartMs[g], vp.startMs);
      final end = math.min(series.gapEndMs[g], vp.endMs);
      if (end <= start) continue;

      final tp = _text(
        'Brak danych: ${formatGapDuration(series.gaps[g].duration)}',
        _gapLabelStyle,
      );
      final visibleWidth = xOf(end) - xOf(start);
      if (visibleWidth < tp.width + 8) continue;

      final center = (xOf(start) + xOf(end)) / 2;
      final box = Rect.fromCenter(
        center: Offset(center, plot.top + 14),
        width: tp.width + 10,
        height: tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        Paint()..color = Colors.blueGrey.shade700.withValues(alpha: 0.85),
      );
      tp.paint(canvas, Offset(box.left + 5, box.top + 3));
    }
  }

  void _paintCursor(
    Canvas canvas,
    Rect plot,
    double Function(double) xOf,
    double Function(double) yAdc,
  ) {
    final selected = selectedTimeMs.value;
    if (selected == null || series.length == 0) return;
    final i = series.nearestIndex(selected);
    final x = xOf(series.times[i]);
    if (x < plot.left || x > plot.right) return;
    final y = yAdc(series.values[i]);

    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..strokeWidth = 1
        ..color = textColor.withValues(alpha: 0.5),
    );
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.green.shade800);

    final t = DateTime.fromMillisecondsSinceEpoch(series.times[i].toInt());
    final label =
        '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}\n'
        '${series.values[i].toInt()} ADC';
    final tp = _text(label, _tooltipStyle);
    final width = tp.width + 12;
    final left = x + 8 + width <= plot.right ? x + 8 : x - 8 - width;
    final box = Rect.fromLTWH(left, plot.top + 4, width, tp.height + 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = Colors.blueGrey.shade900.withValues(alpha: 0.9),
    );
    tp.paint(canvas, Offset(box.left + 6, box.top + 4));
  }

  void _paintTimeLabels(
    Canvas canvas,
    Size size,
    Rect plot,
    List<TimeTick> ticks,
    double Function(double) xOf,
  ) {
    final style = _labelStyle.copyWith(color: textColor);
    final tickPaint = Paint()
      ..strokeWidth = 1
      ..color = textColor.withValues(alpha: 0.5);
    for (final tick in ticks) {
      final x = xOf(tick.timeMs);
      canvas.drawLine(Offset(x, plot.bottom), Offset(x, plot.bottom + 3), tickPaint);

      final tp = _text(tick.label, style);
      final left = x - tp.width / 2;
      if (left < 0 || left + tp.width > size.width) continue;
      tp.paint(canvas, Offset(left, plot.bottom + 5));

      final dateLine = tick.dateLine;
      if (dateLine == null) continue;
      final dp = _text(dateLine, style);
      final dateLeft = math.max(0.0, math.min(x - dp.width / 2, size.width - dp.width));
      dp.paint(canvas, Offset(dateLeft, plot.bottom + 6 + tp.height));
    }
  }

  void _addDashedH(Path path, double x1, double x2, double y, [double dash = 8, double gap = 4]) {
    for (var x = x1; x < x2; x += dash + gap) {
      path
        ..moveTo(x, y)
        ..lineTo(math.min(x + dash, x2), y);
    }
  }

  void _addDashedV(Path path, double x, double y1, double y2, [double dash = 8, double gap = 4]) {
    for (var y = y1; y < y2; y += dash + gap) {
      path
        ..moveTo(x, y)
        ..lineTo(x, math.min(y + dash, y2));
    }
  }

  @override
  bool shouldRepaint(covariant HistoryChartPainter oldDelegate) {
    return !identical(series, oldDelegate.series) ||
        wetCalibration != oldDelegate.wetCalibration ||
        dryCalibration != oldDelegate.dryCalibration ||
        loadedFromMs != oldDelegate.loadedFromMs ||
        nowMs != oldDelegate.nowMs ||
        textColor != oldDelegate.textColor;
  }
}
