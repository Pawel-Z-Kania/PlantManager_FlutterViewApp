/// Reprezentuje wykryty okres bez pomiarów pomiędzy dwoma sąsiednimi punktami danych.
class DataGap {
  final DateTime start;
  final DateTime end;

  const DataGap({required this.start, required this.end});

  Duration get duration => end.difference(start);
}
