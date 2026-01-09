import 'package:flutter/material.dart';
import '../services/authentication_handler.dart';
import '../utils/theme_config.dart';
import 'home_page.dart';

/// 닉네임 설정 화면 (구글 로그인 후 신규 사용자)
class NicknameSetupPage extends StatefulWidget {
  const NicknameSetupPage({super.key});

  @override
  State<NicknameSetupPage> createState() => _NicknameSetupPageState();
}

class _NicknameSetupPageState extends State<NicknameSetupPage> {
  final UserAuthenticationService _authService = UserAuthenticationService();
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  /// 닉네임 설정 처리
  Future<void> _handleNicknameSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Firebase Auth에 닉네임 설정
        await user.updateDisplayName(_nicknameController.text.trim());
        await user.reload();
        
        // Firestore에 닉네임 저장
        await _authService.updateUserNickname(_nicknameController.text.trim());
        
        if (mounted) {
          // 홈 화면으로 이동
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('닉네임 설정'),
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
                    '닉네임을 설정해주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 부제목
                  const Text(
                    '다른 사용자에게 표시될 이름입니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

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

                  // 닉네임 입력 필드
                  TextFormField(
                    controller: _nicknameController,
                    enabled: !_isLoading,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: '닉네임 *',
                      hintText: '닉네임을 입력하세요',
                      prefixIcon: Icon(Icons.person),
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // 닉네임 설정 버튼
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleNicknameSetup,
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
                            '완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
