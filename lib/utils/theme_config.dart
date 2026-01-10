import 'package:flutter/material.dart';

class AppColors {
  // Primary 색상 - 녹색 계열
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color lightGreen = Color(0xFFC8E6C9);
  
  // Accent 색상 - 연한 녹색 계열
  static const Color accentLightGreen = Color(0xFF81C784);
  
  // Background 색상
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  
  // Text 색상
  static const Color textDark = Color(0xFF212121);
  static const Color textGrey = Color(0xFF757575);
  static const Color textSecondary = Color(0xFF757575);
  
  // 추가 유틸리티 색상
  static const Color divider = Color(0xFFBDBDBD);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  
  // Primary 색상 getter
  static Color get primary => primaryGreen;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreen,
        onPrimary: Colors.white,
        surface: AppColors.backgroundWhite,
        onSurface: AppColors.textDark,
        secondary: AppColors.lightGreen,
      ),
      fontFamily: 'Paperlogy',
      scaffoldBackgroundColor: AppColors.backgroundWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundWhite,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Paperlogy',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'Paperlogy',
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textGrey),
      ),
    );
  }

  static ThemeData get darkTheme {
    return lightTheme; 
  }
}
