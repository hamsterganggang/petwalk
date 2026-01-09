import 'package:flutter/material.dart';
import '../providers/user_auth_state.dart';
import '../services/google_signin_handler.dart';
import '../utils/theme_config.dart';
import 'signin_page.dart';

/// 홈 화면 (로그인 후 메인 화면)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UserAuthState _authState = UserAuthState();
  final GoogleSignInHandler _googleSignInHandler = GoogleSignInHandler();

  @override
  void initState() {
    super.initState();
    // 인증 상태 리스너 추가
    _authState.addListener(_onAuthStateChanged);
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

  @override
  Widget build(BuildContext context) {
    final user = _authState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PetWalk'),
        actions: [
          // 사용자 프로필 사진 또는 아이콘
          if (user?.photoURL != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(user!.photoURL!),
                radius: 16,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.person),
            ),
          // 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 사용자 정보 표시
            if (user?.photoURL != null)
              CircleAvatar(
                backgroundImage: NetworkImage(user!.photoURL!),
                radius: 50,
              )
            else
              const Icon(
                Icons.person,
                size: 100,
                color: AppColors.primaryGreen,
              ),
            const SizedBox(height: 24),
            Text(
              '환영합니다!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (user?.displayName != null)
              Text(
                user!.displayName!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (user?.email != null)
              Text(
                user!.email!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: 48),
            const Text(
              '반려동물 산책 관리를 시작하세요!',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
