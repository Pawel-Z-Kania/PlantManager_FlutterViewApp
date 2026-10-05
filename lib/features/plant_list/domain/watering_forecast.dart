enum WateringStatus { noForecast, upcoming, dueSoon, overdue }

/// Prognoza podlania wyliczana po stronie klienta z `next_watered_date` (może być w przeszłości).
class WateringForecast {
  const WateringForecast._(this.status, this.span);

  /// Odstęp od daty prognozy (zawsze nieujemny); null przy braku prognozy.
  final Duration? span;
  final WateringStatus status;

  static const Duration dueSoonThreshold = Duration(hours: 24);

  factory WateringForecast.fromDate(DateTime? nextWateredDate, DateTime now) {
    if (nextWateredDate == null) {
      return const WateringForecast._(WateringStatus.noForecast, null);
    }

    final remaining = nextWateredDate.difference(now);
    if (remaining <= Duration.zero) {
      return WateringForecast._(WateringStatus.overdue, -remaining);
    }
    if (remaining <= dueSoonThreshold) {
      return WateringForecast._(WateringStatus.dueSoon, remaining);
    }
    return WateringForecast._(WateringStatus.upcoming, remaining);
  }

  String get label {
    switch (status) {
      case WateringStatus.noForecast:
        return 'Brak prognozy';
      case WateringStatus.upcoming:
      case WateringStatus.dueSoon:
        return 'Podlej za ${formatSpanPl(span!)}';
      case WateringStatus.overdue:
        return 'Przekroczono o ${formatSpanPl(span!)}';
    }
  }
}

/// Poniżej 48 h podajemy godziny, powyżej dni; od 2 dni polska forma jest zawsze "dni".
String formatSpanPl(Duration span) {
  if (span.inHours < 1) return 'mniej niż godzinę';
  if (span.inHours < 48) return '${span.inHours} godz.';
  return '${span.inDays} dni';
}

String formatAgoPl(Duration elapsed) {
  if (elapsed.inMinutes < 1) return 'przed chwilą';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} min temu';
  if (elapsed.inDays < 1) return '${elapsed.inHours} godz. temu';
  if (elapsed.inDays == 1) return '1 dzień temu';
  return '${elapsed.inDays} dni temu';
}
