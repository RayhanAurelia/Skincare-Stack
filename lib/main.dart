import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'firebase_options.dart';
import 'pages/auth/welcome_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inisialisasi Awesome Notifications dengan Importance MAX untuk Pop-up (Heads-up)
  AwesomeNotifications().initialize(
    null, // icon default
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Skincare Alerts',
        channelDescription: 'Notifikasi untuk pengingat kedaluwarsa skincare',
        defaultColor: const Color(0xFF3F51B5),
        ledColor: Colors.white,
        importance: NotificationImportance.Max, // Penting agar muncul di header (Pop-up)
        channelShowBadge: true,
        onlyAlertOnce: true,
        playSound: true,
        criticalAlerts: true,
      )
    ],
    debug: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Skincare Stack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}
