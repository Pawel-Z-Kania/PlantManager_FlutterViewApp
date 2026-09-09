import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/history_gap_detector.dart';
import '../../domain/history_measurement.dart';

/// Próg luki = mediana odstępów (lub fallback) pomnożona przez ten współczynnik.
const _gapFactor = 3.5;

class HistoryChart extends StatefulWidget {
  const HistoryChart({
    super.key,
    required this.data,
    required this.wetCalibration,
    required this.dryCalibration,
    required this.windowHours,
    this.fallbackExpectedInterval,
    this.isLoadingOlder = false,
    this.hasMoreOlderData = true,
    this.onNeedOlderData,
  });

  final List<HistoryMeasurement> data;
  final int wetCalibration;
  final int dryCalibration;
  final int windowHours;
  final Duration? fallbackExpectedInterval;
  final bool isLoadingOlder;
  final bool hasMoreOlderData;
  final VoidCallback? onNeedOlderData;

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  final TransformationController _transformationController = TransformationController();
  DateTime? _oldestLoadedTimestamp;
  bool _olderRequestPending = false;

  @override
  void initState() {
    super.initState();
    _oldestLoadedTimestamp = widget.data.isNotEmpty ? widget.data.first.measuredAt : null;
  }

  @override
  void didUpdateWidget(covariant HistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.isEmpty) return;

    final newOldest = widget.data.first.measuredAt;
    final previousOldest = _oldestLoadedTimestamp;
    if (previousOldest != null && newOldest.isBefore(previousOldest)) {
      // Doszły starsze dane z przodu listy — przesuwamy transformację o dodaną szerokość,
      // żeby użytkownik nie zobaczył "skoku" widoku po doładowaniu.
      final addedSeconds = previousOldest.difference(newOldest).inSeconds.toDouble();
      final addedWidth = addedSeconds * _pxPerSecondFor(widget.windowHours);
      final matrix = _transformationController.value.clone()..translateByDouble(-addedWidth, 0, 0, 1);
      _transformationController.value = matrix;
    }
    if (widget.windowHours != oldWidget.windowHours) {
      _transformationController.value = Matrix4.identity();
    }
    _olderRequestPending = false;
    _oldestLoadedTimestamp = newOldest;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  static double _pxPerSecondFor(int windowHours) {
    if (windowHours <= 24) return 60.0 / 3600.0; // 60px na godzinę
    if (windowHours <= 72) return 80.0 / 14400.0; // 80px na 4 godziny
    return 100.0 / 86400.0; // 100px na dzień
  }

  void _maybeRequestOlderData() {
    if (widget.onNeedOlderData == null || _olderRequestPending) return;
    if (widget.isLoadingOlder || !widget.hasMoreOlderData) return;

    // screenX = scale*childX + translationX -> lewa krawędź viewportu w przestrzeni
    // dziecka to -translationX/scale; blisko 0 oznacza dotarcie do początku wczytanej historii.
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final viewportLeftInChildSpace = -matrix.getTranslation().x / scale;
    if (viewportLeftInChildSpace < 80) {
      _olderRequestPending = true;
      widget.onNeedOlderData!.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final pxPerSecond = _pxPerSecondFor(widget.windowHours);
        final minTs = widget.data.first.measuredAt.millisecondsSinceEpoch / 1000.0;
        final maxTs = widget.data.last.measuredAt.millisecondsSinceEpoch / 1000.0;
        final rangeSeconds = max(maxTs - minTs, 3600.0);
        final estimatedWidth = rangeSeconds * pxPerSecond;
        final chartWidth = max(constraints.maxWidth, estimatedWidth);

        return Stack(
          children: [
            ClipRect(
              child: InteractiveViewer(
                transformationController: _transformationController,
                constrained: false,
                boundaryMargin: const EdgeInsets.symmetric(horizontal: 16),
                minScale: 0.5,
                maxScale: 5.0,
                onInteractionUpdate: (_) => _maybeRequestOlderData(),
                onInteractionEnd: (_) => _maybeRequestOlderData(),
                child: SizedBox(
                  width: chartWidth,
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 24, 24, 16),
                    child: LineChart(_buildChartData()),
                  ),
                ),
              ),
            ),
            if (widget.isLoadingOlder)
              const Positioned(
                left: 4,
                top: 4,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (!widget.hasMoreOlderData)
              const Positioned(
                left: 4,
                top: 4,
                child: Text(
                  'Brak starszych danych',
                  style: TextStyle(fontSize: 10, color: Colors.black45),
                ),
              ),
          ],
        );
      },
    );
  }

  LineChartData _buildChartData() {
    final data = widget.data;
    final gaps = detectGaps(
      data,
      factor: _gapFactor,
      fallbackExpectedInterval: widget.fallbackExpectedInterval,
    );

    // Pojedyncza seria z FlSpot.nullSpot w miejscach luk — fl_chart realnie przerywa
    // linię w tym miejscu, zamiast łączyć punkty po przekątnej przez okres bez danych.
    final gapStarts = gaps.map((g) => g.start).toSet();
    final spots = <FlSpot>[];
    for (final m in data) {
      spots.add(FlSpot(m.measuredAt.millisecondsSinceEpoch / 1000.0, m.sensorValue.toDouble()));
      if (gapStarts.contains(m.measuredAt)) spots.add(FlSpot.nullSpot);
    }

    final minX = data.first.measuredAt.millisecondsSinceEpoch / 1000.0;
    final maxX = data.length > 1
        ? data.last.measuredAt.millisecondsSinceEpoch / 1000.0
        : minX + 3600;

    final double intervalX;
    final bool showDate;
    final bool onlyDate;
    if (widget.windowHours <= 24) {
      intervalX = 3600;
      showDate = false;
      onlyDate = false;
    } else if (widget.windowHours <= 72) {
      intervalX = 14400;
      showDate = true;
      onlyDate = false;
    } else {
      intervalX = 86400;
      showDate = true;
      onlyDate = true;
    }

    // Niewidoczne "markery" na środku każdej luki, użyte wyłącznie do trwałego wyświetlenia
    // etykiety z czasem trwania przerwy (przez showingTooltipIndicators fl_chart).
    final gapMarkers = <FlSpot>[];
    final gapLabelsByX = <double, String>{};
    for (final gap in gaps) {
      final midSeconds =
          (gap.start.millisecondsSinceEpoch + gap.end.millisecondsSinceEpoch) / 2 / 1000.0;
      final before = data.lastWhere((m) => m.measuredAt == gap.start);
      final after = data.firstWhere((m) => m.measuredAt == gap.end);
      final midY = (before.sensorValue + after.sensorValue) / 2.0;
      gapMarkers.add(FlSpot(midSeconds, midY));
      gapLabelsByX[midSeconds] = _formatGapDuration(gap.duration);
    }

    final lineBarsData = <LineChartBarData>[
      LineChartBarData(
        spots: spots,
        isCurved: false,
        color: Colors.green.shade600,
        barWidth: 2,
        dotData: FlDotData(show: data.length <= 40),
        belowBarData: BarAreaData(
          show: true,
          color: Colors.green.shade600.withValues(alpha: 0.1),
        ),
      ),
      if (gapMarkers.isNotEmpty)
        LineChartBarData(
          spots: gapMarkers,
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
        ),
    ];
    const gapMarkerBarIndex = 1;

    return LineChartData(
      minX: minX,
      maxX: maxX,
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: const Text('Wartość ADC', style: TextStyle(fontSize: 10)),
          axisNameSize: 16,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: showDate ? 40 : 32,
            interval: intervalX,
            getTitlesWidget: (value, meta) {
              final t = DateTime.fromMillisecondsSinceEpoch(
                (value * 1000).toInt(),
              ).toLocal();

              final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

              String label;
              if (onlyDate) {
                label = '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}';
              } else if (showDate) {
                label = '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}\n$timeStr';
              } else {
                label = timeStr;
              }

              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      minY: 0,
      maxY: 1024,
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: widget.wetCalibration.toDouble(),
            color: Colors.blue.withValues(alpha: 0.5),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 5, bottom: 5),
              style: const TextStyle(color: Colors.blue, fontSize: 10),
              labelResolver: (line) => 'Mokro',
            ),
          ),
          HorizontalLine(
            y: widget.dryCalibration.toDouble(),
            color: Colors.orange.withValues(alpha: 0.5),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.only(right: 5, top: 5),
              style: const TextStyle(color: Colors.orange, fontSize: 10),
              labelResolver: (line) => 'Sucho',
            ),
          ),
        ],
      ),
      rangeAnnotations: RangeAnnotations(
        verticalRangeAnnotations: [
          for (final gap in gaps)
            VerticalRangeAnnotation(
              x1: gap.start.millisecondsSinceEpoch / 1000.0,
              x2: gap.end.millisecondsSinceEpoch / 1000.0,
              color: Colors.grey.withValues(alpha: 0.18),
            ),
        ],
      ),
      lineBarsData: lineBarsData,
      showingTooltipIndicators: [
        for (final spot in gapMarkers)
          ShowingTooltipIndicators([
            LineBarSpot(lineBarsData[gapMarkerBarIndex], gapMarkerBarIndex, spot),
          ]),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            if (spot.barIndex == gapMarkerBarIndex) {
              return LineTooltipItem(
                'Brak danych: ${gapLabelsByX[spot.x] ?? ''}',
                const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              );
            }
            final t = DateTime.fromMillisecondsSinceEpoch((spot.x * 1000).toInt()).toLocal();
            final dateStr =
                '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} '
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            return LineTooltipItem(
              '$dateStr\n${spot.y.toInt()} ADC',
              const TextStyle(color: Colors.white, fontSize: 10),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatGapDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}min';
    if (hours > 0) return '${hours}h';
    return '${minutes}min';
  }
}

