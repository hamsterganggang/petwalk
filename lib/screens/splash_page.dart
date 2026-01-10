import 'package:flutter/material.dart';
import '../providers/user_auth_state.dart';
import '../utils/theme_config.dart';
import 'signin_page.dart';
import 'home_page.dart';

/// 스플래시/로딩 화면 (새로운 애니메이션 적용)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  final UserAuthState _authState = UserAuthState();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // 애니메이션 설정
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 인증 상태 확인 후 화면 이동
  Future<void> _checkAuthAndNavigate() async {
    // 최소 2.5초 동안 로딩 화면을 보여줌 (애니메이션 감상용)
    final startTime = DateTime.now();
    
    // 인증 상태 확인
    await _authState.checkAuthStatus();

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime);
    final remaining = const Duration(milliseconds: 2500) - elapsed;

    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    // 인증 상태에 따라 화면 이동
    if (_authState.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryGreen,
              AppColors.accentLightGreen,
            ],
          ),
        ),
        child: Stack(
          children: [
            // 배경 장식 (발자국 패턴)
            Positioned(
              top: 100,
              left: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.pets, size: 150, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 150,
              right: -30,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.pets, size: 200, color: Colors.white),
              ),
            ),
            
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 맥동하는 발바닥 로고
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.pets,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  
                  // 앱 타이틀
                  const Text(
                    'PetWalk',
                    style: TextStyle(
                      fontSize: 48,
                      fontFamily: 'Paperlogy',
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 4),
                          blurRadius: 10,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '함께 걷는 즐거움',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                  
                  // 세련된 로딩 바
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
