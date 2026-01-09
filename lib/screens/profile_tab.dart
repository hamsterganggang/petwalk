import 'package:flutter/material.dart';
import '../utils/theme_config.dart';
import 'profile_view.dart';

/// 사용자 탭 화면
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자'),
        automaticallyImplyLeading: false,
      ),
      body: const ProfileView(),
    );
  }
}
