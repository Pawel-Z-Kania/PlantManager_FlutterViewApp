import 'package:flutter/material.dart';
import 'moisture_state.dart';

enum AlertSeverity { error, warning }

class PlantAlert {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final AlertSeverity severity;

  const PlantAlert({
    required this.code,
    required this.label,
    required this.icon,
    required this.color,
    required this.severity,
  });

  factory PlantAlert.fromJson(Map<String, dynamic> json) {
    final String severityStr = json['severity']?.toString() ?? 'warning';
    final AlertSeverity severity = severityStr.toLowerCase() == 'error'
        ? AlertSeverity.error
        : AlertSeverity.warning;

    final String iconName = json['icon']?.toString() ?? json['code']?.toString() ?? '';
    final IconData icon = _mapIconName(iconName, severity);

    final Color color = severity == AlertSeverity.error ? Colors.red : Colors.amber;

    return PlantAlert(
      code: json['code']?.toString() ?? 'ALERT',
      label: json['label']?.toString() ?? 'Alert',
      icon: icon,
      color: color,
      severity: severity,
    );
  }

  static IconData _mapIconName(String iconName, AlertSeverity severity) {
    final lower = iconName.toLowerCase();
    if (lower.contains('wifi') || lower.contains('disconnect')) {
      return Icons.wifi_off_rounded;
    }
    if (lower.contains('battery') && (lower.contains('0') || lower.contains('critical'))) {
      return Icons.battery_0_bar_rounded;
    }
    if (lower.contains('battery')) {
      return Icons.battery_3_bar_rounded;
    }
    return severity == AlertSeverity.error
        ? Icons.error_outline_rounded
        : Icons.warning_amber_rounded;
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'icon': code.toLowerCase(),
        'severity': severity == AlertSeverity.error ? 'error' : 'warning',
      };
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
  final int? intervalMinutes;
  final List<PlantAlert> alerts;

  PlantPot({
    required this.id,
    required this.boardId,
    required this.name,
    required this.moistureValue,
    required this.lastUpdate,
    required this.dryCalibration,
    required this.wetCalibration,
    this.batteryMv,
    this.intervalMinutes,
    this.alerts = const [],
  });

  MoistureState get moistureState {
    if (dryCalibration == wetCalibration) return MoistureState.humid;

    double pct = (moistureValue - wetCalibration) / (dryCalibration - wetCalibration);

    if (pct >= 0.75) return MoistureState.dry;
    if (pct <= 0.25) return MoistureState.wet;
    return MoistureState.humid;
  }

  List<PlantAlert> get activeAlerts => alerts;

  bool get hasError =>
      alerts.any((a) => a.severity == AlertSeverity.error);

  bool get hasWarning =>
      alerts.any((a) => a.severity == AlertSeverity.warning);
}
