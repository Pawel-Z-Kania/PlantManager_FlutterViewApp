import 'package:flutter/material.dart';
import 'moisture_state.dart';

enum AlertSeverity { error, warning }

class PlantAlert {
  final String label;
  final IconData icon;
  final Color color;
  final AlertSeverity severity;

  const PlantAlert({
    required this.label,
    required this.icon,
    required this.color,
    required this.severity,
  });

  static PlantAlert disconnection() => const PlantAlert(
        label: 'Brak połączenia',
        icon: Icons.wifi_off_rounded,
        color: Colors.red,
        severity: AlertSeverity.error,
      );

  static PlantAlert criticalBattery(int mv) => PlantAlert(
        label: 'Bateria ${mv}mV',
        icon: Icons.battery_0_bar_rounded,
        color: Colors.red,
        severity: AlertSeverity.error,
      );

  static PlantAlert lowBattery(int mv) => PlantAlert(
        label: 'Bateria ${mv}mV',
        icon: Icons.battery_3_bar_rounded,
        color: Colors.amber,
        severity: AlertSeverity.warning,
      );
}

class PlantPot {
  final String id;
  final String name;
  final int moistureValue;
  final DateTime lastUpdate;

  final String boardId;
  final int dryCalibration;
  final int wetCalibration;
  final int? batteryMv;

  PlantPot({
    required this.id,
    required this.boardId,
    required this.name,
    required this.moistureValue,
    required this.lastUpdate,
    required this.dryCalibration,
    required this.wetCalibration,
    this.batteryMv,
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

  List<PlantAlert> get activeAlerts {
    final alerts = <PlantAlert>[];

    // Sprawdzenie rozłączenia (> 2 godziny)
    if (DateTime.now().difference(lastUpdate).inHours >= 2) {
      alerts.add(PlantAlert.disconnection());
    }

    // Sprawdzenie baterii
    if (batteryMv != null) {
      if (batteryMv! < 2700) {
        alerts.add(PlantAlert.criticalBattery(batteryMv!));
      } else if (batteryMv! <= 2800) {
        alerts.add(PlantAlert.lowBattery(batteryMv!));
      }
    }

    return alerts;
  }

  bool get hasError =>
      activeAlerts.any((a) => a.severity == AlertSeverity.error);

  bool get hasWarning =>
      activeAlerts.any((a) => a.severity == AlertSeverity.warning);
}
