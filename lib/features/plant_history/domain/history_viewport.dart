import 'dart:math' as math;

/// Granice, w których może poruszać się widok wykresu (czas w ms od epoki).
class HistoryBounds {
  const HistoryBounds({
    required this.minMs,
    required this.maxMs,
    required this.minSpanMs,
    required this.maxSpanMs,
  });

  final double minMs;
  final double maxMs;
  final double minSpanMs;
  final double maxSpanMs;
}

/// Widoczne okno czasu. Zależy wyłącznie od czasu, nie od załadowanych danych,
/// więc dociągnięcie starszej historii nie może przesunąć ani przeskalować widoku.
class HistoryViewport {
  const HistoryViewport({required this.startMs, required this.spanMs});

  final double startMs;
  final double spanMs;

  double get endMs => startMs + spanMs;

  double xFor(double timeMs, double plotWidth) =>
      (timeMs - startMs) / spanMs * plotWidth;

  double timeAt(double x, double plotWidth) =>
      startMs + x / plotWidth * spanMs;

  /// Przesuwa widok tak, by treść podążała za palcem o [dx] pikseli.
  HistoryViewport panBy(double dx, double plotWidth, HistoryBounds bounds) {
    return HistoryViewport(
      startMs: startMs - dx / plotWidth * spanMs,
      spanMs: spanMs,
    ).clamped(bounds);
  }

  /// [factor] > 1 przybliża; chwila pod [focalX] zostaje w tym samym miejscu.
  HistoryViewport zoomAt(
    double factor,
    double focalX,
    double plotWidth,
    HistoryBounds bounds,
  ) {
    return HistoryViewport.anchored(
      focalTimeMs: timeAt(focalX, plotWidth),
      focalX: focalX,
      spanMs: spanMs / factor,
      plotWidth: plotWidth,
      bounds: bounds,
    );
  }

  /// Widok o rozpiętości [spanMs], w którym [focalTimeMs] leży w pikselu [focalX].
  factory HistoryViewport.anchored({
    required double focalTimeMs,
    required double focalX,
    required double spanMs,
    required double plotWidth,
    required HistoryBounds bounds,
  }) {
    final span = _clampSpan(spanMs, bounds);
    return HistoryViewport(
      startMs: focalTimeMs - focalX / plotWidth * span,
      spanMs: span,
    ).clamped(bounds);
  }

  HistoryViewport clamped(HistoryBounds bounds) {
    final span = _clampSpan(spanMs, bounds);
    final start = math.max(
      bounds.minMs,
      math.min(startMs, bounds.maxMs - span),
    );
    return HistoryViewport(startMs: start, spanMs: span);
  }

  static double _clampSpan(double spanMs, HistoryBounds bounds) {
    final upper = math.min(bounds.maxSpanMs, bounds.maxMs - bounds.minMs);
    return math.max(bounds.minSpanMs, math.min(spanMs, upper));
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryViewport &&
      other.startMs == startMs &&
      other.spanMs == spanMs;

  @override
  int get hashCode => Object.hash(startMs, spanMs);
}

/// Czy widok zbliżył się do brzegu załadowanych danych na tyle, by dociągnąć starsze.
bool shouldPrefetchOlder({
  required HistoryViewport viewport,
  required DateTime loadedFrom,
  required bool hasMoreOlderData,
}) {
  if (!hasMoreOlderData) return false;
  const minMarginMs = 24 * 3600 * 1000.0;
  final marginMs = math.max(minMarginMs, viewport.spanMs * 0.5);
  return viewport.startMs <
      loadedFrom.millisecondsSinceEpoch.toDouble() + marginMs;
}
