import 'package:flutter/material.dart';
import 'package:petwalk/screens/social/user_search_page.dart';
import 'package:petwalk/screens/feed/public_feed_view.dart';
import 'package:petwalk/screens/map/nearby_users_map.dart';

/// 소셜 탭: 피드, 탐색, 검색을 탭으로 분리하여 보여줍니다.
class SocialTab extends StatefulWidget {
  const SocialTab({super.key});

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('소셜'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '피드', icon: Icon(Icons.feed)),
            Tab(text: '탐색', icon: Icon(Icons.explore)),
            Tab(text: '검색', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PublicFeedView(),
          NearbyUsersMap(),
          UserSearchPage(),
        ],
      ),
    );
  }
}
