import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/plant_repository.dart';
import '../domain/plant_pot.dart';
import '../domain/plant_type.dart';

final plantRepositoryProvider = Provider<PlantRepository>(
  (ref) => PlantRepository(),
);

/// Lista typów roślin zmienia się rzadko, więc jest pobierana raz na sesję.
final plantTypesProvider = FutureProvider<List<PlantType>>(
  (ref) => ref.read(plantRepositoryProvider).fetchPlantTypes(),
);

/// Co minutę odświeża teksty "przekroczono o ..." bez zapytań do serwera.
final minuteClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

final plantsProvider = AsyncNotifierProvider<PlantsNotifier, List<PlantPot>>(
  PlantsNotifier.new,
);

class PlantsNotifier extends AsyncNotifier<List<PlantPot>> {
  @override
  Future<List<PlantPot>> build() {
    return ref.read(plantRepositoryProvider).fetchPlants();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<PlantPot>>();
    state = await AsyncValue.guard(
      () => ref.read(plantRepositoryProvider).fetchPlants(),
    );
  }

  /// Zapisuje ustawienia doniczki i odświeża listę; rzuca wyjątek dalej, żeby UI mógł go pokazać.
  Future<void> updateSettings(
    String id,
    String name,
    int dry,
    int wet, {
    String? plantType,
  }) async {
    await ref
        .read(plantRepositoryProvider)
        .updateSettings(id, name, dry, wet, plantType: plantType);
    await refresh();
  }
}
