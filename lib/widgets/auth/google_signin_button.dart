import 'package:flutter/material.dart';
import '../../utils/theme_config.dart';

/// 구글 로그인 버튼 위젯 (구글 로고 포함)
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDark; // 다크 모드 스타일 지원 여부

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isDark ? Colors.transparent : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textDark,
        side: BorderSide(color: isDark ? Colors.grey : Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
            height: 20,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Google로 계속하기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
