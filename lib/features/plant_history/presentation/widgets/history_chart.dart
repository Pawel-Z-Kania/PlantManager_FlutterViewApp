import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/history_measurement.dart';

class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.data,
    required this.wetCalibration,
    required this.dryCalibration,
  });

  final List<HistoryMeasurement> data;
  final int wetCalibration;
  final int dryCalibration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wyznaczenie przedziału czasowego bieżącego widoku do lepszego obliczania skali
        final double minStr = data.first.measuredAt.millisecondsSinceEpoch / 1000.0;
        final double maxStr = data.last.measuredAt.millisecondsSinceEpoch / 1000.0;
        final double rangeSeconds = (maxStr - minStr) > 0 ? (maxStr - minStr) : 3600;

        // Uzależniamy szerokość wykresu bezpiecznie od czasu, a nie od ilości punktów surowych pomiarów
        double estimatedWidth = constraints.maxWidth;
        if (rangeSeconds <= 86400) {
          estimatedWidth = (rangeSeconds / 3600) * 60.0; // Przykładowo 60px na pierwszą godzinę
        } else if (rangeSeconds <= 259200) {
          estimatedWidth = (rangeSeconds / 14400) * 80.0; // Przykładowo 80px na każde 4 godziny
        } else {
          estimatedWidth = (rangeSeconds / 86400) * 100.0; // Przykładowo 100px na każdy 1 dzień
        }

        final chartWidth = max(constraints.maxWidth, estimatedWidth);

        return ClipRect(
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.symmetric(horizontal: 16), // Zapobiega rozjeżdżaniu się marginesowi pustki w prawo
            minScale: 0.5,
            maxScale: 5.0,
            child: SizedBox(
              width: chartWidth,
              height: constraints.maxHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 24, 24, 16),
                child: LineChart(_buildChartData()),
              ),
            ),
          ),
        );
      },
    );
  }

  LineChartData _buildChartData() {
    // X = Unix seconds; avoids double overflow that milliseconds cause post-2020
    final spots = data.map((m) => FlSpot(
      m.measuredAt.millisecondsSinceEpoch / 1000.0,
      m.sensorValue.toDouble(),
    )).toList();

    final minX = spots.first.x;
    final maxX = spots.length > 1 ? spots.last.x : spots.first.x + 3600;
    final rangeSeconds = maxX - minX;

    final double intervalX;
    final bool showDate;
    final bool onlyDate;

    if (rangeSeconds <= 86400) {
      intervalX = 3600;  // Podziały co 1h
      showDate = false;
      onlyDate = false;
    } else if (rangeSeconds <= 259200) {
      intervalX = 14400; // Podziały co 4h
      showDate = true;
      onlyDate = false;
    } else {
      intervalX = 86400; // Podziały co 1 dzień
      showDate = true;
      onlyDate = true; // Zabezpieczenie przed dziwnymi strefowymi 'północami', gdzie pokaże wyłącznie rzutowane dni
    }

    return LineChartData(
      minX: minX,
      maxX: maxX,
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
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
            y: wetCalibration.toDouble(),
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
            y: dryCalibration.toDouble(),
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
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: Colors.green.shade600,
          barWidth: 2,
          dotData: FlDotData(show: spots.length <= 20),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.shade600.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}
