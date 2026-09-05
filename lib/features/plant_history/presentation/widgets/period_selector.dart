import 'package:flutter/material.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onSelected,
  });

  final String selectedPeriod;
  final ValueChanged<String> onSelected;

  static const _periods = ['12h', '24h', '3d', '7d', 'all'];
  static const _labels = {'12h': '12h', '24h': '24h', '3d': '3 dni', '7d': 'Tydzień', 'all': 'Wszystko'};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _periods.map((p) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            label: Text(_labels[p]!),
            selected: selectedPeriod == p,
            selectedColor: Colors.green.shade600,
            labelStyle: TextStyle(color: selectedPeriod == p ? Colors.white : null),
            onSelected: (_) => onSelected(p),
          ),
        )).toList(),
      ),
    );
  }
}
