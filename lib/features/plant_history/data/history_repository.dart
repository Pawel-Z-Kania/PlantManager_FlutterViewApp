import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';
import '../domain/history_measurement.dart';

class HistoryRepository {
  Future<List<HistoryMeasurement>> fetchHistory(
    String boardId, {
    required DateTime from,
    required DateTime to,
    int bucketMinutes = 0,
  }) async {
    if (boardId.isEmpty) throw Exception('Brak board_id dla tej doniczki');
    final params = {
      'board_id': boardId,
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      if (bucketMinutes > 0) 'bucket_minutes': bucketMinutes.toString(),
    };
    final uri = Uri.parse('${Env.vercelApiUrl}/api/history').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      debugPrint('[HistoryRepository] GET $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Błąd serwera: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    final measurements = list
        .map((e) => HistoryMeasurement.fromJson(e as Map<String, dynamic>))
        .where((measurement) {
          final isInRequestedRange =
              !measurement.measuredAt.isBefore(from) && !measurement.measuredAt.isAfter(to);
          if (!isInRequestedRange) {
            debugPrint(
              '[HistoryRepository] Ignoring measurement outside requested range: '
              '${measurement.measuredAt.toIso8601String()} not in '
              '${from.toIso8601String()} - ${to.toIso8601String()}',
            );
          }
          return isInRequestedRange;
        })
        .toList();

    final byTimestamp = <int, HistoryMeasurement>{
      for (final measurement in measurements)
        measurement.measuredAt.millisecondsSinceEpoch: measurement,
    };
    final normalized = byTimestamp.values.toList()
      ..sort((first, second) => first.measuredAt.compareTo(second.measuredAt));
    if (normalized.length != measurements.length) {
      debugPrint('[HistoryRepository] Removed duplicate measurement timestamps from API response');
    }
    return normalized;
  }
}
