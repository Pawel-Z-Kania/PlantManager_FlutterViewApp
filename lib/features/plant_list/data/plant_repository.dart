import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';
import '../domain/plant_pot.dart';

class PlantRepository {
  Future<List<PlantPot>> fetchPlants() async {
    final uri = Uri.parse('${Env.vercelApiUrl}/api/pots');
    final response = await http.get(uri).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      debugPrint('[PlantRepository] GET $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Błąd serwera: ${response.statusCode}');
    }

    final List data = jsonDecode(response.body);
    return [for (final row in data) _mapRow(Map<String, dynamic>.from(row))];
  }

  Future<void> updateSettings(String id, String name, int dry, int wet) async {
    final uri = Uri.parse('${Env.vercelApiUrl}/api/update-pot');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        'name': name,
        'dry_calibration_value': dry,
        'wet_calibration_value': wet,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      debugPrint('[PlantRepository] PUT $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Błąd serwera: ${response.statusCode}');
    }
  }

  PlantPot _mapRow(Map<String, dynamic> row) {
    final List measurements = row['pot_measurements'] ?? [];
    final int latestVal = measurements.isNotEmpty ? measurements[0]['sensor_value'] as int : 0;

    final DateTime updateTime = row['last_signal_time'] != null
        ? DateTime.parse(row['last_signal_time']).toLocal()
        : DateTime.now();

    final int? batteryMv = row['battery_mv'] != null ? (row['battery_mv'] as num).toInt() : null;
    final int? intervalMinutes =
        row['interval_minutes'] != null ? (row['interval_minutes'] as num).toInt() : null;

    final List rawAlerts = row['alerts'] as List? ?? [];
    final List<PlantAlert> alerts = [
      for (final a in rawAlerts)
        if (a is Map) PlantAlert.fromJson(Map<String, dynamic>.from(a))
    ];

    return PlantPot(
      id: row['id'].toString(),
      boardId: row['board_id']?.toString() ?? '',
      name: row['name'] ?? 'Brak nazwy',
      moistureValue: latestVal,
      lastUpdate: updateTime,
      dryCalibration: row['dry_calibration_value'] ?? 700,
      wetCalibration: row['wet_calibration_value'] ?? 400,
      batteryMv: batteryMv,
      intervalMinutes: intervalMinutes,
      alerts: alerts,
    );
  }
}
