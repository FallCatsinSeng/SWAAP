import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/main_page.dart';

void main() => runApp(const SwaapApp());

class SwaapApp extends StatelessWidget {
  const SwaapApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SWAAP',
        theme: ThemeData(
          useMaterial3: true,
          textTheme: GoogleFonts.plusJakartaSansTextTheme(),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D78B7),
          ),
        ),
        home: const MainPage(),
      );
}
