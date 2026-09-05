import 'package:flutter/material.dart';
import '../../domain/plant_pot.dart';

class AlertBadge extends StatelessWidget {
  const AlertBadge({
    super.key,
    required this.alert,
  });

  final PlantAlert alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: alert.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(alert.icon, color: alert.color, size: 14),
          const SizedBox(width: 4),
          Text(
            alert.label,
            style: TextStyle(
              color: alert.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
