import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/main_page.dart';
import 'theme/colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SwaapApp());
}

class SwaapApp extends StatefulWidget {
  const SwaapApp({super.key});
  @override
  State<SwaapApp> createState() => _SwaapAppState();
}

class _SwaapAppState extends State<SwaapApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _themeMode == ThemeMode.dark ? Brightness.light : Brightness.dark,
    ));
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? SwaapColors.dark : SwaapColors.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
      ).copyWith(surface: colors.bg, onSurface: colors.textPrimary),
      scaffoldBackgroundColor: colors.bg,
      extensions: [colors],
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SWAAP',
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
    themeMode: _themeMode,
    home: MainPage(
      isDark: _themeMode == ThemeMode.dark,
      onToggleTheme: _toggleTheme,
    ),
  );
}
