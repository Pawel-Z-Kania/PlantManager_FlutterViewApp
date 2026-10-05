/// Znacznik osi czasu: siatka pionowa i etykieta pod wykresem.
class TimeTick {
  const TimeTick({
    required this.timeMs,
    required this.label,
    required this.isDayStart,
    this.dateLine,
  });

  final double timeMs;
  final String label;

  /// Początek doby lokalnej (mocniejsza linia siatki).
  final bool isDayStart;

  /// Dodatkowa linia z datą pod godziną (pierwszy znacznik i północ).
  final String? dateLine;
}

const _stepHoursCandidates = [1, 3, 6, 12, 24, 48, 168];

/// Znaczniki na granicach czasu lokalnego (poprawne przy zmianie czasu).
/// Krok to najmniejszy z listy, dla którego znaczniki są odległe o co najmniej [minSpacingPx].
List<TimeTick> buildTimeTicks({
  required double startMs,
  required double endMs,
  required double msPerPixel,
  double minSpacingPx = 56,
}) {
  var stepHours = _stepHoursCandidates.last;
  for (final candidate in _stepHoursCandidates) {
    if (candidate * 3600000.0 / msPerPixel >= minSpacingPx) {
      stepHours = candidate;
      break;
    }
  }

  final ticks = <TimeTick>[];
  final first = DateTime.fromMillisecondsSinceEpoch(startMs.floor());
  var day = DateTime(first.year, first.month, first.day);

  while (day.millisecondsSinceEpoch <= endMs) {
    if (stepHours < 24) {
      for (var h = 0; h < 24; h += stepHours) {
        final t = DateTime(day.year, day.month, day.day, h);
        _addIfVisible(ticks, t, startMs, endMs, stepHours);
      }
    } else if (_isDayTick(day, stepHours)) {
      _addIfVisible(ticks, day, startMs, endMs, stepHours);
    }
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return ticks;
}

bool _isDayTick(DateTime day, int stepHours) {
  if (stepHours == 24) return true;
  if (stepHours == 48) {
    final epochDay =
        DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
        86400000;
    return epochDay.isEven;
  }
  return day.weekday == DateTime.monday;
}

void _addIfVisible(
  List<TimeTick> ticks,
  DateTime t,
  double startMs,
  double endMs,
  int stepHours,
) {
  final ms = t.millisecondsSinceEpoch.toDouble();
  if (ms < startMs || ms > endMs) return;

  final date =
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}';
  if (stepHours >= 24) {
    ticks.add(TimeTick(timeMs: ms, label: date, isDayStart: true));
    return;
  }
  final time =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final isDayStart = t.hour == 0;
  ticks.add(
    TimeTick(
      timeMs: ms,
      label: time,
      isDayStart: isDayStart,
      dateLine: (isDayStart || ticks.isEmpty) ? date : null,
    ),
  );
}
