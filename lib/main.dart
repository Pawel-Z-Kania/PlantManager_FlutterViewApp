import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
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

// Model danych dla doniczki
class PlantPot {
  final int id;
  int moistureValue;
  DateTime lastUpdate;

  PlantPot(
      {required this.id,
      required this.moistureValue,
      required this.lastUpdate});

  // Określenie stanu wilgotności
  MoistureState get moistureState {
    if (moistureValue > 700) {
      return MoistureState.dry;
    } else if (moistureValue < 400) {
      return MoistureState.wet;
    } else {
      return MoistureState.humid;
    }
  }
}

enum MoistureState {
  dry, // suchy (>700)
  humid, // wilgotny (400-700)
  wet, // mokry (<400)
}

extension MoistureStateExtension on MoistureState {
  String get label {
    switch (this) {
      case MoistureState.dry:
        return 'Suchy';
      case MoistureState.humid:
        return 'Wilgotny';
      case MoistureState.wet:
        return 'Mokry';
    }
  }

  Color get color {
    switch (this) {
      case MoistureState.dry:
        return Colors.orange;
      case MoistureState.humid:
        return Colors.green;
      case MoistureState.wet:
        return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case MoistureState.dry:
        return Icons.water_drop_outlined;
      case MoistureState.humid:
        return Icons.water_drop;
      case MoistureState.wet:
        return Icons.waves;
    }
  }
}

class PlantMonitorScreen extends StatefulWidget {
  const PlantMonitorScreen({super.key});

  @override
  State<PlantMonitorScreen> createState() => _PlantMonitorScreenState();
}

class _PlantMonitorScreenState extends State<PlantMonitorScreen> {
  // --- KONFIGURACJA ---
  final String broker = 'bc35b9b5a19a425391dfc120db3617fa.s1.eu.hivemq.cloud';
  final int port = 8883;
  final String username = 'esp8266_user';
  final String password = 'esp8266_Pass';
  // Dane publikowane są osobno dla każdej rośliny: dom/plantManager/<id>
  final String topic = 'dom/plantManager/#';

  String connectionState = 'Rozłączony';
  Map<int, PlantPot> plants = {}; // Mapa doniczek według ID
  MqttServerClient? client;

  @override
  void initState() {
    super.initState();
    connect();
  }

  Future<void> connect() async {
    // Unikalne ID klienta dla aplikacji
    client = MqttServerClient.withPort(broker, 'flutter_client', port);
    client!.secure = true; // HiveMQ wymaga SSL
    client!.securityContext = SecurityContext.defaultContext;
    client!.logging(on: true);

    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_phone_id')
        .authenticateAs(username, password)
        .startClean();
    client!.connectionMessage = connMess;

    try {
      setState(() => connectionState = 'Łączenie...');
      await client!.connect();
    } catch (e) {
      setState(() => connectionState = 'Błąd: $e');
      client!.disconnect();
      return;
    }

    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() => connectionState = 'Połączono z HiveMQ!');

      // Subskrypcja tematu
      client!.subscribe(topic, MqttQos.atMostOnce);

      // Nasłuchiwanie zmian
      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        // Parsowanie JSON: {"id":237405,"val":792}
        try {
          final Map<String, dynamic> data = jsonDecode(pt);
          final int id = data['id'] as int;
          final int val = data['val'] as int;

          setState(() {
            if (plants.containsKey(id)) {
              plants[id]!.moistureValue = val;
              plants[id]!.lastUpdate = DateTime.now();
            } else {
              plants[id] = PlantPot(
                id: id,
                moistureValue: val,
                lastUpdate: DateTime.now(),
              );
            }
          });
          print('Odebrano: ID=$id, wartość=$val');
        } catch (e) {
          print('Błąd parsowania JSON: $e');
        }
      });
    } else {
      setState(() => connectionState = 'Nieudane połączenie');
      client!.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Doniczki'),
        backgroundColor: Colors.green.shade100,
      ),
      body: Column(
        children: [
          // Status połączenia
          Container(
            padding: const EdgeInsets.all(12),
            color: connectionState.contains('Połączono')
                ? Colors.green.shade50
                : Colors.orange.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  connectionState.contains('Połączono')
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color: connectionState.contains('Połączono')
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  connectionState,
                  style: TextStyle(
                    color: connectionState.contains('Połączono')
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Lista doniczek
          Expanded(
            child: plants.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grass, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Oczekiwanie na dane z czujników...',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: plants.length,
                    itemBuilder: (context, index) {
                      final plant = plants.values.elementAt(index);
                      return _buildPlantCard(plant);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(PlantPot plant) {
    final state = plant.moistureState;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Ikona rośliny
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.grass, size: 36, color: Colors.green),
            ),
            const SizedBox(width: 16),
            // Informacje o doniczce
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doniczka #${plant.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wartość: ${plant.moistureValue}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Stan wilgotności
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: state.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: state.color, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(state.icon, color: state.color, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    state.label,
                    style: TextStyle(
                      color: state.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
