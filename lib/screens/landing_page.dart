import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/theme_config.dart';
import '../widgets/auth/google_signin_button.dart';
import '../services/google_signin_handler.dart';
import '../services/authentication_handler.dart';
import '../widgets/auth/nickname_setup_dialog.dart';
import 'signin_page.dart';
import 'signup_page.dart';
import 'home_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final GoogleSignInHandler _googleSignInHandler = GoogleSignInHandler();
  final UserAuthenticationService _authService = UserAuthenticationService();
  bool _isLoading = false;

  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final ScrollController _scrollController3 = ScrollController();
  Timer? _timer;

  // 가장 안정적이고 빠른 로딩을 보장하는 고화질 강아지 사진 12선
  final List<String> _dogImages = [
    'https://images.unsplash.com/photo-1517849845537-4d257902454a?w=400&q=75',
    'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=400&q=75',
    'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=400&q=75',
    'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400&q=75',
    'https://images.unsplash.com/photo-1530281700549-e82e7bf110d6?w=400&q=75',
    'https://images.unsplash.com/photo-1444212477490-ca407925329e?w=400&q=75',
    'https://images.unsplash.com/photo-1598133894008-61f7fdb8cc3a?w=400&q=75',
    'https://images.unsplash.com/photo-1552053831-71594a27632d?w=400&q=75',
    'https://images.unsplash.com/photo-1518717758536-85ae29035b6d?w=400&q=75',
    'https://images.unsplash.com/photo-1503256207526-0df5d6342a03?w=400&q=75',
    'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?w=400&q=75',
    'https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=400&q=75',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController1.dispose();
    _scrollController2.dispose();
    _scrollController3.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      _scroll(_scrollController1, 0.8);
      _scroll(_scrollController2, 1.2);
      _scroll(_scrollController3, 0.6);
    });
  }

  void _scroll(ScrollController controller, double speed) {
    if (controller.hasClients) {
      final max = controller.position.maxScrollExtent;
      if (controller.offset >= max * 0.9) {
        controller.jumpTo(max * 0.1);
      } else {
        controller.jumpTo(controller.offset + speed);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final isNew = await _googleSignInHandler.signInWithGoogle();
      final hasNickname = await _authService.hasNickname();
      if (mounted) {
        if (isNew || !hasNickname) {
          await _showNicknameDialog();
        } else {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
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
          Row(
            children: [
              Expanded(child: _buildScrollingColumn(_scrollController1, _dogImages)),
              Expanded(child: _buildScrollingColumn(_scrollController2, _dogImages.reversed.toList())),
              Expanded(child: _buildScrollingColumn(_scrollController3, [_dogImages[5], ..._dogImages])),
            ],
          ),
          // 그라데이션 레이어
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent, Colors.black.withOpacity(0.8), Colors.black],
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
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.4), blurRadius: 25, spreadRadius: 5)]),
                      child: const Icon(Icons.pets, size: 40, color: AppColors.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('내 소중한 반려동물과\n함께하는 특별한 산책,\nPetWalk에서 시작하세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.3, letterSpacing: -0.5)),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpPage())),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 8),
                    child: const Text('가입하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  GoogleSignInButton(onPressed: _isLoading ? null : _handleGoogleSignIn, isLoading: _isLoading, isDark: true),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInPage())),
                    child: RichText(text: const TextSpan(text: '이미 계정이 있으신가요? ', style: TextStyle(color: Colors.white70, fontSize: 14), children: [TextSpan(text: '로그인하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))])),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
        ],
      ),
    );
  }

  Widget _buildScrollingColumn(ScrollController controller, List<String> images) {
    return ListView.builder(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      cacheExtent: 1000, // 핵심: 화면 밖의 이미지도 미리 로드하여 회색 칸 방지
      itemCount: 100, // 적절한 개수로 반복
      itemBuilder: (context, index) {
        final imageUrl = images[index % images.length];
        return Container(
          height: 220,
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[900], // 아주 어두운 색으로 기저 배경 설정
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FadeInImage.assetNetwork( // 페이드 효과로 부드럽게 로딩
              placeholder: 'assets/images/app_icon.png', // 앱 아이콘이 있으면 사용, 없으면 투명 이미지 처리
              image: imageUrl,
              fit: BoxFit.cover,
              imageErrorBuilder: (context, error, stackTrace) => Container(color: Colors.black26),
              placeholderErrorBuilder: (context, error, stackTrace) => Container(color: Colors.black26),
            ),
          ),
        );
      },
    );
  }
}
