import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/history_gap_detector.dart';
import '../../domain/history_measurement.dart';
import 'frozen_y_axis.dart';

/// Próg luki = mediana odstępów (lub fallback) pomnożona przez ten współczynnik.
const _gapFactor = 3.5;

class HistoryChart extends StatefulWidget {
  const HistoryChart({
    super.key,
    required this.data,
    required this.wetCalibration,
    required this.dryCalibration,
    required this.windowHours,
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
  final int windowHours;
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
  static const _initialHiddenFraction = 0.1;
  static const _rightNowBufferFraction = 0.15;
  static const _olderDataTriggerOffset = 8.0;

  final ScrollController _scrollController = ScrollController();
  bool _needsInitialOffset = true;
  bool _olderDataRequested = false;

  @override
  void didUpdateWidget(covariant HistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.axisStart.isBefore(oldWidget.axisStart)) {
      // Doszło starsze okno po lewej — zachowujemy aktualnie oglądany fragment.
      final addedSeconds = oldWidget.axisStart.difference(widget.axisStart).inSeconds.toDouble();
      final addedWidth = addedSeconds * _pxPerSecondFor(widget.windowHours);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final position = _scrollController.position;
        final targetOffset = (position.pixels + addedWidth).clamp(0.0, position.maxScrollExtent);
        _scrollController.jumpTo(targetOffset);
      });
    }
    if (widget.windowHours != oldWidget.windowHours) {
      _needsInitialOffset = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
    }
    if (!widget.isLoadingOlder && oldWidget.isLoadingOlder) {
      _olderDataRequested = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static double _pxPerSecondFor(int windowHours) {
    if (windowHours <= 24) return 60.0 / 3600.0; // 60px na godzinę
    if (windowHours <= 72) return 80.0 / 14400.0; // 80px na 4 godziny
    return 100.0 / 86400.0; // 100px na dzień
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
              final pxPerSecond = _pxPerSecondFor(widget.windowHours);
              final rangeSeconds = max(widget.axisEnd.difference(widget.axisStart).inSeconds.toDouble(), 3600.0);
              final estimatedWidth = rangeSeconds * pxPerSecond;
              final plotWidth = viewportConstraints.maxWidth - _frozenAxisWidth;
              final initialOffset = plotWidth * _initialHiddenFraction;
              final rightNowBufferWidth = plotWidth * _rightNowBufferFraction;
              final rightNowBufferSeconds = rightNowBufferWidth / pxPerSecond;
              final chartWidth = max(
                estimatedWidth + rightNowBufferWidth,
                plotWidth + initialOffset,
              );
              final bottomTitleSize = widget.windowHours <= 24 ? 32.0 : 40.0;

              if (_needsInitialOffset) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_needsInitialOffset || !_scrollController.hasClients) return;
                  final position = _scrollController.position;
                  _scrollController.jumpTo(min(initialOffset, position.maxScrollExtent));
                  _needsInitialOffset = false;
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
                        ClipRect(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _handleScrollNotification,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: chartWidth,
                                height: viewportConstraints.maxHeight,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    _chartTopPadding,
                                    24,
                                    _chartBottomPadding,
                                  ),
                                  child: LineChart(_buildChartData(rightNowBufferSeconds)),
                                ),
                              ),
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
                              style: TextStyle(fontSize: 10, color: Colors.black45),
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

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal || notification is! ScrollUpdateNotification) {
      return false;
    }
    if (notification.metrics.pixels > _olderDataTriggerOffset ||
        _olderDataRequested ||
        widget.isLoadingOlder ||
        !widget.hasMoreOlderData ||
        widget.onNeedOlderData == null) {
      return false;
    }

    _olderDataRequested = true;
    widget.onNeedOlderData!();
    return false;
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
      spots.add(FlSpot(m.measuredAt.millisecondsSinceEpoch / 1000.0, m.sensorValue.toDouble()));
      if (gapStarts.contains(m.measuredAt)) spots.add(FlSpot.nullSpot);
    }

    final minX = widget.axisStart.millisecondsSinceEpoch / 1000.0;
    final nowX = widget.axisEnd.millisecondsSinceEpoch / 1000.0;
    final maxX = nowX + rightNowBufferSeconds;

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
      gridData: const FlGridData(show: true, horizontalInterval: _yAxisInterval),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

