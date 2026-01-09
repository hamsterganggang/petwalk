import 'package:flutter/material.dart';
import '../providers/user_auth_state.dart';
import '../utils/theme_config.dart';
import 'signin_page.dart';
import 'home_page.dart';

/// 스플래시/로딩 화면 (자동 로그인 체크)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final UserAuthState _authState = UserAuthState();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  /// 인증 상태 확인 후 화면 이동
  Future<void> _checkAuthAndNavigate() async {
    // 인증 상태 확인
    await _authState.checkAuthStatus();

    // 짧은 딜레이 (스플래시 화면 표시)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // 인증 상태에 따라 화면 이동
    if (_authState.isAuthenticated) {
      // 로그인된 경우 홈 화면으로
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      // 로그인되지 않은 경우 로그인 화면으로
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고
            const Icon(
              Icons.pets,
              size: 120,
              color: Colors.white,
            ),
            const SizedBox(height: 24),

            // 앱 이름
            const Text(
              'PetWalk',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // 로딩 인디케이터
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 24),

            // 로딩 텍스트
            const Text(
              '로딩 중...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
