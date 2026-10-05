import 'package:flutter/material.dart';
import '../../domain/watering_forecast.dart';

class WateringForecastChip extends StatelessWidget {
  const WateringForecastChip({super.key, required this.forecast});

  final WateringForecast forecast;

  @override
  Widget build(BuildContext context) {
    final color = _color(forecast.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(forecast.status), color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            forecast.label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Czerwień zostaje zarezerwowana dla alertów (bateria, połączenie).
  static Color _color(WateringStatus status) {
    switch (status) {
      case WateringStatus.noForecast:
        return Colors.grey.shade600;
      case WateringStatus.upcoming:
        return Colors.teal;
      case WateringStatus.dueSoon:
        return Colors.amber.shade800;
      case WateringStatus.overdue:
        return Colors.deepOrange;
    }
  }

  static IconData _icon(WateringStatus status) {
    switch (status) {
      case WateringStatus.noForecast:
        return Icons.help_outline;
      case WateringStatus.upcoming:
        return Icons.event_outlined;
      case WateringStatus.dueSoon:
        return Icons.schedule;
      case WateringStatus.overdue:
        return Icons.alarm;
    }
  }
}
