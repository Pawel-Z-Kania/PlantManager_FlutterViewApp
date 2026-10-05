/// Reprezentuje wykryty okres bez pomiarów pomiędzy dwoma sąsiednimi punktami danych.
class DataGap {
  final DateTime start;
  final DateTime end;

  const DataGap({required this.start, required this.end});

  Duration get duration => end.difference(start);
}

String formatGapDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}min';
  if (hours > 0) return '${hours}h';
  return '${minutes}min';
}
