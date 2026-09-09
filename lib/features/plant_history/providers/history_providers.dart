import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/history_repository.dart';
import '../domain/history_measurement.dart';

/// Dostępne szerokości "okna" wykresu (w godzinach) — zastępują dawne sztywne presety
/// (12h/24h/3d/7d/all); "all" znika, bo zastępuje je przewijanie wstecz bez ograniczeń.
const historyWindowHoursOptions = [12, 24, 72, 168];
const historyWindowLabels = {12: '12h', 24: '24h', 72: '3 dni', 168: 'Tydzień'};
const historyWindowBucketMinutes = {12: 0, 24: 0, 72: 5, 168: 30};

/// Limit liczby doładowanych "kawałków" historii trzymanych w pamięci jednocześnie,
/// żeby bardzo długie przewijanie wstecz w jednej sesji nie rosło w nieskończoność.
const _maxLoadedWindows = 6;

class HistoryWindowState {
  final int windowHours;
  final List<HistoryMeasurement> measurements;
  final DateTime? loadedFrom;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool hasMoreOlderData;
  final Object? error;

  const HistoryWindowState({
    required this.windowHours,
    this.measurements = const [],
    this.loadedFrom,
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.hasMoreOlderData = true,
    this.error,
  });

  HistoryWindowState copyWith({
    List<HistoryMeasurement>? measurements,
    DateTime? loadedFrom,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMoreOlderData,
    Object? error,
    bool clearError = false,
  }) {
    return HistoryWindowState(
      windowHours: windowHours,
      measurements: measurements ?? this.measurements,
      loadedFrom: loadedFrom ?? this.loadedFrom,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreOlderData: hasMoreOlderData ?? this.hasMoreOlderData,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HistoryWindowController extends StateNotifier<HistoryWindowState> {
  HistoryWindowController(this._repository, this._boardId, {int initialWindowHours = 168})
      : super(HistoryWindowState(windowHours: initialWindowHours)) {
    _loadInitial();
  }

  final HistoryRepository _repository;
  final String _boardId;
  int _loadedChunks = 0;

  int get _bucketMinutes => historyWindowBucketMinutes[state.windowHours] ?? 0;

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final to = DateTime.now();
    final from = to.subtract(Duration(hours: state.windowHours));
    try {
      final data = await _repository.fetchHistory(
        _boardId,
        from: from,
        to: to,
        bucketMinutes: _bucketMinutes,
      );
      _loadedChunks = 1;
      state = state.copyWith(
        measurements: data,
        loadedFrom: from,
        isLoading: false,
        hasMoreOlderData: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Zmiana szerokości okna zawsze resetuje widok do najnowszych danych.
  Future<void> setWindowHours(int hours) async {
    if (hours == state.windowHours) return;
    _loadedChunks = 0;
    state = HistoryWindowState(windowHours: hours);
    await _loadInitial();
  }

  Future<void> refreshToNow() async {
    _loadedChunks = 0;
    state = HistoryWindowState(windowHours: state.windowHours);
    await _loadInitial();
  }

  /// Doładowuje wcześniejszy, przyległy fragment historii i dokleja go z przodu listy.
  Future<void> loadOlder() async {
    if (state.isLoadingOlder || !state.hasMoreOlderData || state.loadedFrom == null) return;

    state = state.copyWith(isLoadingOlder: true, clearError: true);
    final to = state.loadedFrom!;
    final from = to.subtract(Duration(hours: state.windowHours));
    try {
      final older = await _repository.fetchHistory(
        _boardId,
        from: from,
        to: to,
        bucketMinutes: _bucketMinutes,
      );
      if (older.isEmpty) {
        state = state.copyWith(isLoadingOlder: false, hasMoreOlderData: false);
        return;
      }
      _loadedChunks++;
      var merged = [...older, ...state.measurements];
      if (_loadedChunks > _maxLoadedWindows) {
        // Obcinamy najnowszy (dalszy od aktualnie oglądanej, wcześniejszej krawędzi) koniec,
        // żeby nie trzymać w pamięci więcej niż _maxLoadedWindows okien naraz.
        final keepUntil = from.add(Duration(hours: state.windowHours * _maxLoadedWindows));
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
      state = state.copyWith(isLoadingOlder: false, error: e);
    }
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

final historyWindowProvider = StateNotifierProvider.autoDispose
    .family<HistoryWindowController, HistoryWindowState, String>((ref, boardId) {
  return HistoryWindowController(ref.read(historyRepositoryProvider), boardId);
});
