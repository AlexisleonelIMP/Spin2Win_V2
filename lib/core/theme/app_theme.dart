import 'package:flutter/material.dart';

// --- DEFINICIÓN DEL TEMA CLARO ---
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.amber,
  fontFamily: 'Poppins',
  scaffoldBackgroundColor: const Color(0xFFFDFBF3),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
    bodyMedium: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
  ),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.amber,
    brightness: Brightness.light,
  ).copyWith(
    secondary: const Color(0xFFF9693B),
    surface: const Color(0xFFFFFFFF),
    onSurface: Colors.black87,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFFF8E1),
    elevation: 1,
    titleTextStyle: TextStyle(
      fontFamily: 'Poppins',
      color: Colors.black87,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: Colors.black87),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: UnderlineInputBorder(),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.amber),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFF9693B),
    ),
  ),
);

// --- DEFINICIÓN DEL TEMA OSCURO ---
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.amber,
  fontFamily: 'Poppins',
  scaffoldBackgroundColor: const Color(0xFF121212),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
    bodyMedium:
    TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
  ),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.amber,
    brightness: Brightness.dark,
  ).copyWith(
    secondary: const Color(0xFFF9693B),
    surface: const Color(0xFF1E1E1E),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: const UnderlineInputBorder(),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.amber.shade400),
    ),
    labelStyle: TextStyle(color: Colors.grey.shade400),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Colors.amber.shade400,
    ),
  ),
);