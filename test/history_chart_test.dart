import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/plant_history/domain/history_measurement.dart';
import 'package:plant_app/features/plant_history/presentation/widgets/history_chart.dart';
import 'package:plant_app/features/plant_history/providers/history_providers.dart';

void main() {
  final now = DateTime(2026, 10, 5, 12);

  List<HistoryMeasurement> dataFrom(DateTime from) => [
    for (var t = from; t.isBefore(now); t = t.add(const Duration(minutes: 30)))
      HistoryMeasurement(sensorValue: 500, measuredAt: t, batteryMv: 3000),
  ];

  Widget host({
    required DateTime loadedFrom,
    required VoidCallback onNeedOlderData,
    bool isLoadingOlder = false,
    bool hasMoreOlderData = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HistoryChart(
          data: dataFrom(loadedFrom),
          wetCalibration: 300,
          dryCalibration: 800,
          loadedFrom: loadedFrom,
          loadedTo: now,
          earliestAllowed: now.subtract(historyMaxDepth),
          isLoadingOlder: isLoadingOlder,
          hasMoreOlderData: hasMoreOlderData,
          onNeedOlderData: onNeedOlderData,
        ),
      ),
    );
  }

  final plot = find.byKey(const ValueKey('history-chart-plot'));

  testWidgets('requests older data once when panned towards the loaded edge', (
    tester,
  ) async {
    var calls = 0;
    final week = now.subtract(const Duration(hours: 168));
    await tester.pumpWidget(host(loadedFrom: week, onNeedOlderData: () => calls++));
    expect(calls, 0);

    await tester.drag(plot, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.drag(plot, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('prepended data does not trigger another request', (tester) async {
    var calls = 0;
    final week = now.subtract(const Duration(hours: 168));
    await tester.pumpWidget(host(loadedFrom: week, onNeedOlderData: () => calls++));
    await tester.drag(plot, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.pumpWidget(
      host(loadedFrom: week, onNeedOlderData: () => calls++, isLoadingOlder: true),
    );
    await tester.pumpWidget(
      host(
        loadedFrom: now.subtract(const Duration(hours: 336)),
        onNeedOlderData: () => calls++,
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not request when there is no older data', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        loadedFrom: now.subtract(const Duration(hours: 168)),
        onNeedOlderData: () => calls++,
        hasMoreOlderData: false,
      ),
    );
    await tester.drag(plot, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
}
