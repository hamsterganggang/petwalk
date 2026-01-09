import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/authentication_handler.dart';

/// 인증 상태 관리 클래스
class UserAuthState extends ChangeNotifier {
  final UserAuthenticationService _authService = UserAuthenticationService();
  
  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  UserAuthState() {
    _initializeAuthListener();
  }

  /// 인증 상태 리스너 초기화
  void _initializeAuthListener() {
    _authService.authStateChanges.listen(
      (User? user) {
        _currentUser = user;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = '인증 상태 확인 중 오류가 발생했습니다.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// 인증 상태 확인
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isAuth = await _authService.checkAuthStatus();
      if (!isAuth) {
        _currentUser = null;
      }
      _isLoading = false;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '인증 상태 확인 중 오류가 발생했습니다.';
      _isLoading = false;
    }

    notifyListeners();
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
