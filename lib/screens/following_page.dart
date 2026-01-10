import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/profile_state_manager.dart';
import '../services/follow_service.dart';
import '../utils/theme_config.dart';

/// 팔로잉 목록 화면 (인스타그램 스타일)
class FollowingPage extends StatefulWidget {
  final String userId;

  const FollowingPage({
    super.key,
    required this.userId,
  });

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  late Future<List<UserProfile>> _followingFuture;
  final FollowService _followService = FollowService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    setState(() {
      _followingFuture = _followService.getFollowing(widget.userId);
    });
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
      
      await _loadFollowing();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        title: Text(
          '팔로잉',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textDark),
      ),
      body: _buildFollowingList(),
    );
  }

  Widget _buildFollowingList() {
    return RefreshIndicator(
      onRefresh: _loadFollowing,
      color: AppColors.textDark,
      backgroundColor: Colors.grey[100],
      child: FutureBuilder<List<UserProfile>>(
        future: _followingFuture,
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
                  const Text('팔로잉 목록을 불러올 수 없습니다.', style: TextStyle(color: AppColors.textDark)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFollowing,
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

          final following = snapshot.data ?? [];

          if (following.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add, size: 64, color: AppColors.textDark),
                  SizedBox(height: 16),
                  Text('팔로잉하는 사용자가 없습니다.', style: TextStyle(color: AppColors.textDark, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: following.length,
            itemBuilder: (context, index) {
              final followingUser = following[index];
              return _buildUserTile(followingUser);
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
                trailing: ElevatedButton(
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
              ),
            );
          },
        );
      },
    );
  }
}
