import 'package:flutter/material.dart';
import '../utils/theme_config.dart';
import '../widgets/auth/google_signin_button.dart';
import '../services/google_signin_handler.dart';
import '../services/authentication_handler.dart';
import '../widgets/auth/nickname_setup_dialog.dart';
import 'signin_page.dart';
import 'signup_page.dart';
import 'home_page.dart';

/// 소개 화면 (Landing Page - 정적 그리드 버전)
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final GoogleSignInHandler _googleSignInHandler = GoogleSignInHandler();
  final UserAuthenticationService _authService = UserAuthenticationService();
  bool _isLoading = false;

  // 검증된 고화질 강아지 사진 리스트
  final List<String> _dogImages = [
    'https://images.unsplash.com/photo-1517849845537-4d257902454a?w=500&q=80',
    'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=500&q=80',
    'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=500&q=80',
    'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500&q=80',
    'https://images.unsplash.com/photo-1530281700549-e82e7bf110d6?w=500&q=80',
    'https://images.unsplash.com/photo-1444212477490-ca407925329e?w=500&q=80',
    'https://images.unsplash.com/photo-1598133894008-61f7fdb8cc3a?w=500&q=80',
    'https://images.unsplash.com/photo-1552053831-71594a27632d?w=500&q=80',
    'https://images.unsplash.com/photo-1518717758536-85ae29035b6d?w=500&q=80',
    'https://images.unsplash.com/photo-1535930891776-0c2dfb7fda1a?w=500&q=80',
    'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=500&q=80',
    'https://images.unsplash.com/photo-1517423440428-a5a00ad493e8?w=500&q=80',
  ];

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final isNew = await _googleSignInHandler.signInWithGoogle();
      final hasNickname = await _authService.hasNickname();
      if (mounted) {
        if (isNew || !hasNickname) {
          await _showNicknameDialog();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showNicknameDialog() async {
    await showNicknameSetupDialog(
      context: context,
      authService: _authService,
      onComplete: () {
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 고정된 그리드 사진 배경
          _buildStaticGrid(),
          
          // 2. 그라데이션 오버레이
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),

          // 3. 콘텐츠 레이어
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pets,
                        size: 40,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    '내 소중한 반려동물과\n함께하는 특별한 산책,\nPetWalk를 시작해보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 48),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      '가입하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),

                  GoogleSignInButton(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    isLoading: _isLoading,
                    isDark: true,
                  ),
                  const SizedBox(height: 24),

                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignInPage()),
                      );
                    },
                    child: const Text(
                      '로그인하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
        ],
      ),
    );
  }

  /// 고정된 사진 그리드 생성
  Widget _buildStaticGrid() {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      physics: const NeverScrollableScrollPhysics(), // 스크롤 금지
      itemCount: 15, // 화면 상단부를 채울 정도의 개수
      itemBuilder: (context, index) {
        final imageUrl = _dogImages[index % _dogImages.length];
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.2),
                BlendMode.darken,
              ),
            ),
          ),
        );
      },
    );
  }
}
