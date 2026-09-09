import 'package:flutter/material.dart';
import '../../providers/history_providers.dart';

/// Wybór szerokości "okna" wykresu; starsze dane wczytuje się przewijając wykres wstecz,
/// więc nie ma tu już opcji "Wszystko".
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.windowHours,
    required this.onSelected,
  });

  final int windowHours;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: historyWindowHoursOptions.map((hours) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            label: Text(historyWindowLabels[hours]!),
            selected: windowHours == hours,
            selectedColor: Colors.green.shade600,
            labelStyle: TextStyle(color: windowHours == hours ? Colors.white : null),
            onSelected: (_) => onSelected(hours),
          ),
        )).toList(),
      ),
    );
  }
}
