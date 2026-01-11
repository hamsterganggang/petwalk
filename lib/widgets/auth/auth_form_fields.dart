import 'package:flutter/material.dart';

/// 이메일 입력 필드
class EmailFormField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?)? validator;

  const EmailFormField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      enabled: enabled,
      decoration: const InputDecoration(
        labelText: '이메일 *',
        hintText: 'example@email.com',
        prefixIcon: Icon(Icons.email),
      ),
      validator: validator ?? (value) {
        if (value == null || value.trim().isEmpty) {
          return '이메일을 입력해주세요.';
        }
        if (!value.contains('@')) {
          return '올바른 이메일 형식이 아닙니다.';
        }
        return null;
      },
    );
  }
}

/// 비밀번호 입력 필드
class PasswordFormField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;
  final String? labelText;
  final String? hintText;

  const PasswordFormField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.obscureText = true,
    this.onToggleVisibility,
    this.validator,
    this.labelText,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText ?? '비밀번호 *',
        hintText: hintText ?? '비밀번호를 입력하세요',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: onToggleVisibility != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
      ),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return '비밀번호를 입력해주세요.';
        }
        if (value.length < 6) {
          return '비밀번호는 6자 이상이어야 합니다.';
        }
        return null;
      },
    );
  }
}

/// 비밀번호 확인 입력 필드
class ConfirmPasswordFormField extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController passwordController;
  final bool enabled;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;

  const ConfirmPasswordFormField({
    super.key,
    required this.controller,
    required this.passwordController,
    this.enabled = true,
    this.obscureText = true,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: '비밀번호 확인 *',
        hintText: '비밀번호를 다시 입력하세요',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: onToggleVisibility != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '비밀번호 확인을 입력해주세요.';
        }
        if (value != passwordController.text) {
          return '비밀번호가 일치하지 않습니다.';
        }
        return null;
      },
    );
  }
}

/// 구분선 위젯
class DividerWithText extends StatelessWidget {
  final String text;

  const DividerWithText({
    super.key,
    this.text = '또는',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }
}
