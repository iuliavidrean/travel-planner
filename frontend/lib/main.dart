import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/home_page.dart';
import 'pages/trips_page.dart';

import 'services/session_service.dart';

void main() {
  runApp(const TerraWiseApp());
}

class TerraWiseApp extends StatelessWidget {
  const TerraWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    const mintPrimary = Color(0xFF77CDBB);
    const mintSoft = Color(0xFFDDF5EF);
    const lavenderAccent = Color(0xFFDCCEF8);
    const background = Color(0xFFF7F6F2);
    const surface = Colors.white;
    const border = Color(0xFFE9E6E1);
    const darkText = Color(0xFF2E2A27);
    const secondaryText = Color(0xFF746E67);

    final baseTextTheme = GoogleFonts.interTextTheme();

    return MaterialApp(
      title: 'TerraWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: mintPrimary,
          brightness: Brightness.light,
          primary: mintPrimary,
          secondary: lavenderAccent,
          surface: surface,
        ),
        textTheme: baseTextTheme.copyWith(
          headlineLarge: GoogleFonts.playfairDisplay(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: darkText,
            height: 1.1,
          ),
          headlineMedium: GoogleFonts.playfairDisplay(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: darkText,
            height: 1.1,
          ),
          headlineSmall: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: darkText,
            height: 1.15,
          ),
          titleLarge: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: darkText,
            height: 1.15,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: secondaryText,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: secondaryText,
            height: 1.45,
          ),
          labelLarge: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: darkText,
          ),
          labelMedium: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: secondaryText,
            letterSpacing: 0.2,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: background,
          foregroundColor: darkText,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.playfairDisplay(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: darkText,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: border),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          labelStyle: GoogleFonts.inter(
            color: secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: GoogleFonts.inter(
            color: secondaryText.withValues(alpha: 0.75),
            fontSize: 14,
          ),
          prefixIconColor: secondaryText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: mintPrimary, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: mintPrimary,
            foregroundColor: darkText,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.playfairDisplay(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkText,
            side: const BorderSide(color: border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkText,
            textStyle: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: mintSoft,
          selectedColor: mintPrimary.withValues(alpha: 0.18),
          disabledColor: border,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        dividerColor: border,
      ),
      home: const AppStartPage(),
    );
  }
}

class AppStartPage extends StatelessWidget {
  const AppStartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SessionService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const HomePage();
        }

        if (snapshot.data == true) {
          return const TripsPage();
        }

        return const HomePage();
      },
    );
  }
}
