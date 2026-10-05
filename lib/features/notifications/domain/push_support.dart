import 'package:flutter/foundation.dart';

/// firebase_messaging nie ma implementacji dla Windows/Linux, a iOS i web nie są objęte pierwszą wersją push.
bool isPushSupported({required bool isWeb, required TargetPlatform platform}) =>
    !isWeb && platform == TargetPlatform.android;
