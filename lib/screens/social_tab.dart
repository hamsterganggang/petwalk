import 'package:flutter/material.dart';
import 'package:petwalk/screens/social/user_search_page.dart';

/// 소셜 탭은 이제 UserSearchPage를 래핑하여 보여줍니다.
class SocialTab extends StatelessWidget {
  const SocialTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserSearchPage();
  }
}
