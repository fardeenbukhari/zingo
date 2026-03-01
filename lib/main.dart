import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService().init();
  } catch (e) {
    debugPrint('Initialization failed: $e');
  }
  runApp(const ZingooApp());
}

class ZingooApp extends StatelessWidget {
  const ZingooApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zingoo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFFBFBFB), // Soft white
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF121212), // Matte Black for high contrast
          secondary: Color(0xFF626262), // Gray for sub-elements
          surface: Color(0xFFFFFFFF), // Pure White surfaces
        ),
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Inter'),
      ),
      home: const LoginScreen(),
    );
  }
}
