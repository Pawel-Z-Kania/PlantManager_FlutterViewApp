import 'dart:typed_data';
import 'history_gap.dart';
import 'history_gap_detector.dart';
import 'history_measurement.dart';

/// Próg luki = mediana odstępów (lub fallback) pomnożona przez ten współczynnik.
const historyGapFactor = 3.5;

/// Dane wykresu w postaci tablic typowanych, budowane raz przy zmianie danych.
class HistorySeries {
  HistorySeries._({
    required this.times,
    required this.values,
    required this.voltages,
    required this.breakAfter,
    required this.gaps,
  }) : gapStartMs = Float64List.fromList([
         for (final g in gaps) g.start.millisecondsSinceEpoch.toDouble(),
       ]),
       gapEndMs = Float64List.fromList([
         for (final g in gaps) g.end.millisecondsSinceEpoch.toDouble(),
       ]);

  factory HistorySeries.fromMeasurements(
    List<HistoryMeasurement> sortedAsc, {
    Duration? fallbackExpectedInterval,
  }) {
    final n = sortedAsc.length;
    final times = Float64List(n);
    final values = Float64List(n);
    final voltages = Float64List(n);
    for (var i = 0; i < n; i++) {
      final m = sortedAsc[i];
      times[i] = m.measuredAt.millisecondsSinceEpoch.toDouble();
      values[i] = m.sensorValue.toDouble();
      voltages[i] = m.batteryMv == null ? double.nan : m.batteryMv! / 1000.0;
    }

    final gaps = detectGaps(
      sortedAsc,
      factor: historyGapFactor,
      fallbackExpectedInterval: fallbackExpectedInterval,
    );
    final breakAfter = Uint8List(n);
    var g = 0;
    for (var i = 0; i < n - 1 && g < gaps.length; i++) {
      if (sortedAsc[i].measuredAt == gaps[g].start) {
        breakAfter[i] = 1;
        g++;
      }
    }

    return HistorySeries._(
      times: times,
      values: values,
      voltages: voltages,
      breakAfter: breakAfter,
      gaps: gaps,
    );
  }

  /// Czas pomiaru w ms od epoki, rosnąco.
  final Float64List times;

  /// Wartość czujnika wilgotności (ADC).
  final Float64List values;

  /// Napięcie baterii w V; NaN, gdy brak odczytu.
  final Float64List voltages;
  final List<DataGap> gaps;
  final Float64List gapStartMs;
  final Float64List gapEndMs;

  /// 1, gdy między punktem i a i + 1 wykryto lukę.
  final Uint8List breakAfter;

  int get length => times.length;

  /// Czy między punktem [i] a [i] + 1 jest luka (linia ma się tam urywać).
  bool breaksAfter(int i) => breakAfter[i] == 1;

  /// Pierwszy indeks z czasem >= [timeMs].
  int lowerBound(double timeMs) {
    var lo = 0;
    var hi = times.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (times[mid] < timeMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Pierwszy indeks z czasem > [timeMs].
  int upperBound(double timeMs) {
    var lo = 0;
    var hi = times.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (times[mid] <= timeMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Indeks punktu najbliższego [timeMs] lub -1 dla pustej serii.
  int nearestIndex(double timeMs) {
    if (times.isEmpty) return -1;
    final upper = lowerBound(timeMs);
    if (upper == 0) return 0;
    if (upper == times.length) return times.length - 1;
    return (timeMs - times[upper - 1]) <= (times[upper] - timeMs)
        ? upper - 1
        : upper;
  }
}
