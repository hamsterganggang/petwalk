import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/google_signin_handler.dart';
import '../services/authentication_handler.dart';
import '../utils/theme_config.dart';
import '../utils/auth_helpers.dart';
import '../widgets/auth/nickname_setup_dialog.dart';
import '../widgets/auth/error_message_widget.dart';
import '../widgets/auth/google_signin_button.dart';
import '../widgets/auth/auth_form_fields.dart';
import 'signup_page.dart';
import 'home_page.dart';

/// 로그인 화면 (비밀번호 찾기 기능 포함)
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final GoogleSignInHandler _googleSignInHandler = GoogleSignInHandler();
  final UserAuthenticationService _authService = UserAuthenticationService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  StreamSubscription<User?>? _authStateSubscription;
  bool _isSettingNickname = false;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = _authService.authStateChanges.listen(
      (User? user) async {
        if (user != null && mounted && !_isSettingNickname) {
          final hasNickname = await _authService.hasNickname();
          if (hasNickname && mounted) {
            if (!_isSettingNickname) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            }
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final hasNickname = await _authService.hasNickname();
      if (mounted) {
        if (!hasNickname) {
          setState(() => _isSettingNickname = true);
          await _showNicknameDialog();
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = cleanErrorMessage(e); _isLoading = false; _isSettingNickname = false; });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; _isSettingNickname = true; });
    try {
      final isNew = await _googleSignInHandler.signInWithGoogle();
      final hasNickname = await _authService.hasNickname();
      if (mounted && (isNew || !hasNickname)) {
        await _showNicknameDialog();
      } else if (mounted) {
        setState(() { _isLoading = false; _isSettingNickname = false; });
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = cleanErrorMessage(e); _isLoading = false; _isSettingNickname = false; });
      }
    }
  }

  Future<void> _showNicknameDialog() async {
    await showNicknameSetupDialog(
      context: context,
      authService: _authService,
      onComplete: () {
        if (mounted) {
          setState(() { _isSettingNickname = false; _isLoading = false; });
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
        }
      },
    );
  }

  /// 비밀번호 찾기 (이메일 발송)
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar('비밀번호를 재설정할 이메일 주소를 입력해주세요.');
      return;
    }

    // 발송 전 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비밀번호 찾기'),
        content: Text('$email 주소로 비밀번호 재설정 이메일을 보내시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('보내기')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('비밀번호 재설정 링크가 이메일로 발송되었습니다. 메일함을 확인해주세요.'),
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar(cleanErrorMessage(e));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange[800]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
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
                  const Icon(Icons.pets, size: 80, color: AppColors.primaryGreen),
                  const SizedBox(height: 24),
                  const Text('로그인', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 48),
                  if (_errorMessage != null) ErrorMessageWidget(message: _errorMessage!),
                  EmailFormField(controller: _emailController, enabled: !_isLoading),
                  const SizedBox(height: 16),
                  PasswordFormField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: _obscurePassword,
                    onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      child: const Text('비밀번호를 잊으셨나요?', style: TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailSignIn,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  const DividerWithText(),
                  const SizedBox(height: 16),
                  GoogleSignInButton(onPressed: _handleGoogleSignIn, isLoading: _isLoading),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('계정이 없으신가요? ', style: TextStyle(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpPage())),
                        child: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
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
