import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/authentication_handler.dart';
import '../services/google_signin_handler.dart';
import '../utils/theme_config.dart';
import '../utils/auth_helpers.dart';
import '../widgets/auth/nickname_setup_dialog.dart';
import '../widgets/auth/error_message_widget.dart';
import '../widgets/auth/google_signin_button.dart';
import '../widgets/auth/auth_form_fields.dart';
import 'home_page.dart';

/// 회원가입 화면
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final UserAuthenticationService _authService = UserAuthenticationService();
  final GoogleSignInHandler _googleSignInHandler = GoogleSignInHandler();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  StreamSubscription<User?>? _authStateSubscription;
  bool _isSettingNickname = false; // 닉네임 설정 중인지 여부

  @override
  void initState() {
    super.initState();
    // 인증 상태 변경 리스너 등록
    _authStateSubscription = _authService.authStateChanges.listen(
      (User? user) {
        // 닉네임 설정 중이면 자동 이동하지 않음
        if (user != null && mounted && !_isSettingNickname) {
          // 회원가입 성공 시 홈 화면으로 이동
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// 이메일 회원가입 처리
  Future<void> _handleEmailSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSettingNickname = true; // 닉네임 설정 시작 (리스너가 실행되지 않도록)
    });

    try {
      await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      // 회원가입 성공 후 닉네임이 설정되어 있는지 확인
      final hasNickname = await _authService.hasNickname();
      
      // 닉네임이 없으면 닉네임 설정 다이얼로그 표시
      if (mounted && !hasNickname) {
        await _showNicknameDialog();
      } else if (mounted) {
        // 닉네임이 이미 있으면 홈으로 이동
        setState(() {
          _isLoading = false;
          _isSettingNickname = false;
        });
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = cleanErrorMessage(e);
          _isLoading = false;
          _isSettingNickname = false; // 에러 발생 시 플래그 해제
        });
      }
    }
  }

  /// 구글 회원가입 처리
  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSettingNickname = true; // 닉네임 설정 시작 (리스너가 실행되지 않도록)
    });

    try {
      final isNew = await _googleSignInHandler.signInWithGoogle();
      
      // 구글 로그인 성공 후 닉네임이 설정되어 있는지 확인
      final hasNickname = await _authService.hasNickname();
      
      // 신규 사용자이거나 닉네임이 없으면 닉네임 설정 다이얼로그 표시
      if (mounted && (isNew || !hasNickname)) {
        await _showNicknameDialog();
      } else if (mounted) {
        // 기존 사용자이고 닉네임이 있으면 홈으로 이동
        setState(() {
          _isLoading = false;
          _isSettingNickname = false;
        });
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = cleanErrorMessage(e);
          _isLoading = false;
          _isSettingNickname = false; // 에러 발생 시 플래그 해제
        });
      }
    }
  }

  /// 닉네임 설정 다이얼로그 표시
  Future<void> _showNicknameDialog() async {
    await showNicknameSetupDialog(
      context: context,
      authService: _authService,
      onComplete: () {
        if (mounted) {
          setState(() {
            _isSettingNickname = false;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 앱 로고
                  const Icon(
                    Icons.pets,
                    size: 80,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 32),

                  // 제목
                  const Text(
                    '회원가입',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 부제목
                  const Text(
                    'PetWalk에 오신 것을 환영합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 에러 메시지 표시
                  if (_errorMessage != null)
                    ErrorMessageWidget(message: _errorMessage!),

                  // 이메일 입력 필드
                  EmailFormField(
                    controller: _emailController,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이메일을 입력해주세요.';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return '올바른 이메일 형식이 아닙니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 입력 필드
                  PasswordFormField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: _obscurePassword,
                    hintText: '6자 이상 입력하세요',
                    onToggleVisibility: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 확인 입력 필드
                  ConfirmPasswordFormField(
                    controller: _confirmPasswordController,
                    passwordController: _passwordController,
                    enabled: !_isLoading,
                    obscureText: _obscureConfirmPassword,
                    onToggleVisibility: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  const SizedBox(height: 32),

                  // 이메일 회원가입 버튼
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailSignUp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '이메일로 회원가입',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // 구분선
                  const DividerWithText(),
                  const SizedBox(height: 16),

                  // 구글 시작하기 버튼
                  GoogleSignInButton(
                    onPressed: _handleGoogleSignUp,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),

                  // 필수 입력 안내
                  const Text(
                    '*는 필수입력 사항입니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 로그인 링크
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '이미 계정이 있으신가요? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        child: const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
