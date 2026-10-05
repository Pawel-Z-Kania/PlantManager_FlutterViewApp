class PlantType {
  final String code;
  final String labelPl;

  const PlantType({required this.code, required this.labelPl});

  factory PlantType.fromJson(Map<String, dynamic> json) {
    final code = json['code'].toString();
    return PlantType(code: code, labelPl: json['label_pl']?.toString() ?? code);
  }
}

const String unknownPlantType = 'unknown';
