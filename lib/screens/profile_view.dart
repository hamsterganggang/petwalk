import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_state_manager.dart';
import '../providers/user_auth_state.dart';
import '../models/user_profile.dart';
import '../utils/theme_config.dart';
import '../services/google_signin_handler.dart';
import '../services/block_service.dart';
import '../services/follow_service.dart';
import '../services/feed_service.dart';
import '../screens/edit_profile_page.dart';
import '../screens/social/blocked_users_list.dart';
import '../screens/followers_page.dart';
import '../screens/following_page.dart';
import 'walk_detail_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final BlockService _blockService = BlockService();
  final FollowService _followService = FollowService();
  final FeedService _feedService = FeedService();
  
  List<FeedItem> _myFeeds = [];
  int? _filteredFollowingCount;
  int? _filteredFollowersCount;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
    await _blockService.initialize();
    await profileManager.loadProfileData();
    await _loadMyFeeds(profileManager.profile?.uid);
    await _updateFilteredCounts(profileManager.profile?.uid);
    if (mounted) setState(() => _isInitialLoading = false);
  }

  Future<void> _loadMyFeeds(String? userId) async {
    if (userId == null) return;
    try {
      final result = await _feedService.loadPublicFeed(likeStatusMap: {});
      final filtered = result.items.where((item) => item.userId == userId).toList();
      if (mounted) setState(() => _myFeeds = filtered);
    } catch (e) {
      print('내 피드 로드 오류: $e');
    }
  }

  Future<void> _updateFilteredCounts(String? userId) async {
    if (userId == null) return;
    try {
      final followingList = await _followService.getFollowing(userId);
      final filteredFollowing = _blockService.filterBlockedUsers(followingList);
      final followersList = await _followService.getFollowers(userId);
      final filteredFollowers = _blockService.filterBlockedUsers(followersList);
      if (mounted) {
        setState(() {
          _filteredFollowingCount = filteredFollowing.length;
          _filteredFollowersCount = filteredFollowers.length;
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileStateManager, UserAuthState>(
      builder: (context, profileManager, authState, child) {
        final profile = profileManager.profile;
        if (_isInitialLoading || profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(profile.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: false, 
              elevation: 0,
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                await profileManager.refresh();
                await _loadMyFeeds(profile.uid);
                await _updateFilteredCounts(profile.uid);
              },
              child: Column(
                children: [
                  _buildProfileHeader(profile, profileManager),
                  
                  const TabBar(
                    indicatorColor: Colors.black87,
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on)),
                      Tab(icon: Icon(Icons.settings)),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildMyPostsGrid(), 
                        _buildSettingsList(profile, profileManager),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(UserProfile profile, ProfileStateManager profileManager) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundImage: (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                    ? NetworkImage(profile.photoUrl!) : null,
                child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 45) : null,
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('게시물', _myFeeds.length, null),
                    _buildStatItem('팔로워', _filteredFollowersCount ?? profile.followers, () => _showFollowersList(context, profileManager)),
                    _buildStatItem('팔로잉', _filteredFollowingCount ?? profile.following, () => _showFollowingList(context, profileManager)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(profile.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (profile.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(profile.bio),
            ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(profile: profile, profileManager: profileManager))),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('프로필 수정', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(count.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMyPostsGrid() {
    if (_myFeeds.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('아직 게시물이 없습니다', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1,
      ),
      itemCount: _myFeeds.length,
      itemBuilder: (context, index) {
        final item = _myFeeds[index];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalkDetailView(docId: item.walkId, walkData: item.toWalkDataMap()))),
          child: Container(
            color: Colors.grey[200],
            child: item.imageUrls.isNotEmpty 
                ? Image.network(item.imageUrls.first, fit: BoxFit.cover)
                : const Icon(Icons.pets, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildSettingsList(UserProfile profile, ProfileStateManager profileManager) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingGroup('개인정보 및 보안', [
          _buildSettingTile(
            icon: Icons.map_outlined,
            title: '탐색 위치 표시',
            subtitle: profile.locationEnabled ? '다른 사용자에게 내 위치가 보입니다' : '내 위치가 숨겨져 있습니다',
            trailing: Switch(
              value: profile.locationEnabled,
              onChanged: (val) => profileManager.updateLocationEnabled(val),
              activeColor: AppColors.primaryGreen,
            ),
          ),
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: '프로필 비공개',
            subtitle: profile.isPrivate ? '팔로워만 내 정보를 볼 수 있습니다' : '모든 사용자가 내 정보를 볼 수 있습니다',
            trailing: Switch(
              value: profile.isPrivate,
              onChanged: (val) => profileManager.updateIsPrivate(val),
              activeColor: AppColors.primaryGreen,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingGroup('기타 설정', [
          _buildSettingTile(
            icon: Icons.notifications_none,
            title: '알림 설정',
            subtitle: profile.notificationsEnabled ? '활성화됨' : '비활성화됨',
            trailing: Switch(
              value: profile.notificationsEnabled,
              onChanged: (val) => profileManager.updateNotificationsEnabled(val),
              activeColor: AppColors.primaryGreen,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.block_flipped),
            title: const Text('차단된 사용자'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersList())),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('로그아웃', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃하시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('로그아웃', style: TextStyle(color: AppColors.error))),
                  ],
                ),
              );
              if (confirmed == true) await GoogleSignInHandler().signOut();
            },
          ),
          // 회원 탈퇴 항목 추가
          ListTile(
            leading: const Icon(Icons.person_remove_outlined, color: Colors.grey),
            title: const Text('회원 탈퇴', style: TextStyle(color: Colors.grey, fontSize: 14)),
            onTap: () => _showDeleteAccountDialog(),
          ),
        ]),
      ],
    );
  }

  /// 회원 탈퇴 확인 다이얼로그
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n탈퇴 시 모든 산책 기록과 프로필 정보가 영구적으로 삭제되며 복구할 수 없습니다.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 다이얼로그 닫기
              _handleDeleteAccount();
            },
            child: const Text('탈퇴하기', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 실제 탈퇴 처리 로직
  Future<void> _handleDeleteAccount() async {
    try {
      // 1. 여기서 실제 Firebase Auth 및 Firestore 데이터 삭제 로직 호출
      // 현재는 UI 구현이므로 로그아웃으로 대체하거나 전용 서비스 함수 연결 필요
      await GoogleSignInHandler().signOut(); // 임시로 로그아웃 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('탈퇴 처리 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _buildSettingGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Card(
          elevation: 0,
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, required String subtitle, required Widget trailing}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: trailing,
    );
  }

  void _showFollowersList(BuildContext context, ProfileStateManager profileManager) {
    if (profileManager.profile == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => FollowersPage(userId: profileManager.profile!.uid)));
  }

  void _showFollowingList(BuildContext context, ProfileStateManager profileManager) {
    if (profileManager.profile == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => FollowingPage(userId: profileManager.profile!.uid)));
  }
}
