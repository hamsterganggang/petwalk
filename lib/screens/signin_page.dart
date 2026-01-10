import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/google_signin_handler.dart';
import '../services/authentication_handler.dart';
import '../utils/theme_config.dart';
import 'signup_page.dart';
import 'home_page.dart';

/// 로그인 화면
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
  bool _isSettingNickname = false; // 닉네임 설정 중인지 여부

  @override
  void initState() {
    super.initState();
    // 인증 상태 변경 리스너 등록
    _authStateSubscription = _authService.authStateChanges.listen(
      (User? user) async {
        // 닉네임 설정 중이면 자동 이동하지 않음
        if (user != null && mounted && !_isSettingNickname) {
          // 닉네임이 설정되어 있는지 확인
          final hasNickname = await _authService.hasNickname();
          if (hasNickname && mounted) {
            // 닉네임이 있으면 홈 화면으로 이동 (다이얼로그가 표시되지 않은 경우에만)
            // 이미 다이얼로그가 표시되었거나 다른 화면으로 이동 중이면 무시
            if (!_isSettingNickname) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            }
          }
          // 닉네임이 없으면 닉네임 설정 다이얼로그가 표시될 때까지 대기
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

  /// 이메일/비밀번호 로그인
  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      // 로그인 성공 후 닉네임이 설정되어 있는지 확인
      final hasNickname = await _authService.hasNickname();
      
      if (mounted) {
        if (!hasNickname) {
          // 닉네임이 없으면 닉네임 설정 다이얼로그 표시
          setState(() {
            _isSettingNickname = true;
          });
          await _showNicknameDialog();
        } else {
          // 닉네임이 있으면 authStateChanges 리스너에서 자동으로 홈 화면으로 이동
          setState(() {
            _isLoading = false; // 로딩 상태 명시적으로 해제
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _isSettingNickname = false;
        });
      }
    }
  }

  /// 구글 로그인 실행
  Future<void> _handleGoogleSignIn() async {
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
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _isSettingNickname = false; // 에러 발생 시 플래그 해제
        });
      }
    }
  }

  /// 닉네임 설정 다이얼로그 표시
  Future<void> _showNicknameDialog() async {
    final nicknameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isChecking = false;
    String? duplicateError;
    bool dialogClosed = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('닉네임 설정'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '사용할 닉네임을 입력해주세요.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nicknameController,
                    autofocus: true,
                    maxLength: 20,
                    enabled: !isChecking,
                    decoration: const InputDecoration(
                      labelText: '닉네임 *',
                      hintText: '닉네임을 입력하세요',
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '닉네임을 입력해주세요.';
                      }
                      if (value.trim().length < 2) {
                        return '닉네임은 2자 이상이어야 합니다.';
                      }
                      if (value.trim().length > 20) {
                        return '닉네임은 20자 이하여야 합니다.';
                      }
                      if (duplicateError != null) {
                        return duplicateError;
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // 입력이 변경되면 중복 에러 초기화
                      if (duplicateError != null && !dialogClosed) {
                        setDialogState(() {
                          duplicateError = null;
                        });
                        formKey.currentState?.validate();
                      }
                    },
                  ),
                  if (isChecking)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isChecking ? null : () async {
                  if (formKey.currentState!.validate()) {
                    if (dialogClosed) return;
                    
                    setDialogState(() {
                      isChecking = true;
                      duplicateError = null;
                    });

                    try {
                      final nickname = nicknameController.text.trim();
                      
                      // 닉네임 중복 체크
                      final isAvailable = await _authService.checkNicknameAvailability(nickname);
                      
                      if (!isAvailable) {
                        if (dialogClosed) return;
                        setDialogState(() {
                          isChecking = false;
                          duplicateError = '이미 사용 중인 닉네임입니다.';
                        });
                        formKey.currentState?.validate();
                        return;
                      }

                      // 닉네임 저장
                      await _authService.updateUserNickname(nickname);
                      
                      // 다이얼로그 닫기
                      if (!dialogClosed && dialogContext.mounted) {
                        dialogClosed = true;
                        Navigator.of(dialogContext).pop();
                      }
                      
                      // 위젯이 여전히 마운트되어 있는지 확인 후 홈으로 이동
                      if (mounted) {
                        // 로딩 상태 해제 및 닉네임 설정 완료
                        _isSettingNickname = false;
                        _isLoading = false;
                        
                        // 홈 화면으로 이동
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const HomePage()),
                            (route) => false,
                          );
                        }
                      }
                    } catch (e) {
                      if (dialogClosed) return;
                      setDialogState(() {
                        isChecking = false;
                        duplicateError = e.toString().replaceAll('Exception: ', '');
                      });
                      formKey.currentState?.validate();
                    }
                  }
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
    
    nicknameController.dispose();
  }

  /// 비밀번호 재설정
  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일을 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('비밀번호 재설정 이메일을 전송했습니다.'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  // 앱 로고/아이콘 영역
                  const Icon(
                    Icons.pets,
                    size: 100,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 32),

                  // 앱 제목
                  const Text(
                    'PetWalk',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 부제목
                  const Text(
                    '반려동물 산책 관리 앱',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 에러 메시지 표시
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 이메일 입력 필드
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: '이메일 *',
                      hintText: 'example@email.com',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이메일을 입력해주세요.';
                      }
                      if (!value.contains('@')) {
                        return '올바른 이메일 형식이 아닙니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 입력 필드
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: '비밀번호 *',
                      hintText: '비밀번호를 입력하세요',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요.';
                      }
                      if (value.length < 6) {
                        return '비밀번호는 6자 이상이어야 합니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // 비밀번호 찾기
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      child: const Text(
                        '비밀번호를 잊으셨나요?',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 이메일 로그인 버튼
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailSignIn,
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
                            '로그인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // 구분선
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '또는',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 구글 시작하기 버튼
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: const Icon(Icons.login, size: 20),
                    label: const Text(
                      '구글로 시작하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textDark,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
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

                  // 회원가입 링크
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '계정이 없으신가요? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpPage(),
                                  ),
                                );
                              },
                        child: const Text(
                          '회원가입',
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
