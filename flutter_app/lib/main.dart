import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/main_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SwaapApp());
}

class SwaapApp extends StatelessWidget {
  const SwaapApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SWAAP',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C8EFF),
            brightness: Brightness.dark,
          ).copyWith(
            surface: const Color(0xFF0F1117),
            onSurface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F1117),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF181A24),
            indicatorColor: const Color(0xFF6C8EFF).withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.all(
              GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        home: const MainPage(),
      );
}
