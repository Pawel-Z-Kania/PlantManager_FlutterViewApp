import 'package:flutter/material.dart';
import '../../domain/plant_pot.dart';

/// Modal do edycji nazwy i kalibracji czujnika; [onSave] wykonuje faktyczny zapis.
void showPlantSettingsSheet(
  BuildContext context,
  PlantPot plant,
  Future<void> Function(String name, int dry, int wet) onSave,
) {
  final nameController = TextEditingController(text: plant.name);
  double currentWet = plant.wetCalibration.toDouble();
  double currentDry = plant.dryCalibration.toDouble();

  // Zabezpieczenie przed błędem RangeSlider (min >= max)
  if (currentWet >= currentDry) {
    currentWet = 400;
    currentDry = 700;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Pozwala na dopasowanie do klawiatury
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, // Unoszenie nad klawiaturą
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ustawienia doniczki',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa doniczki',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Kalibracja czujnika (Mokro - Sucho)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                RangeSlider(
                  values: RangeValues(currentWet, currentDry),
                  min: 0,
                  max: 1024,
                  divisions: 1024,
                  labels: RangeLabels(
                    currentWet.round().toString(),
                    currentDry.round().toString(),
                  ),
                  activeColor: Colors.green,
                  inactiveColor: Colors.grey.shade300,
                  onChanged: (RangeValues values) {
                    setModalState(() {
                      currentWet = values.start;
                      currentDry = values.end;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mokro: ${currentWet.round()}', style: const TextStyle(color: Colors.blue)),
                    Text('Sucho: ${currentDry.round()}', style: const TextStyle(color: Colors.orange)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await onSave(nameController.text, currentDry.round(), currentWet.round());
                    },
                    child: const Text('Zapisz zmiany', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    },
  );
}
