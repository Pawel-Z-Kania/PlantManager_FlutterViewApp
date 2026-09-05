import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/env.dart';
import '../domain/plant_pot.dart';

class PlantRepository {
  PlantRepository(this._client);

  final SupabaseClient _client;

  Future<List<PlantPot>> fetchPlants() async {
    final response = await _client
        .from('pots')
        .select(
            'id, name, board_id, last_signal_time, dry_calibration_value, wet_calibration_value, battery_mv, pot_measurements(sensor_value)')
        .order('measured_at', referencedTable: 'pot_measurements', ascending: false)
        .limit(1, referencedTable: 'pot_measurements');

    return [for (final row in response) _mapRow(row)];
  }

  Future<void> updateSettings(String id, String name, int dry, int wet) async {
    final response = await http.put(
      Uri.parse('${Env.vercelApiUrl}/api/update-pot'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        'name': name,
        'dry_calibration_value': dry,
        'wet_calibration_value': wet,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
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

    return PlantPot(
      id: row['id'].toString(),
      boardId: row['board_id']?.toString() ?? '',
      name: row['name'] ?? 'Brak nazwy',
      moistureValue: latestVal,
      lastUpdate: updateTime,
      dryCalibration: row['dry_calibration_value'] ?? 700,
      wetCalibration: row['wet_calibration_value'] ?? 400,
      batteryMv: batteryMv,
    );
  }
}
