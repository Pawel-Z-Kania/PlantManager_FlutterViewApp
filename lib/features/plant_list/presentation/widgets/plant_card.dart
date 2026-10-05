import 'package:flutter/material.dart';
import '../../domain/moisture_state.dart';
import '../../domain/plant_pot.dart';
import '../../domain/watering_forecast.dart';
import 'alert_badge.dart';
import 'watering_forecast_chip.dart';

class PlantCard extends StatelessWidget {
  const PlantCard({
    super.key,
    required this.plant,
    required this.now,
    required this.onTap,
    required this.onSettingsTap,
  });

  final PlantPot plant;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final state = plant.moistureState;
    final timeAgo = _capitalize(formatAgoPl(now.difference(plant.lastUpdate)));
    final forecast = plant.wateringForecast(now);
    final lastWatered = plant.lastWateredAt;

    final bool hasError = plant.hasError;
    final bool hasWarning = plant.hasWarning;

    final Color cardBgColor = hasError
        ? Colors.red.shade50.withValues(alpha: 0.6)
        : Colors.white;

    final BorderSide borderSide = hasError
        ? BorderSide(color: Colors.red.shade400, width: 1.5)
        : hasWarning
            ? BorderSide(color: Colors.amber.shade600, width: 1.5)
            : BorderSide.none;

    final Color iconBgColor = hasError
        ? Colors.red.shade100
        : hasWarning
            ? Colors.amber.shade100
            : Colors.green.shade50;

    final Color iconColor = hasError
        ? Colors.red.shade700
        : hasWarning
            ? Colors.amber.shade900
            : Colors.green;

    final IconData mainIcon = hasError ? Icons.warning_amber_rounded : Icons.grass;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        shadowColor: hasError ? Colors.red.withValues(alpha: 0.2) : Colors.black12,
        color: cardBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: borderSide,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(mainIcon, size: 36, color: iconColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plant.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: hasError ? Colors.red.shade900 : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings, size: 22),
                              color: Colors.grey.shade700,
                              onPressed: onSettingsTap,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.history_toggle_off, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Ostatni: $timeAgo',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            if (plant.batteryMv != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                plant.batteryMv! < 2700
                                    ? Icons.battery_0_bar_rounded
                                    : plant.batteryMv! <= 2800
                                        ? Icons.battery_3_bar_rounded
                                        : Icons.battery_full_rounded,
                                size: 14,
                                color: plant.batteryMv! < 2700
                                    ? Colors.red
                                    : plant.batteryMv! <= 2800
                                        ? Colors.amber.shade800
                                        : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${(plant.batteryMv! / 1000).toStringAsFixed(2)}V',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: plant.batteryMv! <= 2800 ? FontWeight.bold : FontWeight.normal,
                                  color: plant.batteryMv! < 2700
                                      ? Colors.red
                                      : plant.batteryMv! <= 2800
                                          ? Colors.amber.shade900
                                          : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: state.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(state.icon, color: state.color, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              state.label,
                              style: TextStyle(color: state.color, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${plant.moistureValue} / 1024',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  WateringForecastChip(forecast: forecast),
                  if (lastWatered != null)
                    Text(
                      'Podlano ${formatAgoPl(now.difference(lastWatered))}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                ],
              ),
              if (plant.activeAlerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final alert in plant.activeAlerts)
                      AlertBadge(alert: alert),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _capitalize(String text) => text[0].toUpperCase() + text.substring(1);
