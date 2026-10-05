import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/plant_history/domain/history_viewport.dart';

void main() {
  const bounds = HistoryBounds(
    minMs: 0,
    maxMs: 1000000,
    minSpanMs: 1000,
    maxSpanMs: 500000,
  );
  const viewport = HistoryViewport(startMs: 400000, spanMs: 100000);
  const width = 100.0;

  group('HistoryViewport', () {
    test('panBy moves the content with the finger', () {
      final panned = viewport.panBy(10, width, bounds);
      expect(panned.startMs, 390000);
      expect(panned.spanMs, viewport.spanMs);
    });

    test('panBy is clamped to the bounds', () {
      expect(viewport.panBy(100000, width, bounds).startMs, 0);
      expect(viewport.panBy(-100000, width, bounds).endMs, 1000000);
    });

    test('zoomAt keeps the time under the focal point', () {
      const focalX = 25.0;
      final focalTime = viewport.timeAt(focalX, width);
      final zoomed = viewport.zoomAt(2, focalX, width, bounds);
      expect(zoomed.spanMs, 50000);
      expect(zoomed.timeAt(focalX, width), closeTo(focalTime, 1e-6));
    });

    test('zoomAt respects the span limits', () {
      expect(viewport.zoomAt(1000, 50, width, bounds).spanMs, 1000);
      expect(viewport.zoomAt(0.0001, 50, width, bounds).spanMs, 500000);
    });

    test('clamped limits the span to the available range', () {
      const narrow = HistoryBounds(
        minMs: 0,
        maxMs: 20000,
        minSpanMs: 1000,
        maxSpanMs: 500000,
      );
      final clamped = const HistoryViewport(
        startMs: -5000,
        spanMs: 90000,
      ).clamped(narrow);
      expect(clamped.startMs, 0);
      expect(clamped.spanMs, 20000);
    });

    test('anchored places the focal time at the given pixel', () {
      final anchored = HistoryViewport.anchored(
        focalTimeMs: 450000,
        focalX: 50,
        spanMs: 200000,
        plotWidth: width,
        bounds: bounds,
      );
      expect(anchored.timeAt(50, width), closeTo(450000, 1e-6));
    });
  });

  group('shouldPrefetchOlder', () {
    final loadedFrom = DateTime.fromMillisecondsSinceEpoch(1000000000);
    final fromMs = loadedFrom.millisecondsSinceEpoch.toDouble();
    const hourMs = 3600000.0;

    HistoryViewport at(double startOffsetHours, double spanHours) =>
        HistoryViewport(
          startMs: fromMs + startOffsetHours * hourMs,
          spanMs: spanHours * hourMs,
        );

    test('is false while the viewport is far from the loaded edge', () {
      expect(
        shouldPrefetchOlder(
          viewport: at(60, 96),
          loadedFrom: loadedFrom,
          hasMoreOlderData: true,
        ),
        isFalse,
      );
    });

    test('is true within half a span of the loaded edge', () {
      expect(
        shouldPrefetchOlder(
          viewport: at(40, 96),
          loadedFrom: loadedFrom,
          hasMoreOlderData: true,
        ),
        isTrue,
      );
    });

    test('uses at least 24h margin for narrow views', () {
      expect(
        shouldPrefetchOlder(
          viewport: at(20, 6),
          loadedFrom: loadedFrom,
          hasMoreOlderData: true,
        ),
        isTrue,
      );
      expect(
        shouldPrefetchOlder(
          viewport: at(30, 6),
          loadedFrom: loadedFrom,
          hasMoreOlderData: true,
        ),
        isFalse,
      );
    });

    test('is false when there is no older data', () {
      expect(
        shouldPrefetchOlder(
          viewport: at(-10, 96),
          loadedFrom: loadedFrom,
          hasMoreOlderData: false,
        ),
        isFalse,
      );
    });
  });
}
