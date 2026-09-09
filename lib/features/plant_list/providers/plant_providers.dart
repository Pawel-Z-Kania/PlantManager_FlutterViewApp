import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/plant_repository.dart';
import '../domain/plant_pot.dart';

final plantRepositoryProvider = Provider<PlantRepository>((ref) => PlantRepository());

final plantsProvider = AsyncNotifierProvider<PlantsNotifier, List<PlantPot>>(PlantsNotifier.new);

class PlantsNotifier extends AsyncNotifier<List<PlantPot>> {
  @override
  Future<List<PlantPot>> build() {
    return ref.read(plantRepositoryProvider).fetchPlants();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<PlantPot>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(plantRepositoryProvider).fetchPlants());
  }

  /// Zapisuje ustawienia doniczki i odświeża listę; rzuca wyjątek dalej, żeby UI mógł go pokazać.
  Future<void> updateSettings(String id, String name, int dry, int wet) async {
    await ref.read(plantRepositoryProvider).updateSettings(id, name, dry, wet);
    await refresh();
  }
}
