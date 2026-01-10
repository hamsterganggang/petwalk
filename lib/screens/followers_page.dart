import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../providers/profile_state_manager.dart';
import '../services/follow_service.dart';
import '../services/block_service.dart';
import '../utils/theme_config.dart';

/// 팔로워 목록 화면
class FollowersPage extends StatefulWidget {
  final String userId;

  const FollowersPage({
    super.key,
    required this.userId,
  });

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  late Future<List<UserProfile>> _followersFuture;
  final FollowService _followService = FollowService();
  final BlockService _blockService = BlockService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  /// BlockService 초기화 후 팔로워 목록 로드
  Future<void> _initializeAndLoad() async {
    await _blockService.initialize();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    // BlockService 초기화 확인
    await _blockService.initialize();

    // 팔로워 목록 가져오기
    final followersList = await _followService.getFollowers(widget.userId);

    // 차단된 사용자 필터링
    final filteredList = _blockService.filterBlockedUsers(followersList);

    if (mounted) {
      setState(() {
        _followersFuture = Future.value(filteredList);
      });
    }
  }

  Future<void> _toggleFollow(UserProfile user) async {
    final profileManager = Provider.of<ProfileStateManager>(context, listen: false);

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool isFollowingUser = await profileManager.isFollowing(user.uid);

      if (isFollowingUser) {
        await profileManager.unfollowUser(user.uid);
      } else {
        await profileManager.followUser(user.uid);
      }

      await _loadFollowers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 사용자 차단 처리 (차단 시 자동 언팔로우)
  Future<void> _blockUser(UserProfile user) async {
    final profileManager = Provider.of<ProfileStateManager>(context, listen: false);

    if (_isLoading) return;

    // 차단 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 차단'),
        content: Text('${user.nickname}님을 차단하시겠습니까?\n차단하면 자동으로 언팔로우됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('차단'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 차단
      await _blockService.blockUser(user.uid);

      // 양방향 팔로우 관계 모두 취소 (내가 팔로우하는 경우 + 상대방이 나를 팔로우하는 경우)
      final followService = FollowService();
      await followService.removeAllFollowRelationships(
        (await FirebaseAuth.instance.currentUser)!.uid,
        user.uid,
      );

      // 차단 목록 새로고침
      await _blockService.refresh();

      // 팔로워 목록 새로고침
      await _loadFollowers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.nickname}님을 차단했습니다.'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('차단 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        title: Text(
          '팔로워',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textDark),
      ),
      body: _buildFollowersList(),
    );
  }

  Widget _buildFollowersList() {
    return RefreshIndicator(
      onRefresh: _loadFollowers,
      color: AppColors.textDark,
      backgroundColor: Colors.grey[100],
      child: FutureBuilder<List<UserProfile>>(
        future: _followersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.textDark),
                  const SizedBox(height: 16),
                  const Text('팔로워 목록을 불러올 수 없습니다.', style: TextStyle(color: AppColors.textDark)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFollowers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final followers = snapshot.data ?? [];

          if (followers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: AppColors.textDark),
                  const SizedBox(height: 16),
                  const Text('팔로워가 없습니다.', style: TextStyle(color: AppColors.textDark, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final follower = followers[index];
              return _buildUserTile(follower);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserTile(UserProfile user) {
    return Consumer<ProfileStateManager>(
      builder: (context, profileManager, child) {
        return FutureBuilder<bool>(
          future: profileManager.isFollowing(user.uid),
          builder: (context, followSnapshot) {
            final isFollowing = followSnapshot.data ?? false;

            return Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? const Icon(Icons.person, color: AppColors.textDark) : null,
                ),
                title: Text(
                  user.nickname,
                  style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: user.bio.isNotEmpty
                    ? Text(
                  user.bio,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _toggleFollow(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.transparent : AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        side: isFollowing ? BorderSide(color: AppColors.textGrey, width: 1) : null,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : Text(isFollowing ? '팔로잉' : '팔로우', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textGrey),
                      onSelected: (value) {
                        if (value == 'block') {
                          _blockUser(user);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: AppColors.error, size: 20),
                              SizedBox(width: 8),
                              Text('차단하기'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}