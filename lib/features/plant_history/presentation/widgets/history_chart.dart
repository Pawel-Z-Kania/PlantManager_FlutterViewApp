import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import '../../domain/history_measurement.dart';
import '../../domain/history_series.dart';
import '../../domain/history_viewport.dart';
import 'frozen_voltage_axis.dart';
import 'frozen_y_axis.dart';
import 'history_chart_painter.dart';

/// Wykres historii z widokiem zależnym wyłącznie od czasu: dociągnięte starsze dane
/// dorysowują się po lewej bez zmiany pozycji i skali widoku.
class HistoryChart extends StatefulWidget {
  const HistoryChart({
    super.key,
    required this.data,
    required this.wetCalibration,
    required this.dryCalibration,
    required this.loadedFrom,
    required this.loadedTo,
    required this.earliestAllowed,
    this.fallbackExpectedInterval,
    this.isLoadingOlder = false,
    this.hasMoreOlderData = true,
    this.onNeedOlderData,
  });

  final List<HistoryMeasurement> data;
  final int wetCalibration;
  final int dryCalibration;
  final DateTime loadedFrom;

  /// Moment ostatniego pobrania ("teraz" na osi).
  final DateTime loadedTo;

  /// Najstarszy moment, do którego można przewinąć wykres.
  final DateTime earliestAllowed;
  final Duration? fallbackExpectedInterval;
  final bool isLoadingOlder;
  final bool hasMoreOlderData;
  final VoidCallback? onNeedOlderData;

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart>
    with SingleTickerProviderStateMixin {
  static const _screenHorizontalPadding = 16.0;
  static const _axisWidth = 48.0;
  static const _initialSpan = Duration(hours: 96);
  static const _minSpan = Duration(hours: 6);
  static const _maxSpan = Duration(days: 14);
  static const _rightBuffer = Duration(hours: 6);
  static const _selectionRadius = 32.0;
  static const _retryDelay = Duration(seconds: 5);
  static const _flingDrag = 0.135;

  late HistorySeries _series;
  late final ValueNotifier<HistoryViewport> _viewport;
  final ValueNotifier<double?> _selectedTimeMs = ValueNotifier(null);
  late final AnimationController _fling;

  double _plotWidth = 0;
  double _flingLast = 0;
  double _gestureFocalTimeMs = 0;
  double _gestureStartSpanMs = 0;
  bool _olderRequested = false;
  DateTime? _retryAfter;

  HistoryBounds get _bounds => HistoryBounds(
    minMs: widget.earliestAllowed.millisecondsSinceEpoch.toDouble(),
    maxMs:
        widget.loadedTo.millisecondsSinceEpoch.toDouble() +
        _rightBuffer.inMilliseconds,
    minSpanMs: _minSpan.inMilliseconds.toDouble(),
    maxSpanMs: _maxSpan.inMilliseconds.toDouble(),
  );

  HistoryViewport get _initialViewport {
    final bounds = _bounds;
    return HistoryViewport(
      startMs: bounds.maxMs - _initialSpan.inMilliseconds,
      spanMs: _initialSpan.inMilliseconds.toDouble(),
    ).clamped(bounds);
  }

  @override
  void initState() {
    super.initState();
    _series = _buildSeries();
    _viewport = ValueNotifier(_initialViewport)
      ..addListener(_checkPrefetchOlder);
    _fling = AnimationController.unbounded(vsync: this)
      ..addListener(_onFlingTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPrefetchOlder());
  }

  @override
  void didUpdateWidget(covariant HistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data) ||
        oldWidget.fallbackExpectedInterval != widget.fallbackExpectedInterval) {
      _series = _buildSeries();
    }

    if (oldWidget.loadedTo != widget.loadedTo) {
      _fling.stop();
      _viewport.value = _initialViewport;
      _selectedTimeMs.value = null;
      _olderRequested = false;
      _retryAfter = null;
    }

    if (oldWidget.isLoadingOlder && !widget.isLoadingOlder) {
      _olderRequested = false;
      if (oldWidget.loadedFrom == widget.loadedFrom) {
        // Żądanie nie przyniosło danych (błąd): nie ponawiamy w pętli.
        _retryAfter = DateTime.now().add(_retryDelay);
      } else {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _checkPrefetchOlder(),
        );
      }
    }
  }

  @override
  void dispose() {
    _fling.dispose();
    _viewport
      ..removeListener(_checkPrefetchOlder)
      ..dispose();
    _selectedTimeMs.dispose();
    super.dispose();
  }

  HistorySeries _buildSeries() => HistorySeries.fromMeasurements(
    widget.data,
    fallbackExpectedInterval: widget.fallbackExpectedInterval,
  );

  void _checkPrefetchOlder() {
    // Zmiana stanu dostawcy w trakcie budowania drzewa jest niedozwolona.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkPrefetchOlder(),
      );
      return;
    }
    final onNeedOlderData = widget.onNeedOlderData;
    if (!mounted ||
        onNeedOlderData == null ||
        _olderRequested ||
        widget.isLoadingOlder) {
      return;
    }
    final retryAfter = _retryAfter;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) return;
    if (!shouldPrefetchOlder(
      viewport: _viewport.value,
      loadedFrom: widget.loadedFrom,
      hasMoreOlderData: widget.hasMoreOlderData,
    )) {
      return;
    }
    _olderRequested = true;
    onNeedOlderData();
  }

  bool _panBy(double dx) {
    if (_plotWidth <= 0) return false;
    final current = _viewport.value;
    final next = current.panBy(dx, _plotWidth, _bounds);
    if (next == current) return false;
    _viewport.value = next;
    return true;
  }

  void _zoomAt(double factor, double focalX) {
    if (_plotWidth <= 0) return;
    _viewport.value = _viewport.value.zoomAt(
      factor,
      focalX,
      _plotWidth,
      _bounds,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _fling.stop();
    final viewport = _viewport.value;
    _gestureStartSpanMs = viewport.spanMs;
    _gestureFocalTimeMs = viewport.timeAt(
      details.localFocalPoint.dx,
      _plotWidth,
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_plotWidth <= 0) return;
    final focalX = details.localFocalPoint.dx;
    final next = HistoryViewport.anchored(
      focalTimeMs: _gestureFocalTimeMs,
      focalX: focalX,
      spanMs: _gestureStartSpanMs / math.max(details.scale, 0.05),
      plotWidth: _plotWidth,
      bounds: _bounds,
    );
    _viewport.value = next;
    // Po dojściu do granicy kotwica musi podążać za palcem, a nie za utraconą pozycją.
    _gestureFocalTimeMs = next.timeAt(focalX, _plotWidth);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (details.pointerCount > 0) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity.abs() < kMinFlingVelocity) return;
    _flingLast = 0;
    unawaited(_fling.animateWith(FrictionSimulation(_flingDrag, 0, velocity)));
  }

  void _onFlingTick() {
    final delta = _fling.value - _flingLast;
    _flingLast = _fling.value;
    if (delta == 0) return;
    if (!_panBy(delta)) _fling.stop();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      _fling.stop();
      if (scroll.scrollDelta.dx.abs() > scroll.scrollDelta.dy.abs()) {
        _panBy(-scroll.scrollDelta.dx);
      } else {
        _zoomAt(math.exp(-scroll.scrollDelta.dy / 300), scroll.localPosition.dx);
      }
    });
  }

  void _selectAt(double x) {
    if (_plotWidth <= 0 || _series.length == 0) return;
    final viewport = _viewport.value;
    final i = _series.nearestIndex(viewport.timeAt(x, _plotWidth));
    final pointX = viewport.xFor(_series.times[i], _plotWidth);
    _selectedTimeMs.value = (pointX - x).abs() <= _selectionRadius
        ? _series.times[i]
        : null;
  }

  void _zoomButton(double factor) {
    _fling.stop();
    _zoomAt(factor, _plotWidth / 2);
  }

  void _resetViewport() {
    _fling.stop();
    _viewport.value = _initialViewport;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _screenHorizontalPadding,
        0,
        _screenHorizontalPadding,
        _screenHorizontalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _axisWidth,
            child: FrozenYAxis(
              topPadding: historyChartTopPadding,
              bottomPadding: historyChartBottomPadding,
              wetCalibration: widget.wetCalibration,
              dryCalibration: widget.dryCalibration,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _plotWidth = constraints.maxWidth;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Listener(
                        onPointerSignal: _onPointerSignal,
                        child: MouseRegion(
                          onHover: (event) => _selectAt(event.localPosition.dx),
                          onExit: (_) => _selectedTimeMs.value = null,
                          child: GestureDetector(
                            key: const ValueKey('history-chart-plot'),
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: _onScaleUpdate,
                            onScaleEnd: _onScaleEnd,
                            onTapUp: (details) =>
                                _selectAt(details.localPosition.dx),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: HistoryChartPainter(
                                  series: _series,
                                  viewport: _viewport,
                                  selectedTimeMs: _selectedTimeMs,
                                  wetCalibration: widget.wetCalibration,
                                  dryCalibration: widget.dryCalibration,
                                  loadedFromMs: widget
                                      .loadedFrom
                                      .millisecondsSinceEpoch
                                      .toDouble(),
                                  nowMs: widget.loadedTo.millisecondsSinceEpoch
                                      .toDouble(),
                                  textColor: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Material(
                        color: theme.scaffoldBackgroundColor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Oddal wykres',
                              icon: const Icon(Icons.remove),
                              onPressed: () => _zoomButton(1 / 1.5),
                            ),
                            IconButton(
                              tooltip: 'Przybliż wykres',
                              icon: const Icon(Icons.add),
                              onPressed: () => _zoomButton(1.5),
                            ),
                            IconButton(
                              tooltip: 'Pokaż ostatnie dni',
                              icon: const Icon(Icons.restart_alt),
                              onPressed: _resetViewport,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.isLoadingOlder)
                      const Positioned(
                        left: 4,
                        top: 8,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (!widget.isLoadingOlder && !widget.hasMoreOlderData)
                      const Positioned(
                        left: 4,
                        top: 8,
                        child: Text(
                          'Brak starszych danych',
                          style: TextStyle(fontSize: 10, color: Colors.black45),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: _axisWidth, child: FrozenVoltageAxis()),
        ],
      ),
    );
  }
}
