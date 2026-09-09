import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/plant_history/domain/history_gap_detector.dart';
import 'package:plant_app/features/plant_history/domain/history_measurement.dart';

HistoryMeasurement _m(DateTime t, [int v = 500]) =>
    HistoryMeasurement(sensorValue: v, measuredAt: t);

void main() {
  final base = DateTime(2026, 1, 1, 0, 0);

  group('detectGaps', () {
    test('returns no gaps for a uniform dense series', () {
      final data = [
        for (var i = 0; i < 10; i++) _m(base.add(Duration(minutes: 10 * i))),
      ];
      expect(detectGaps(data), isEmpty);
    });

    test('detects a single clear gap', () {
      final data = [
        _m(base),
        _m(base.add(const Duration(minutes: 10))),
        _m(base.add(const Duration(minutes: 20))),
        _m(base.add(const Duration(minutes: 30))),
        // Duża przerwa: 6h zamiast 10 minut
        _m(base.add(const Duration(hours: 6, minutes: 30))),
        _m(base.add(const Duration(hours: 6, minutes: 40))),
      ];
      final gaps = detectGaps(data);
      expect(gaps, hasLength(1));
      expect(gaps.first.start, data[3].measuredAt);
      expect(gaps.first.end, data[4].measuredAt);
      expect(gaps.first.duration, const Duration(hours: 6));
    });

    test('uses fallbackExpectedInterval when too few points for a median', () {
      final data = [
        _m(base),
        _m(base.add(const Duration(hours: 5))),
      ];
      // Bez fallbacku: za mało punktów, brak wykrywania.
      expect(detectGaps(data), isEmpty);

      // Z fallbackiem 60 min * factor 3.5 = 210 min < 5h -> wykryta luka.
      final gaps = detectGaps(
        data,
        fallbackExpectedInterval: const Duration(minutes: 60),
      );
      expect(gaps, hasLength(1));
    });

    test('does not flag small jitter as a gap thanks to the absolute floor', () {
      final data = [
        _m(base),
        _m(base.add(const Duration(minutes: 1))),
        _m(base.add(const Duration(minutes: 2))),
        _m(base.add(const Duration(minutes: 3))),
        // Odstająca, ale wciąż mała przerwa (5 min) nie powinna być zgłoszona jako luka.
        _m(base.add(const Duration(minutes: 8))),
      ];
      expect(detectGaps(data), isEmpty);
    });

    test('returns empty for lists shorter than 2', () {
      expect(detectGaps([]), isEmpty);
      expect(detectGaps([_m(base)]), isEmpty);
    });
  });

  group('splitIntoSegments', () {
    test('returns a single segment when there are no gaps', () {
      final data = [
        _m(base),
        _m(base.add(const Duration(minutes: 10))),
      ];
      final segments = splitIntoSegments(data, const []);
      expect(segments, hasLength(1));
      expect(segments.first, data);
    });

    test('splits into multiple segments at each gap', () {
      final data = [
        _m(base),
        _m(base.add(const Duration(minutes: 10))),
        _m(base.add(const Duration(minutes: 20))),
        _m(base.add(const Duration(minutes: 30))),
        _m(base.add(const Duration(hours: 6, minutes: 30))),
        _m(base.add(const Duration(hours: 6, minutes: 40))),
      ];
      final gaps = detectGaps(data);
      final segments = splitIntoSegments(data, gaps);
      expect(segments, hasLength(2));
      expect(segments[0], data.sublist(0, 4));
      expect(segments[1], data.sublist(4, 6));
    });

    test('returns empty for an empty input list', () {
      expect(splitIntoSegments(const [], const []), isEmpty);
    });
  });
}
