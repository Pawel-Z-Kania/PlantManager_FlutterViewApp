import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/plant_list/domain/watering_forecast.dart';

void main() {
  final now = DateTime.utc(2026, 10, 3, 12);

  group('WateringForecast.fromDate', () {
    test('no forecast when the date is missing', () {
      final forecast = WateringForecast.fromDate(null, now);
      expect(forecast.status, WateringStatus.noForecast);
      expect(forecast.label, 'Brak prognozy');
    });

    test('upcoming beyond 24 h, due soon within 24 h (boundary inclusive)', () {
      expect(
        WateringForecast.fromDate(now.add(const Duration(hours: 24, minutes: 1)), now).status,
        WateringStatus.upcoming,
      );
      expect(
        WateringForecast.fromDate(now.add(const Duration(hours: 24)), now).status,
        WateringStatus.dueSoon,
      );
    });

    test('overdue from the exact moment of the forecast', () {
      expect(WateringForecast.fromDate(now, now).status, WateringStatus.overdue);
      expect(
        WateringForecast.fromDate(now.subtract(const Duration(days: 3)), now).label,
        'Przekroczono o 3 dni',
      );
    });

    test('labels use hours below 48 h and days above', () {
      expect(
        WateringForecast.fromDate(now.add(const Duration(minutes: 30)), now).label,
        'Podlej za mniej niż godzinę',
      );
      expect(
        WateringForecast.fromDate(now.add(const Duration(hours: 5, minutes: 10)), now).label,
        'Podlej za 5 godz.',
      );
      expect(
        WateringForecast.fromDate(now.add(const Duration(hours: 47)), now).label,
        'Podlej za 47 godz.',
      );
      expect(
        WateringForecast.fromDate(now.add(const Duration(hours: 50)), now).label,
        'Podlej za 2 dni',
      );
      expect(
        WateringForecast.fromDate(now.subtract(const Duration(hours: 2)), now).label,
        'Przekroczono o 2 godz.',
      );
    });
  });

  group('formatAgoPl', () {
    test('uses the singular only for exactly one day', () {
      expect(formatAgoPl(const Duration(seconds: 20)), 'przed chwilą');
      expect(formatAgoPl(const Duration(minutes: 12)), '12 min temu');
      expect(formatAgoPl(const Duration(hours: 5)), '5 godz. temu');
      expect(formatAgoPl(const Duration(days: 1, hours: 3)), '1 dzień temu');
      expect(formatAgoPl(const Duration(days: 2)), '2 dni temu');
      expect(formatAgoPl(const Duration(days: 22)), '22 dni temu');
    });
  });
}
