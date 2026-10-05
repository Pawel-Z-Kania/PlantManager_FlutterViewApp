import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/plant_list/data/plant_repository.dart';

void main() {
  final repository = PlantRepository();

  Map<String, dynamic> row([Map<String, dynamic> overrides = const {}]) => {
        'id': 'pot-1',
        'board_id': 'board-1',
        'name': 'Skrzydłokwiat',
        'pot_measurements': [
          {'sensor_value': 450},
        ],
        'last_signal_time': '2026-10-03T10:00:00+00:00',
        'dry_calibration_value': 600,
        'wet_calibration_value': 400,
        'alerts': [],
        ...overrides,
      };

  test('maps plant type and watering dates from the API', () {
    final pot = repository.mapRow(row({
      'plant_type': 'skrzydlokwiat',
      'last_watered_at': '2026-09-29T20:46:44.959123+00:00',
      'next_watered_date': '2026-10-08T00:00:00+00:00',
    }));

    expect(pot.plantType, 'skrzydlokwiat');
    expect(pot.lastWateredAt!.toUtc(), DateTime.utc(2026, 9, 29, 20, 46, 44, 959, 123));
    expect(pot.nextWateredDate!.toUtc(), DateTime.utc(2026, 10, 8));
  });

  test('stays compatible with a backend that does not send the new fields', () {
    final pot = repository.mapRow(row());

    expect(pot.plantType, 'unknown');
    expect(pot.lastWateredAt, isNull);
    expect(pot.nextWateredDate, isNull);
  });

  test('treats null and malformed dates as missing', () {
    final pot = repository.mapRow(row({
      'last_watered_at': null,
      'next_watered_date': 'not-a-date',
    }));

    expect(pot.lastWateredAt, isNull);
    expect(pot.nextWateredDate, isNull);
  });
}
