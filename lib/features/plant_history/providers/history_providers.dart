import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/history_repository.dart';
import '../domain/history_measurement.dart';

const historyPeriodHours = {'12h': 12, '24h': 24, '3d': 72, '7d': 168, 'all': 43800};
const historyPeriodBucketMinutes = {'12h': 0, '24h': 0, '3d': 5, '7d': 30, 'all': 60};

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

/// Wybrany okres wykresu, osobny stan per doniczka (kluczowany po boardId).
final selectedPeriodProvider =
    StateProvider.autoDispose.family<String, String>((ref, boardId) => '7d');

/// Klucz: (boardId, period). Pobiera pomiary dla wybranej doniczki i okresu.
final historyProvider =
    FutureProvider.autoDispose.family<List<HistoryMeasurement>, (String, String)>((ref, params) {
  final (boardId, period) = params;
  final to = DateTime.now();
  final from = to.subtract(Duration(hours: historyPeriodHours[period]!));
  return ref.read(historyRepositoryProvider).fetchHistory(
        boardId,
        from: from,
        to: to,
        bucketMinutes: historyPeriodBucketMinutes[period]!,
      );
});
