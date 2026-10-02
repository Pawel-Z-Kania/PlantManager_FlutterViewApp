import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/history_repository.dart';
import '../domain/history_measurement.dart';

const historyWindowHours = 168;
const historyWindowBucketMinutes = 30;

/// Limit liczby doładowanych "kawałków" historii trzymanych w pamięci jednocześnie,
/// żeby bardzo długie przewijanie wstecz w jednej sesji nie rosło w nieskończoność.
const _maxLoadedWindows = 6;

class HistoryWindowState {
  final List<HistoryMeasurement> measurements;
  final DateTime? loadedFrom;
  final DateTime? loadedTo;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool hasMoreOlderData;
  final Object? error;

  const HistoryWindowState({
    this.measurements = const [],
    this.loadedFrom,
    this.loadedTo,
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.hasMoreOlderData = true,
    this.error,
  });

  HistoryWindowState copyWith({
    List<HistoryMeasurement>? measurements,
    DateTime? loadedFrom,
    DateTime? loadedTo,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMoreOlderData,
    Object? error,
    bool clearError = false,
  }) {
    return HistoryWindowState(
      measurements: measurements ?? this.measurements,
      loadedFrom: loadedFrom ?? this.loadedFrom,
      loadedTo: loadedTo ?? this.loadedTo,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreOlderData: hasMoreOlderData ?? this.hasMoreOlderData,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HistoryWindowController extends Notifier<HistoryWindowState> {
  HistoryWindowController(this._boardId);

  final String _boardId;
  int _loadedChunks = 0;
  int _requestVersion = 0;

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  @override
  HistoryWindowState build() {
    Future.microtask(_loadInitial);
    return const HistoryWindowState();
  }

  Future<void> _loadInitial() async {
    final requestVersion = ++_requestVersion;
    state = state.copyWith(isLoading: true, clearError: true);
    final to = DateTime.now();
    final from = to.subtract(const Duration(hours: historyWindowHours));
    try {
      final data = await _repository.fetchHistory(
        _boardId,
        from: from,
        to: to,
        bucketMinutes: historyWindowBucketMinutes,
      );
      if (!ref.mounted || requestVersion != _requestVersion) return;
      _loadedChunks = 1;
      state = state.copyWith(
        measurements: data,
        loadedFrom: from,
        loadedTo: to,
        isLoading: false,
        hasMoreOlderData: true,
      );
    } catch (e) {
      if (!ref.mounted || requestVersion != _requestVersion) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refreshToNow() async {
    _loadedChunks = 0;
    await _loadInitial();
  }

  /// Doładowuje wcześniejszy, przyległy fragment historii i dokleja go z przodu listy.
  Future<void> loadOlder() async {
    if (state.isLoadingOlder ||
        !state.hasMoreOlderData ||
        state.loadedFrom == null) {
      return;
    }

    final requestVersion = _requestVersion;
    state = state.copyWith(isLoadingOlder: true, clearError: true);
    final to = state.loadedFrom!;
    final from = to.subtract(const Duration(hours: historyWindowHours));
    try {
      final older = await _repository.fetchHistory(
        _boardId,
        from: from,
        to: to,
        bucketMinutes: historyWindowBucketMinutes,
      );
      if (!ref.mounted || requestVersion != _requestVersion) return;
      if (older.isEmpty) {
        state = state.copyWith(isLoadingOlder: false, hasMoreOlderData: false);
        return;
      }
      _loadedChunks++;
      var merged = _mergeMeasurements(older, state.measurements);
      if (_loadedChunks > _maxLoadedWindows) {
        // Obcinamy najnowszy (dalszy od aktualnie oglądanej, wcześniejszej krawędzi) koniec,
        // żeby nie trzymać w pamięci więcej niż _maxLoadedWindows okien naraz.
        final keepUntil = from.add(
          const Duration(hours: historyWindowHours * _maxLoadedWindows),
        );
        merged = merged.where((m) => m.measuredAt.isBefore(keepUntil)).toList();
        _loadedChunks = _maxLoadedWindows;
      }
      state = state.copyWith(
        measurements: merged,
        loadedFrom: from,
        isLoadingOlder: false,
        hasMoreOlderData: true,
      );
    } catch (e) {
      if (!ref.mounted || requestVersion != _requestVersion) return;
      state = state.copyWith(isLoadingOlder: false, error: e);
    }
  }
}

List<HistoryMeasurement> _mergeMeasurements(
  List<HistoryMeasurement> older,
  List<HistoryMeasurement> newer,
) {
  final measurementsByTimestamp = <int, HistoryMeasurement>{
    for (final measurement in older)
      measurement.measuredAt.millisecondsSinceEpoch: measurement,
    for (final measurement in newer)
      measurement.measuredAt.millisecondsSinceEpoch: measurement,
  };
  final merged = measurementsByTimestamp.values.toList()
    ..sort((first, second) => first.measuredAt.compareTo(second.measuredAt));
  return merged;
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(),
);

final historyWindowProvider = NotifierProvider.autoDispose
    .family<HistoryWindowController, HistoryWindowState, String>(
      HistoryWindowController.new,
    );
