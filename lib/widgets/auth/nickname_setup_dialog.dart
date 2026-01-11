import 'package:flutter/material.dart';
import '../../services/authentication_handler.dart';
import '../../screens/home_page.dart';

/// 닉네임 설정 다이얼로그 위젯
class NicknameSetupDialog extends StatefulWidget {
  final UserAuthenticationService authService;
  final VoidCallback? onComplete;

  const NicknameSetupDialog({
    super.key,
    required this.authService,
    this.onComplete,
  });

  @override
  State<NicknameSetupDialog> createState() => _NicknameSetupDialogState();
}

class _NicknameSetupDialogState extends State<NicknameSetupDialog> {
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isChecking = false;
  String? _duplicateError;
  bool _dialogClosed = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate() || _dialogClosed) {
      return;
    }

    setState(() {
      _isChecking = true;
      _duplicateError = null;
    });

    try {
      final nickname = _nicknameController.text.trim();
      
      // 닉네임 중복 체크
      final isAvailable = await widget.authService.checkNicknameAvailability(nickname);
      
      if (!isAvailable) {
        if (_dialogClosed) return;
        setState(() {
          _isChecking = false;
          _duplicateError = '이미 사용 중인 닉네임입니다.';
        });
        _formKey.currentState?.validate();
        return;
      }

      // 닉네임 저장
      await widget.authService.updateUserNickname(nickname);
      
      // 다이얼로그 닫기
      if (!_dialogClosed && mounted) {
        _dialogClosed = true;
        Navigator.of(context).pop();
      }
      
      // 콜백 실행 또는 홈으로 이동
      if (mounted) {
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (_dialogClosed) return;
      setState(() {
        _isChecking = false;
        _duplicateError = e.toString().replaceAll('Exception: ', '');
      });
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('닉네임 설정'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '사용할 닉네임을 입력해주세요.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nicknameController,
              autofocus: true,
              maxLength: 20,
              enabled: !_isChecking,
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
                if (_duplicateError != null) {
                  return _duplicateError;
                }
                return null;
              },
              onChanged: (value) {
                if (_duplicateError != null && !_dialogClosed) {
                  setState(() {
                    _duplicateError = null;
                  });
                  _formKey.currentState?.validate();
                }
              },
            ),
            if (_isChecking)
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
          onPressed: _isChecking ? null : _handleConfirm,
          child: const Text('확인'),
        ),
      ],
    );
  }
}

/// 닉네임 설정 다이얼로그 표시 헬퍼 함수
Future<void> showNicknameSetupDialog({
  required BuildContext context,
  required UserAuthenticationService authService,
  VoidCallback? onComplete,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => NicknameSetupDialog(
      authService: authService,
      onComplete: onComplete,
    ),
  );
}
