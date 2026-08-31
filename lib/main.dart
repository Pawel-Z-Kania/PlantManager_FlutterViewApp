import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// --- INICJALIZACJA PROJEKTU SUPABASE ---
// (Uzupełnij swoimi danymi publicznymi z zakładki API Supabase)
const String supabaseUrl = 'https://vkpxmvmthcdakeomseaf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_457NI-KNXQINDcX3R5dFBg_uR3U40bi';
// Replace with your Vercel deployment URL
const String vercelApiUrl = 'https://plant-manager-server-backend.vercel.app';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const PlantMonitorScreen(),
    );
  }
}

// ------------------------------------------
// MODEL DANYCH
// ------------------------------------------
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

class HistoryMeasurement {
  final int sensorValue;
  final DateTime measuredAt;

  HistoryMeasurement({required this.sensorValue, required this.measuredAt});

  factory HistoryMeasurement.fromJson(Map<String, dynamic> json) =>
      HistoryMeasurement(
        sensorValue: json['sensor_value'] as int,
        measuredAt: DateTime.parse(json['measured_at'] as String).toLocal(),
      );
}

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

class HistoryService {
  static Future<List<HistoryMeasurement>> fetchHistory(
    String boardId, {
    required DateTime from,
    required DateTime to,
    int bucketMinutes = 0,
  }) async {
    if (boardId.isEmpty) throw Exception('Brak board_id dla tej doniczki');
    final params = {
      'board_id': boardId,
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      if (bucketMinutes > 0) 'bucket_minutes': bucketMinutes.toString(),
    };
    final uri = Uri.parse('$vercelApiUrl/api/history').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Błąd serwera: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    return list
        .map((e) => HistoryMeasurement.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ------------------------------------------
// UI & LOGIKA EKRANU GLOWNEGO 
// ------------------------------------------
class PlantMonitorScreen extends StatefulWidget {
  const PlantMonitorScreen({super.key});

  @override
  State<PlantMonitorScreen> createState() => _PlantMonitorScreenState();
}

class _PlantMonitorScreenState extends State<PlantMonitorScreen> {
  final _supabase = Supabase.instance.client;
  List<PlantPot> plants = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDoniczkiData();
  }

  /// 1. POBIERANIE Z BAZY DANYCH HTTP REST
  Future<void> _fetchDoniczkiData() async {
    setState(() => isLoading = true);
    
    try {
      final response = await _supabase
          .from('pots')
          .select('id, name, board_id, last_signal_time, dry_calibration_value, wet_calibration_value, pot_measurements(sensor_value)')
          .order('measured_at', referencedTable: 'pot_measurements', ascending: false)
          .limit(1, referencedTable: 'pot_measurements');

      final List<PlantPot> loadedPlants = [];
      for (var row in response) {
         final List measurements = row['pot_measurements'] ?? [];
         final int latestVal = measurements.isNotEmpty ? measurements[0]['sensor_value'] as int : 0;
         
         final DateTime updateTime = row['last_signal_time'] != null 
             ? DateTime.parse(row['last_signal_time']).toLocal() 
             : DateTime.now();

         loadedPlants.add(PlantPot(
           id: row['id'].toString(),
           boardId: row['board_id']?.toString() ?? '',
           name: row['name'] ?? 'Brak nazwy',
           moistureValue: latestVal,
           lastUpdate: updateTime,
           dryCalibration: row['dry_calibration_value'] ?? 700,
           wetCalibration: row['wet_calibration_value'] ?? 400,
         ));
      }

      setState(() {
        plants = loadedPlants;
        isLoading = false;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd pobierania danych: $e'), backgroundColor: Colors.red),
      );
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inteligentne Doniczki'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchDoniczkiData(),
          )
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : plants.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plants.length,
              itemBuilder: (context, index) {
                return _buildPlantCard(plants[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.eco_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Brak przypisanych doniczek w Twoim koncie.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(PlantPot plant) {
    final state = plant.moistureState;
    final diff = DateTime.now().difference(plant.lastUpdate);
    final String timeAgo = diff.inMinutes < 1 ? "Przed chwilą" : "${diff.inMinutes} min temu";

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HistoryScreen(plant: plant)),
      ),
      child: Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.grass, size: 36, color: Colors.green),
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, size: 24),
                        color: Colors.green.shade700,
                        onPressed: () => _showSettingsBottomSheet(plant),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.history_toggle_off, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Ostatni: $timeAgo',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: state.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(state.icon, color: state.color, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        state.label,
                        style: TextStyle(color: state.color, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${plant.moistureValue} / 1024',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _showSettingsBottomSheet(PlantPot plant) {
    final nameController = TextEditingController(text: plant.name);
    double currentWet = plant.wetCalibration.toDouble();
    double currentDry = plant.dryCalibration.toDouble();

    // Zabezpieczenie przed błędem RangeSlider (min >= max)
    if (currentWet >= currentDry) {
      currentWet = 400;
      currentDry = 700;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Pozwala na dopasowanie do klawiatury
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // Unoszenie nad klawiaturą
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ustawienia doniczki',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa doniczki',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Kalibracja czujnika (Mokro - Sucho)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  RangeSlider(
                    values: RangeValues(currentWet, currentDry),
                    min: 0,
                    max: 1024,
                    divisions: 1024,
                    labels: RangeLabels(
                      currentWet.round().toString(),
                      currentDry.round().toString(),
                    ),
                    activeColor: Colors.green,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: (RangeValues values) {
                      setModalState(() {
                        currentWet = values.start;
                        currentDry = values.end;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Mokro: ${currentWet.round()}', style: const TextStyle(color: Colors.blue)),
                      Text('Sucho: ${currentDry.round()}', style: const TextStyle(color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _updatePlantSettings(
                          plant.id,
                          nameController.text,
                          currentDry.round(),
                          currentWet.round(),
                        );
                      },
                      child: const Text('Zapisz zmiany', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updatePlantSettings(String id, String name, int dry, int wet) async {
    setState(() => isLoading = true);
    try {
      final response = await http.put(
        Uri.parse('$vercelApiUrl/api/update-pot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'name': name,
          'dry_calibration_value': dry,
          'wet_calibration_value': wet,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Błąd serwera: ${response.statusCode}');
      }
      _fetchDoniczkiData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.red),
      );
      setState(() => isLoading = false);
    }
  }
}

// ------------------------------------------
// EKRAN HISTORII POMIARÓW
// ------------------------------------------
class HistoryScreen extends StatefulWidget {
  final PlantPot plant;
  const HistoryScreen({super.key, required this.plant});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryMeasurement> _measurements = [];
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = '24h';

  static const _periodHours = {'12h': 12, '24h': 24, '3d': 72, '7d': 168, 'all': 43800};
  static const _periodBucketMinutes = {'12h': 0, '24h': 0, '3d': 5, '7d': 30, 'all': 60};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final to   = DateTime.now();
      final from = to.subtract(Duration(hours: _periodHours[_selectedPeriod]!));
      final data = await HistoryService.fetchHistory(
        widget.plant.boardId,
        from: from,
        to: to,
        bucketMinutes: _periodBucketMinutes[_selectedPeriod]!,
      );
      setState(() {
        _measurements = data; // API returns ascending order
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plant.name),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _measurements.isEmpty
                  ? const Center(child: Text('Brak danych historycznych'))
                  : _buildChart(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadHistory,
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = ['12h', '24h', '3d', '7d', 'all'];
    const labels = {'12h': '12h', '24h': '24h', '3d': '3 dni', '7d': 'Tydzień', 'all': 'Wszystko'};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: periods.map((p) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            label: Text(labels[p]!),
            selected: _selectedPeriod == p,
            selectedColor: Colors.green.shade600,
            labelStyle: TextStyle(color: _selectedPeriod == p ? Colors.white : null),
            onSelected: (_) {
              _selectedPeriod = p;
              _loadHistory();
            },
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildChart() {
    final data = _measurements;
    return Column(
      children: [
        _buildPeriodSelector(),
        Expanded(
          child: data.isEmpty
              ? const Center(child: Text('Brak danych dla wybranego okresu'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = max(constraints.maxWidth, data.length * 12.0);
                    return InteractiveViewer(
                      constrained: false,
                      boundaryMargin: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: SizedBox(
                        width: chartWidth,
                        height: constraints.maxHeight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 24, 24, 16),
                          child: LineChart(_buildChartData(data)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  LineChartData _buildChartData(List<HistoryMeasurement> data) {
    // X = Unix seconds; avoids double overflow that milliseconds cause post-2020
    final spots = data.map((m) => FlSpot(
      m.measuredAt.millisecondsSinceEpoch / 1000.0,
      m.sensorValue.toDouble(),
    )).toList();

    final minX = spots.first.x;
    final maxX = spots.length > 1 ? spots.last.x : spots.first.x + 3600;
    final rangeSeconds = maxX - minX;

    final double intervalX;
    final bool showDate;
    if (rangeSeconds <= 86400) {
      intervalX = 3600;  // every 1 h
      showDate = false;
    } else if (rangeSeconds <= 259200) {
      intervalX = 14400; // every 4 h
      showDate = true;
    } else {
      intervalX = 86400; // every day
      showDate = true;
    }

    return LineChartData(
      minX: minX,
      maxX: maxX,
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: showDate ? 40 : 32,
            interval: intervalX,
            getTitlesWidget: (value, meta) {
              final t = DateTime.fromMillisecondsSinceEpoch(
                (value * 1000).toInt(),
              ).toLocal();
              final timeStr =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              final label = showDate
                  ? '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}\n$timeStr'
                  : timeStr;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      minY: 0,
      maxY: 1024,
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: widget.plant.wetCalibration.toDouble(),
            color: Colors.blue.withValues(alpha: 0.5),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 5, bottom: 5),
              style: const TextStyle(color: Colors.blue, fontSize: 10),
              labelResolver: (line) => 'Mokro',
            ),
          ),
          HorizontalLine(
            y: widget.plant.dryCalibration.toDouble(),
            color: Colors.orange.withValues(alpha: 0.5),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.only(right: 5, top: 5),
              style: const TextStyle(color: Colors.orange, fontSize: 10),
              labelResolver: (line) => 'Sucho',
            ),
          ),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.green.shade600,
          barWidth: 2,
          dotData: FlDotData(show: spots.length <= 20),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.shade600.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

