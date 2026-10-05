import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/plant_history/domain/history_time_ticks.dart';

void main() {
  const hourMs = 3600000.0;

  test('picks a 12h step for a 96h view on a phone-sized plot', () {
    final start = DateTime(2026, 10, 1, 5);
    final startMs = start.millisecondsSinceEpoch.toDouble();
    final ticks = buildTimeTicks(
      startMs: startMs,
      endMs: startMs + 96 * hourMs,
      msPerPixel: 96 * hourMs / 672,
    );

    expect(ticks.first.label, '12:00');
    expect(ticks.first.dateLine, '01.10');
    final midnight = ticks.firstWhere((t) => t.isDayStart);
    expect(midnight.label, '00:00');
    expect(midnight.dateLine, '02.10');
    expect(
      ticks.every((t) => DateTime.fromMillisecondsSinceEpoch(t.timeMs.toInt()).hour % 12 == 0),
      isTrue,
    );
    expect(ticks, hasLength(8));
  });

  test('uses hourly ticks when zoomed in to 6h', () {
    final start = DateTime(2026, 10, 1, 8, 30);
    final startMs = start.millisecondsSinceEpoch.toDouble();
    final ticks = buildTimeTicks(
      startMs: startMs,
      endMs: startMs + 6 * hourMs,
      msPerPixel: 6 * hourMs / 672,
    );

    expect(ticks.map((t) => t.label), ['09:00', '10:00', '11:00', '12:00', '13:00', '14:00']);
    expect(ticks.first.dateLine, '01.10');
    expect(ticks[1].dateLine, isNull);
  });

  test('uses 2-day steps with date labels for a 14 day view', () {
    final start = DateTime(2026, 10, 1);
    final startMs = start.millisecondsSinceEpoch.toDouble();
    final ticks = buildTimeTicks(
      startMs: startMs,
      endMs: startMs + 14 * 24 * hourMs,
      msPerPixel: 14 * 24 * hourMs / 672,
    );

    expect(ticks.length, greaterThanOrEqualTo(6));
    expect(ticks.every((t) => t.isDayStart && t.dateLine == null), isTrue);
    for (var i = 1; i < ticks.length; i++) {
      expect(ticks[i].timeMs - ticks[i - 1].timeMs, 48 * hourMs);
    }
  });
}
