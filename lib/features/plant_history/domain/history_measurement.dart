class HistoryMeasurement {
  final int sensorValue;
  final DateTime measuredAt;

  HistoryMeasurement({required this.sensorValue, required this.measuredAt});

  factory HistoryMeasurement.fromJson(Map<String, dynamic> json) =>
      HistoryMeasurement(
        sensorValue: json['sensor_value'] as int,
        measuredAt: DateTime.parse(json['measured_at'] as String).toLocal(),
      );
}
