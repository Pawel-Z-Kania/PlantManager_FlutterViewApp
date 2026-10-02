import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/history_gap_detector.dart';
import '../../domain/history_measurement.dart';
import 'frozen_y_axis.dart';

/// Próg luki = mediana odstępów (lub fallback) pomnożona przez ten współczynnik.
const _gapFactor = 3.5;

/// Odstęp linii siatki pionowej — 12h w sekundach, licząc od epoki, więc zawsze wypada o 00:00/12:00 czasu lokalnego.
const _verticalGridIntervalSeconds = 12 * 3600.0;

class HistoryChart extends StatefulWidget {
  const HistoryChart({
    super.key,
    required this.data,
    required this.wetCalibration,
    required this.dryCalibration,
    required this.axisStart,
    required this.axisEnd,
    this.fallbackExpectedInterval,
    this.isLoadingOlder = false,
    this.hasMoreOlderData = true,
    this.onNeedOlderData,
  });

  final List<HistoryMeasurement> data;
  final int wetCalibration;
  final int dryCalibration;
  final DateTime axisStart;
  final DateTime axisEnd;
  final Duration? fallbackExpectedInterval;
  final bool isLoadingOlder;
  final bool hasMoreOlderData;
  final VoidCallback? onNeedOlderData;

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  static const _screenHorizontalPadding = 16.0;
  static const _frozenAxisWidth = 48.0;
  static const _chartTopPadding = 24.0;
  static const _chartBottomPadding = 16.0;
  static const _yAxisInterval = 256.0;
  static const _initialScale = 2.0;
  static const _maximumScale = 8.0;
  static const _rightNowBufferFraction = 0.15;
  static const _olderDataTriggerOffset = 8.0;

  final TransformationController _transformationController =
      TransformationController();
  bool _needsInitialViewport = true;
  bool _olderDataRequested = false;
  bool _ignoringTransformationChange = false;
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChange);
  }

  @override
  void didUpdateWidget(covariant HistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.axisStart.isBefore(oldWidget.axisStart)) {
      final addedSeconds = oldWidget.axisStart
          .difference(widget.axisStart)
          .inSeconds
          .toDouble();
      final oldRangeSeconds = _axisRangeSeconds(
        oldWidget.axisStart,
        oldWidget.axisEnd,
      );
      final newRangeSeconds = _axisRangeSeconds(
        widget.axisStart,
        widget.axisEnd,
      );
      final scale = _transformationController.value.getMaxScaleOnAxis();
      final oldTranslationX = _transformationController.value
          .getTranslation()
          .x;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _viewportWidth == 0) return;
        final oldVisibleFraction = (-oldTranslationX / (scale * _viewportWidth))
            .clamp(0.0, 1.0);
        final newVisibleFraction =
            ((addedSeconds + oldVisibleFraction * oldRangeSeconds) /
                    newRangeSeconds)
                .clamp(0.0, 1.0);
        _setTransformation(scale, -newVisibleFraction * scale * _viewportWidth);
      });
    }
    if (!widget.isLoadingOlder && oldWidget.isLoadingOlder) {
      _olderDataRequested = false;
    }
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(_handleTransformationChange)
      ..dispose();
    super.dispose();
  }

  double _axisRangeSeconds(DateTime start, DateTime end) {
    final rangeSeconds = max(
      end.difference(start).inSeconds.toDouble(),
      3600.0,
    );
    return rangeSeconds * (1 + _rightNowBufferFraction);
  }

  void _handleTransformationChange() {
    if (_ignoringTransformationChange || _viewportWidth == 0) return;
    final translationX = _transformationController.value.getTranslation().x;
    if (translationX < -_olderDataTriggerOffset ||
        _olderDataRequested ||
        widget.isLoadingOlder ||
        !widget.hasMoreOlderData ||
        widget.onNeedOlderData == null) {
      return;
    }

    _olderDataRequested = true;
    widget.onNeedOlderData!();
  }

  void _setTransformation(double scale, double translationX) {
    _ignoringTransformationChange = true;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(translationX, 0, 0, 1)
      ..scaleByDouble(scale, 1, 1, 1);
    _ignoringTransformationChange = false;
  }

  void _setInitialViewport() {
    _setTransformation(_initialScale, -_viewportWidth * (_initialScale - 1));
    _needsInitialViewport = false;
  }

  void _zoomBy(double scaleDelta) {
    if (_viewportWidth == 0) return;
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final nextScale = (currentScale * scaleDelta).clamp(1.0, _maximumScale);
    final focalX = _viewportWidth / 2;
    final currentTranslationX = currentMatrix.getTranslation().x;
    final focalSceneX = (focalX - currentTranslationX) / currentScale;
    _setTransformation(nextScale, focalX - nextScale * focalSceneX);
  }

  void _resetZoom() {
    _setTransformation(1, 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            _screenHorizontalPadding,
            0,
            _screenHorizontalPadding,
            _screenHorizontalPadding,
          ),
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              final plotWidth = viewportConstraints.maxWidth - _frozenAxisWidth;
              final rightNowBufferSeconds =
                  _axisRangeSeconds(widget.axisStart, widget.axisEnd) -
                  max(
                    widget.axisEnd
                        .difference(widget.axisStart)
                        .inSeconds
                        .toDouble(),
                    3600.0,
                  );
              const bottomTitleSize = 40.0;
              _viewportWidth = plotWidth;

              if (_needsInitialViewport) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted ||
                      !_needsInitialViewport ||
                      _viewportWidth == 0) {
                    return;
                  }
                  _setInitialViewport();
                });
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _frozenAxisWidth,
                    child: FrozenYAxis(
                      topPadding: _chartTopPadding,
                      bottomPadding: _chartBottomPadding + bottomTitleSize,
                      wetCalibration: widget.wetCalibration,
                      dryCalibration: widget.dryCalibration,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            0,
                            _chartTopPadding,
                            24,
                            _chartBottomPadding,
                          ),
                          child: LineChart(
                            _buildChartData(rightNowBufferSeconds),
                            transformationConfig: FlTransformationConfig(
                              scaleAxis: FlScaleAxis.horizontal,
                              minScale: 1,
                              maxScale: _maximumScale,
                              trackpadScrollCausesScale: true,
                              transformationController:
                                  _transformationController,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          width: _frozenAxisWidth,
                          child: IgnorePointer(
                            child: Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Material(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Oddal wykres',
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => _zoomBy(1 / 1.5),
                                ),
                                IconButton(
                                  tooltip: 'Przybliż wykres',
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _zoomBy(1.5),
                                ),
                                IconButton(
                                  tooltip: 'Pokaż cały tydzień',
                                  icon: const Icon(Icons.restart_alt),
                                  onPressed: _resetZoom,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: _chartTopPadding,
                          right: _frozenAxisWidth,
                          bottom: _chartBottomPadding + bottomTitleSize,
                          child: IgnorePointer(
                            child: Container(
                              width: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        if (widget.isLoadingOlder)
                          const Positioned(
                            left: 4,
                            top: 8,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (!widget.isLoadingOlder && !widget.hasMoreOlderData)
                          const Positioned(
                            left: 4,
                            top: 8,
                            child: Text(
                              'Brak starszych danych',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  LineChartData _buildChartData(double rightNowBufferSeconds) {
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
      spots.add(
        FlSpot(
          m.measuredAt.millisecondsSinceEpoch / 1000.0,
          m.sensorValue.toDouble(),
        ),
      );
      if (gapStarts.contains(m.measuredAt)) spots.add(FlSpot.nullSpot);
    }

    final minX = widget.axisStart.millisecondsSinceEpoch / 1000.0;
    final nowX = widget.axisEnd.millisecondsSinceEpoch / 1000.0;
    final maxX = nowX + rightNowBufferSeconds;

    const intervalX = 86400.0;

    // Niewidoczne "markery" na środku każdej luki, użyte wyłącznie do trwałego wyświetlenia
    // etykiety z czasem trwania przerwy (przez showingTooltipIndicators fl_chart).
    final gapMarkers = <FlSpot>[];
    final gapLabelsByX = <double, String>{};
    for (final gap in gaps) {
      final midSeconds =
          (gap.start.millisecondsSinceEpoch + gap.end.millisecondsSinceEpoch) /
          2 /
          1000.0;
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
      gridData: FlGridData(
        show: true,
        horizontalInterval: _yAxisInterval,
        verticalInterval: _verticalGridIntervalSeconds,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.blueGrey.withValues(alpha: 0.15),
          strokeWidth: 0.4,
          dashArray: const [8, 4],
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: Colors.blueGrey.withValues(alpha: 0.15),
          strokeWidth: 0.4,
          dashArray: const [8, 4],
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: intervalX,
            getTitlesWidget: (value, meta) {
              final t = DateTime.fromMillisecondsSinceEpoch(
                (value * 1000).toInt(),
              ).toLocal();

              final label =
                  '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}';

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
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: true),
      minY: 0,
      maxY: 1024,
      extraLinesData: ExtraLinesData(
        verticalLines: [
          VerticalLine(
            x: nowX,
            color: Colors.green.shade800.withValues(alpha: 0.8),
            strokeWidth: 2,
          ),
        ],
        horizontalLines: [
          HorizontalLine(
            y: widget.wetCalibration.toDouble(),
            color: Colors.blue.withValues(alpha: 0.5),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: false,
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
              show: false,
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
            LineBarSpot(
              lineBarsData[gapMarkerBarIndex],
              gapMarkerBarIndex,
              spot,
            ),
          ]),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            if (spot.barIndex == gapMarkerBarIndex) {
              return LineTooltipItem(
                'Brak danych: ${gapLabelsByX[spot.x] ?? ''}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              );
            }
            final t = DateTime.fromMillisecondsSinceEpoch(
              (spot.x * 1000).toInt(),
            ).toLocal();
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
