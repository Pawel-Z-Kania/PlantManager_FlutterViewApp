class HistoryMeasurement {
  final int sensorValue;
  final DateTime measuredAt;

  /// Napięcie baterii w mV; null, gdy brak odczytu lub backend nie zwraca pola.
  final int? batteryMv;

  HistoryMeasurement({
    required this.sensorValue,
    required this.measuredAt,
    this.batteryMv,
  });

  factory HistoryMeasurement.fromJson(Map<String, dynamic> json) =>
      HistoryMeasurement(
        sensorValue: json['sensor_value'] as int,
        measuredAt: DateTime.parse(json['measured_at'] as String).toLocal(),
        batteryMv: (json['battery_mv'] as num?)?.toInt(),
      );
}
