import 'package:flutter/material.dart';

/// 앱 전체에 적용될 테마 색상 상수
class AppColors {
  // Primary 색상 - 녹색 계열
  static const Color primaryGreen = Color(0xFF4CAF50);
  
  // Background 색상
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  
  // Text 색상
  static const Color textDark = Color(0xFF212121);
  
  // Accent 색상 - 연한 녹색 계열
  static const Color accentLightGreen = Color(0xFF81C784);
  
  // 추가 유틸리티 색상
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
}

/// 앱 테마 설정 클래스
class AppTheme {
  /// Light Theme 설정
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryGreen,
        secondary: AppColors.accentLightGreen,
        surface: AppColors.backgroundWhite,
        background: AppColors.backgroundWhite,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textDark,
        onBackground: AppColors.textDark,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.backgroundWhite,
      textTheme: _textTheme,
      appBarTheme: _appBarTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      dividerTheme: _dividerTheme,
    );
  }

  /// Dark Theme 설정
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryGreen,
        secondary: AppColors.accentLightGreen,
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: _textThemeDark,
      appBarTheme: _appBarThemeDark,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      inputDecorationTheme: _inputDecorationThemeDark,
      dividerTheme: _dividerThemeDark,
    );
  }

  /// 텍스트 테마 (Light)
  static TextTheme get _textTheme {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        letterSpacing: -0.25,
        fontFamily: 'Paperlogy',
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        letterSpacing: 0,
        fontFamily: 'Paperlogy',
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        letterSpacing: 0,
        fontFamily: 'Paperlogy',
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        letterSpacing: 0,
        fontFamily: 'Paperlogy',
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        letterSpacing: 0,
        fontFamily: 'Paperlogy',
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        letterSpacing: 0,
        fontFamily: 'Paperlogy',
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        letterSpacing: 0,
        fontFamily: 'Paperlogy',
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        letterSpacing: 0.15,
        fontFamily: 'Paperlogy',
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        letterSpacing: 0.1,
        fontFamily: 'Paperlogy',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        letterSpacing: 0.5,
        fontFamily: 'Paperlogy',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
        letterSpacing: 0.25,
        fontFamily: 'Paperlogy',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
        fontFamily: 'Paperlogy',
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        letterSpacing: 0.1,
        fontFamily: 'Paperlogy',
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        letterSpacing: 0.5,
        fontFamily: 'Paperlogy',
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        letterSpacing: 0.5,
        fontFamily: 'Paperlogy',
      ),
    );
  }

  /// 텍스트 테마 (Dark)
  static TextTheme get _textThemeDark {
    return _textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );
  }

  /// AppBar 테마 (Light)
  static AppBarTheme get _appBarTheme {
    return AppBarTheme(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        letterSpacing: 0.15,
        fontFamily: 'Paperlogy',
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
    );
  }

  /// AppBar 테마 (Dark)
  static AppBarTheme get _appBarThemeDark {
    return _appBarTheme.copyWith(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
    );
  }

  /// ElevatedButton 테마
  static ElevatedButtonThemeData get _elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFamily: 'Paperlogy',
        ),
      ),
    );
  }

  /// OutlinedButton 테마
  static OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: const BorderSide(color: AppColors.primaryGreen, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFamily: 'Paperlogy',
        ),
      ),
    );
  }

  /// TextButton 테마
  static TextButtonThemeData get _textButtonTheme {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFamily: 'Paperlogy',
        ),
      ),
    );
  }

  /// InputDecoration 테마 (Light)
  static InputDecorationTheme get _inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontFamily: 'Paperlogy',
      ),
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontSize: 14,
        fontFamily: 'Paperlogy',
      ),
    );
  }

  /// InputDecoration 테마 (Dark)
  static InputDecorationTheme get _inputDecorationThemeDark {
    return InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[700]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[700]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(
        color: Colors.grey,
        fontSize: 14,
        fontFamily: 'Paperlogy',
      ),
      hintStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
        fontFamily: 'Paperlogy',
      ),
    );
  }

  /// Divider 테마 (Light)
  static DividerThemeData get _dividerTheme {
    return DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    );
  }

  /// Divider 테마 (Dark)
  static DividerThemeData get _dividerThemeDark {
    return DividerThemeData(
      color: Colors.grey[700]!,
      thickness: 1,
      space: 1,
    );
  }
}

/// 테마 설정 헬퍼 클래스
class ThemeConfiguration {
  /// 기본 테마 가져오기
  static ThemeData get defaultTheme => AppTheme.lightTheme;
  
  /// 다크 테마 가져오기
  static ThemeData get darkTheme => AppTheme.darkTheme;
}

