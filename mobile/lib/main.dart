import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/ar_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force portrait, hide system UI for full immersion
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ARVisionGoldApp());
}

class ARVisionGoldApp extends StatelessWidget {
  const ARVisionGoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARVision Gold',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080B0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF0B90B),   // gold
          secondary: Color(0xFF00E676), // green
          error: Color(0xFFFF1744),     // red
          surface: Color(0xFF0D1117),
        ),
        textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme),
      ),
      home: const ARScreen(),
    );
  }
}
