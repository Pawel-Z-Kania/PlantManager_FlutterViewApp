import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../plant_list/domain/plant_pot.dart';
import '../providers/history_providers.dart';
import 'widgets/history_chart.dart';
import 'widgets/period_selector.dart';

class PlantHistoryScreen extends ConsumerWidget {
  const PlantHistoryScreen({super.key, required this.plant});

  final PlantPot plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(selectedPeriodProvider(plant.boardId));
    final historyKey = (plant.boardId, selectedPeriod);
    final historyAsync = ref.watch(historyProvider(historyKey));

    return Scaffold(
      appBar: AppBar(
        title: Text(plant.name),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(historyProvider(historyKey)),
          ),
        ],
      ),
      body: Column(
        children: [
          PeriodSelector(
            selectedPeriod: selectedPeriod,
            onSelected: (period) =>
                ref.read(selectedPeriodProvider(plant.boardId).notifier).state = period,
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildErrorState(ref, historyKey, error),
              data: (data) => data.isEmpty
                  ? const Center(child: Text('Brak danych dla wybranego okresu'))
                  : HistoryChart(
                      data: data,
                      wetCalibration: plant.wetCalibration,
                      dryCalibration: plant.dryCalibration,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, (String, String) historyKey, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('$error', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.invalidate(historyProvider(historyKey)),
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    );
  }
}
