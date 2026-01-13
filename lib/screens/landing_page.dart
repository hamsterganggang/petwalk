import 'package:flutter/material.dart';
import '../utils/theme_config.dart';
import '../widgets/auth/google_signin_button.dart';
import '../services/google_signin_handler.dart';
import '../services/authentication_handler.dart';
import '../widgets/auth/nickname_setup_dialog.dart';
import 'signin_page.dart';
import 'signup_page.dart';
import 'home_page.dart';

/// 소개 화면 (Landing Page)
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final GoogleSignInHandler _googleSignInHandler = GoogleSignInHandler();
  final UserAuthenticationService _authService = UserAuthenticationService();
  bool _isLoading = false;

  // 배경에 사용할 강아지 이미지 URL 리스트
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구글 로그인 실패: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showNicknameDialog() async {
    await showNicknameSetupDialog(
      context: context,
      authService: _authService,
      onComplete: () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 실제 강아지 사진 콜라주 배경
          _buildBackgroundCollage(),
          
          // 그라데이션 오버레이 (하단 텍스트 가독성 확보)
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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 앱 로고
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.pets,
                        size: 40,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 메인 카피
                  const Text(
                    '내 소중한 반려동물과\n함께하는 특별한 산책,\nPetWalk를 시작해보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 가입하기 버튼
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
                      elevation: 0,
                    ),
                    child: const Text(
                      '가입하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 구글로 계속하기
                  GoogleSignInButton(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    isLoading: _isLoading,
                    isDark: true,
                  ),
                  const SizedBox(height: 16),

                  // 로그인하기 링크
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
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
        ],
      ),
    );
  }

  /// 강아지 사진들로 구성된 배경 콜라주
  Widget _buildBackgroundCollage() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 12, // 화면을 채울 만큼의 개수
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        // 이미지 리스트를 순환하며 표시
        final imageUrl = _dogImages[index % _dogImages.length];
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4), // 이미지를 약간 어둡게 처리
                BlendMode.darken,
              ),
            ),
          ),
        );
      },
    );
  }
}
