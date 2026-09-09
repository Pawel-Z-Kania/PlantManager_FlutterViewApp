import 'history_gap.dart';
import 'history_measurement.dart';

/// Próg wykrywania luki jest adaptacyjny: mediana odstępów w danym zbiorze * [factor],
/// z podłogą [absoluteFloor] i fallbackiem [fallbackExpectedInterval] gdy punktów jest za mało
/// na sensowną medianę (np. świeżo dodana doniczka lub bardzo krótkie okno).
List<DataGap> detectGaps(
  List<HistoryMeasurement> sortedAsc, {
  double factor = 3.5,
  Duration absoluteFloor = const Duration(minutes: 30),
  Duration? fallbackExpectedInterval,
  int minSampleForMedian = 5,
}) {
  if (sortedAsc.length < 2) return const [];

  final intervals = <Duration>[
    for (var i = 1; i < sortedAsc.length; i++)
      sortedAsc[i].measuredAt.difference(sortedAsc[i - 1].measuredAt),
  ];

  Duration threshold;
  if (sortedAsc.length >= minSampleForMedian) {
    final sortedIntervals = [...intervals]..sort((a, b) => a.compareTo(b));
    final median = sortedIntervals[sortedIntervals.length ~/ 2];
    threshold = median * factor;
  } else if (fallbackExpectedInterval != null) {
    threshold = fallbackExpectedInterval * factor;
  } else {
    return const [];
  }
  if (threshold < absoluteFloor) threshold = absoluteFloor;

  final gaps = <DataGap>[];
  for (var i = 0; i < intervals.length; i++) {
    if (intervals[i] > threshold) {
      gaps.add(DataGap(start: sortedAsc[i].measuredAt, end: sortedAsc[i + 1].measuredAt));
    }
  }
  return gaps;
}

/// Dzieli posortowaną rosnąco listę pomiarów na ciągłe segmenty w miejscach wykrytych luk,
/// tak by wykres nie łączył linią punktów rozdzielonych przerwą.
List<List<HistoryMeasurement>> splitIntoSegments(
  List<HistoryMeasurement> sortedAsc,
  List<DataGap> gaps,
) {
  if (sortedAsc.isEmpty) return const [];
  if (gaps.isEmpty) return [sortedAsc];

  final gapStarts = gaps.map((g) => g.start).toSet();
  final segments = <List<HistoryMeasurement>>[];
  var current = <HistoryMeasurement>[sortedAsc.first];

  for (var i = 1; i < sortedAsc.length; i++) {
    final prev = sortedAsc[i - 1];
    if (gapStarts.contains(prev.measuredAt)) {
      segments.add(current);
      current = [sortedAsc[i]];
    } else {
      current.add(sortedAsc[i]);
    }
  }
  segments.add(current);
  return segments;
}
