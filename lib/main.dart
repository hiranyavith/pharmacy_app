// lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pharmacy_app/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1920, 1080),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });

  final prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String serial_number = await getMotherboardSerial();
  print('Motherboard Serial: $serial_number');
  String realSerial = 'PHDKN00WBC35FB';
  if (serial_number != realSerial) {
    print('Unauthorized device. Exiting app.');
    exit(0);
  }
  runApp(PharmacyApp(isLoggedIn: isLoggedIn));
}

Future<String> getMotherboardSerial() async {
  try {
    final result = await Process.run(
      'wmic',
      ['baseboard', 'get', 'serialnumber'],
    );

    final output = result.stdout.toString();

    final lines = output
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.length >= 2) {
      return lines[1];
    }

    return 'Unknown';
  } catch (e) {
    return 'Error';
  }
}

class PharmacyApp extends StatelessWidget {
  final bool isLoggedIn;
  const PharmacyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Hub Pharmacy System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
