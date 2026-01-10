import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/profile_state_manager.dart';
import '../providers/user_auth_state.dart';
import '../models/user_profile.dart';
import '../utils/theme_config.dart';
import '../services/google_signin_handler.dart';
import '../services/block_service.dart';
import '../services/follow_service.dart';
import '../screens/edit_profile_page.dart';
import '../screens/social/blocked_users_list.dart';
import '../screens/followers_page.dart';
import '../screens/following_page.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final BlockService _blockService = BlockService();
  final FollowService _followService = FollowService();
  int? _filteredFollowingCount;
  int? _filteredFollowersCount;
  bool _isCalculatingCounts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
      
      // BlockService 초기화
      await _blockService.initialize();
      
      // 프로필 데이터 로드
      await profileManager.loadProfileData();
      
      // 필터링된 개수 계산
      if (mounted) {
        setState(() {
          _isCalculatingCounts = true;
        });
      }
      await _updateFilteredCounts(profileManager.profile?.uid);
      if (mounted) {
        setState(() {
          _isCalculatingCounts = false;
        });
      }
    });
  }

  Future<void> _updateFilteredCounts(String? userId) async {
    if (userId == null) {
      setState(() {
        _filteredFollowingCount = null;
        _filteredFollowersCount = null;
      });
      return;
    }

    try {
      await _blockService.initialize();
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
    } catch (e) {
      print('필터링된 팔로잉/팔로워 수 계산 오류: $e');
    }
  }

  Future<void> _requestLocationPermission(ProfileStateManager profileManager) async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        await profileManager.updateLocationEnabled(true);
      } else if (status.isDenied) {
        _showPermissionDeniedDialog();
      } else if (status.isPermanentlyDenied) {
        _showPermissionPermanentlyDeniedDialog();
      }
    } catch (e) {
      print('권한 요청 오류: $e');
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text('위치 기능을 사용하려면 위치 권한이 필요합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () { Navigator.pop(context); openAppSettings(); }, child: const Text('설정')),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text('설정 앱에서 위치 권한을 수동으로 허용해주세요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(onPressed: () { Navigator.pop(context); openAppSettings(); }, child: const Text('설정')),
        ],
      ),
    );
  }

  Future<void> _toggleLocationPermission(ProfileStateManager profileManager, bool currentStatus) async {
    if (profileManager.isUpdating) return;
    if (!currentStatus) {
      await _requestLocationPermission(profileManager);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('위치 권한 비활성화'),
          content: const Text('위치 권한을 비활성화하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('비활성화')),
          ],
        ),
      );
      if (confirmed == true) {
        await profileManager.updateLocationEnabled(false);
      }
    }
  }

  void _showFollowersList(BuildContext context, ProfileStateManager profileManager) {
    if (profileManager.profile == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => FollowersPage(userId: profileManager.profile!.uid)));
  }

  void _showFollowingList(BuildContext context, ProfileStateManager profileManager) {
    if (profileManager.profile == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => FollowingPage(userId: profileManager.profile!.uid)));
  }

  Widget _buildFollowerInfo(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileStateManager, UserAuthState>(
      builder: (context, profileManager, authState, child) {
        final profile = profileManager.profile;
        final isLoading = profileManager.isLoading || authState.isLoading || _isCalculatingCounts;

        if (isLoading || profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await profileManager.refresh();
            await _updateFilteredCounts(profile.uid);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.divider,
                  backgroundImage: (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                      ? NetworkImage(profile.photoUrl!)
                      : null,
                  child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 60, color: AppColors.textSecondary)
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  profile.nickname,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.bio.isNotEmpty ? profile.bio : '한 줄 소개가 없습니다.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _showFollowersList(context, profileManager),
                      child: _buildFollowerInfo('팔로워', _filteredFollowersCount ?? profile.followers),
                    ),
                    const SizedBox(width: 40),
                    GestureDetector(
                      onTap: () => _showFollowingList(context, profileManager),
                      child: _buildFollowerInfo('팔로잉', _filteredFollowingCount ?? profile.following),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: profileManager.isLoading ? null : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditProfilePage(profile: profile, profileManager: profileManager)),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('프로필 수정'),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('위치 권한'),
                        subtitle: Text(profile.locationEnabled ? '활성화됨' : '비활성화됨'),
                        trailing: Switch(
                          value: profile.locationEnabled,
                          onChanged: (value) => _toggleLocationPermission(profileManager, profile.locationEnabled),
                        ),
                      ),
                      const Divider(height: 1),
                      // 알림 설정 ListTile 추가
                      ListTile(
                        leading: const Icon(Icons.notifications),
                        title: const Text('알림 설정'),
                        subtitle: Text(profile.notificationsEnabled ? '활성화됨' : '비활성화됨'),
                        trailing: Switch(
                          value: profile.notificationsEnabled,
                          onChanged: profileManager.isUpdating 
                            ? null 
                            : (value) => profileManager.updateNotificationsEnabled(value),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.block),
                        title: const Text('차단된 사용자'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const BlockedUsersList()));
                          if (result == true) await _updateFilteredCounts(profile.uid);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppColors.error),
                        title: const Text('로그아웃', style: TextStyle(color: AppColors.error)),
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
