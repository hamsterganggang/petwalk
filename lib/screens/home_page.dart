import 'package:flutter/material.dart';
import '../providers/user_auth_state.dart';
import '../services/google_signin_handler.dart';
import '../utils/theme_config.dart';
import 'signin_page.dart';
import 'home_tab.dart';
import 'pets_tab.dart';
import 'walks_tab.dart';
import 'social_tab.dart';
import 'profile_tab.dart';

/// 메인 네비게이션 화면 (로그인 후 메인 화면)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UserAuthState _authState = UserAuthState();
  final GoogleSignInHandler _googleSignInHandler = GoogleSignInHandler();
  
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    // HomeTab에 탭 변경 콜백 전달
    _tabs = [
      HomeTab(onTabChange: changeTab),
      const PetsTab(),
      const WalksTab(),
      const SocialTab(),
      const ProfileTab(),
    ];
    // 인증 상태 리스너 추가
    _authState.addListener(_onAuthStateChanged);
  }

  /// 탭 인덱스 변경 (외부에서 호출 가능)
  void changeTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  void dispose() {
    _authState.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  /// 인증 상태 변경 시 호출
  void _onAuthStateChanged() {
    if (!_authState.isAuthenticated) {
      // 로그아웃된 경우 로그인 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
    }
  }

  /// 로그아웃 처리
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _googleSignInHandler.signOut();
        // 로그아웃 성공 시 자동으로 로그인 화면으로 이동 (_onAuthStateChanged에서 처리)
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그아웃 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 탭 변경 처리
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: '반려동물',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk),
            label: '산책',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '소셜',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '사용자',
          ),
        ],
      ),
    );
  }
}
