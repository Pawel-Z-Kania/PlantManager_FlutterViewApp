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
    final controller = ref.read(historyWindowProvider(plant.boardId).notifier);
    final state = ref.watch(historyWindowProvider(plant.boardId));

    return Scaffold(
      appBar: AppBar(
        title: Text(plant.name),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshToNow,
          ),
        ],
      ),
      body: Column(
        children: [
          PeriodSelector(
            windowHours: state.windowHours,
            onSelected: controller.setWindowHours,
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _buildErrorState(controller, state.error!)
                    : state.measurements.isEmpty
                        ? const Center(child: Text('Brak danych dla wybranego okresu'))
                        : HistoryChart(
                            data: state.measurements,
                            wetCalibration: plant.wetCalibration,
                            dryCalibration: plant.dryCalibration,
                            windowHours: state.windowHours,
                            fallbackExpectedInterval: plant.intervalMinutes != null
                                ? Duration(minutes: plant.intervalMinutes!)
                                : null,
                            isLoadingOlder: state.isLoadingOlder,
                            hasMoreOlderData: state.hasMoreOlderData,
                            onNeedOlderData: controller.loadOlder,
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(HistoryWindowController controller, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('$error', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: controller.refreshToNow,
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    );
  }
}
