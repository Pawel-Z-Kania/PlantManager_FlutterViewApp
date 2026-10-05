import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/plant_history/domain/history_gap.dart';
import 'package:plant_app/features/plant_history/domain/history_measurement.dart';
import 'package:plant_app/features/plant_history/domain/history_series.dart';

HistoryMeasurement _m(DateTime t, [int v = 500, int? mv]) =>
    HistoryMeasurement(sensorValue: v, measuredAt: t, batteryMv: mv);

void main() {
  final base = DateTime(2026, 1, 1);

  HistorySeries build(List<HistoryMeasurement> data) =>
      HistorySeries.fromMeasurements(data);

  group('HistorySeries', () {
    final data = [
      for (var i = 0; i < 6; i++)
        _m(base.add(Duration(minutes: 30 * i)), 100 + i, i.isEven ? 3000 : null),
    ];
    final series = build(data);

    double ms(int i) => data[i].measuredAt.millisecondsSinceEpoch.toDouble();

    test('copies values and converts voltage to volts with NaN for missing', () {
      expect(series.length, 6);
      expect(series.values[2], 102);
      expect(series.voltages[0], 3.0);
      expect(series.voltages[1].isNaN, isTrue);
    });

    test('lowerBound and upperBound handle exact and between values', () {
      expect(series.lowerBound(ms(2)), 2);
      expect(series.upperBound(ms(2)), 3);
      expect(series.lowerBound(ms(2) + 1), 3);
      expect(series.lowerBound(ms(0) - 1), 0);
      expect(series.lowerBound(ms(5) + 1), 6);
      expect(series.upperBound(ms(5)), 6);
    });

    test('nearestIndex picks the closest point and handles edges', () {
      expect(series.nearestIndex(ms(2) + 100), 2);
      expect(series.nearestIndex(ms(3) - 100), 3);
      expect(series.nearestIndex(ms(0) - 1e9), 0);
      expect(series.nearestIndex(ms(5) + 1e9), 5);
    });

    test('nearestIndex returns -1 for an empty series', () {
      expect(build(const []).nearestIndex(0), -1);
    });
  });

  test('marks the point before a gap as a line break', () {
    final data = [
      _m(base),
      _m(base.add(const Duration(minutes: 30))),
      _m(base.add(const Duration(minutes: 60))),
      _m(base.add(const Duration(minutes: 90))),
      _m(base.add(const Duration(minutes: 120))),
      _m(base.add(const Duration(hours: 10))),
      _m(base.add(const Duration(hours: 10, minutes: 30))),
    ];
    final series = build(data);

    expect(series.gaps, hasLength(1));
    expect(
      [for (var i = 0; i < data.length; i++) series.breaksAfter(i)],
      [false, false, false, false, true, false, false],
    );
    expect(series.gapStartMs.single, data[4].measuredAt.millisecondsSinceEpoch);
    expect(series.gapEndMs.single, data[5].measuredAt.millisecondsSinceEpoch);
  });

  test('formatGapDuration formats hours and minutes', () {
    expect(formatGapDuration(const Duration(hours: 2, minutes: 5)), '2h 5min');
    expect(formatGapDuration(const Duration(hours: 3)), '3h');
    expect(formatGapDuration(const Duration(minutes: 45)), '45min');
  });

  test('HistoryMeasurement.fromJson reads optional battery_mv', () {
    final withBattery = HistoryMeasurement.fromJson({
      'sensor_value': 400,
      'measured_at': '2026-01-01T00:00:00Z',
      'battery_mv': 2950,
    });
    final withoutBattery = HistoryMeasurement.fromJson({
      'sensor_value': 400,
      'measured_at': '2026-01-01T00:00:00Z',
    });
    expect(withBattery.batteryMv, 2950);
    expect(withoutBattery.batteryMv, isNull);
  });
}
