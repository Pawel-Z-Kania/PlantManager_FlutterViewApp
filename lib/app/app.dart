import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/notifications/domain/push_support.dart';
import '../features/notifications/providers/push_notification_providers.dart';
import '../features/plant_list/presentation/plant_list_screen.dart';
import '../features/plant_list/providers/plant_providers.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    if (isPushSupported(isWeb: kIsWeb, platform: defaultTargetPlatform)) {
      unawaited(ref.read(pushNotificationServiceProvider).start(
            onForegroundAlert: _showForegroundAlert,
            onOpenedFromNotification: _showPlantList,
          ));
    }
  }

  // invalidate zamiast refresh(), żeby lista nie znikała pod spinnerem.
  void _showForegroundAlert(String text) {
    ref.invalidate(plantsProvider);
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 8)),
    );
  }

  void _showPlantList() {
    ref.invalidate(plantsProvider);
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const PlantListScreen(),
    );
  }
}
