import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/plant_list/domain/plant_pot.dart';
import 'package:plant_app/features/plant_list/presentation/widgets/plant_card.dart';

void main() {
  final now = DateTime(2026, 10, 3, 12);

  PlantPot plant({DateTime? lastWatered, DateTime? nextWatered}) => PlantPot(
        id: 'pot-1',
        boardId: 'board-1',
        name: 'Skrzydłokwiat',
        moistureValue: 450,
        lastUpdate: now.subtract(const Duration(minutes: 5)),
        dryCalibration: 600,
        wetCalibration: 400,
        lastWateredAt: lastWatered,
        nextWateredDate: nextWatered,
      );

  Future<void> pump(WidgetTester tester, PlantPot pot) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlantCard(plant: pot, now: now, onTap: () {}, onSettingsTap: () {}),
      ),
    ));
  }

  testWidgets('shows "no forecast" and hides the last watering without data', (tester) async {
    await pump(tester, plant());

    expect(find.text('Brak prognozy'), findsOneWidget);
    expect(find.textContaining('Podlano'), findsNothing);
  });

  testWidgets('shows the upcoming and due soon chips', (tester) async {
    await pump(tester, plant(nextWatered: now.add(const Duration(days: 3))));
    expect(find.text('Podlej za 3 dni'), findsOneWidget);

    await pump(tester, plant(nextWatered: now.add(const Duration(hours: 6))));
    expect(find.text('Podlej za 6 godz.'), findsOneWidget);
  });

  testWidgets('shows how long the forecast has been exceeded and the last watering', (tester) async {
    await pump(
      tester,
      plant(
        lastWatered: now.subtract(const Duration(days: 9)),
        nextWatered: now.subtract(const Duration(days: 2, hours: 3)),
      ),
    );

    expect(find.text('Przekroczono o 2 dni'), findsOneWidget);
    expect(find.text('Podlano 9 dni temu'), findsOneWidget);
  });
}
