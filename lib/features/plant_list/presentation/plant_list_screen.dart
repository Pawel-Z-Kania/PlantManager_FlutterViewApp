import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../plant_history/presentation/plant_history_screen.dart';
import '../domain/plant_pot.dart';
import '../domain/plant_type.dart';
import '../providers/plant_providers.dart';
import 'widgets/plant_card.dart';
import 'widgets/plant_settings_sheet.dart';

class PlantListScreen extends ConsumerWidget {
  const PlantListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(plantsProvider);
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inteligentne Doniczki'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(plantsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: plantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Błąd pobierania danych: $error', style: const TextStyle(color: Colors.red)),
        ),
        data: (plants) => plants.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: plants.length,
                itemBuilder: (context, index) {
                  final plant = plants[index];
                  return PlantCard(
                    plant: plant,
                    now: now,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlantHistoryScreen(plant: plant)),
                    ),
                    onSettingsTap: () => _openSettings(context, ref, plant),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref, PlantPot plant) async {
    // Brak listy typów nie blokuje edycji nazwy i kalibracji; lista zostanie pobrana ponownie.
    List<PlantType> plantTypes = const [];
    try {
      plantTypes = await ref.read(plantTypesProvider.future);
    } catch (_) {
      ref.invalidate(plantTypesProvider);
    }
    if (!context.mounted) return;

    showPlantSettingsSheet(context, plant, plantTypes, (name, dry, wet, plantType) async {
      try {
        await ref
            .read(plantsProvider.notifier)
            .updateSettings(plant.id, name, dry, wet, plantType: plantType);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.red),
        );
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.eco_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Brak przypisanych doniczek w Twoim koncie.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
