import 'package:flutter/material.dart';

enum MoistureState { dry, humid, wet }

extension MoistureStateExtension on MoistureState {
  String get label {
    switch (this) {
      case MoistureState.dry: return 'Suchy';
      case MoistureState.humid: return 'Wilgotny';
      case MoistureState.wet: return 'Mokry';
    }
  }

  Color get color {
    switch (this) {
      case MoistureState.dry: return Colors.orange;
      case MoistureState.humid: return Colors.green;
      case MoistureState.wet: return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case MoistureState.dry: return Icons.water_drop_outlined;
      case MoistureState.humid: return Icons.water_drop;
      case MoistureState.wet: return Icons.waves;
    }
  }
}
