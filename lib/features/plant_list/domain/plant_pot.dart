import 'moisture_state.dart';

class PlantPot {
  final String id;
  final String name;
  final int moistureValue;
  final DateTime lastUpdate;

  final String boardId;
  final int dryCalibration;
  final int wetCalibration;

  PlantPot({
    required this.id,
    required this.boardId,
    required this.name,
    required this.moistureValue,
    required this.lastUpdate,
    required this.dryCalibration,
    required this.wetCalibration,
  });

  MoistureState get moistureState {
    if (dryCalibration == wetCalibration) return MoistureState.humid;

    // Obliczamy udział w zakresie, od 0 (Mokro) do 1 (Sucho)
    // Zakładamy, że sucho to odczyt wyższy (>700), mokro to niższy (<400)
    double pct = (moistureValue - wetCalibration) / (dryCalibration - wetCalibration);

    if (pct >= 0.75) return MoistureState.dry;
    if (pct <= 0.25) return MoistureState.wet;
    return MoistureState.humid;
  }
}
