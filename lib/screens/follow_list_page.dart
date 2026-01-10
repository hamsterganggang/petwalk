import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_state_manager.dart';
import '../models/user_profile.dart';
import '../utils/theme_config.dart';

/// 팔로워/팔로잉 목록 화면
class FollowListPage extends StatefulWidget {
  final String title;
  final String userId;
  final bool isFollowing; // true: 팔로잉 목록, false: 팔로워 목록

  const FollowListPage({
    super.key,
    required this.title,
    required this.userId,
    required this.isFollowing,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  List<UserProfile> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
      List<UserProfile> users;
      
      if (widget.isFollowing) {
        users = await profileManager.getFollowing(widget.userId);
      } else {
        users = await profileManager.getFollowers(widget.userId);
      }
      
      setState(() {
        _users = users;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '목록을 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow(UserProfile user) async {
    final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
    
    try {
      bool isFollowingUser = await profileManager.isFollowing(user.uid);
      
      // 즉시 UI 업데이트를 위해 상태 변경
      setState(() {
        // 임시로 버튼 상태 변경 (실시간 반영)
      });
      
      if (isFollowingUser) {
        await profileManager.unfollowUser(user.uid);
      } else {
        await profileManager.followUser(user.uid);
      }
      
      // 팔로우/언팔로우 성공 후 목록 새로고침
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.isFollowing ? '팔로잉한 사용자가 없습니다.' : '팔로워가 없습니다.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.divider,
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? const Icon(Icons.person, color: AppColors.textSecondary)
                : null,
          ),
          title: Text(user.nickname),
          subtitle: user.email.isNotEmpty ? Text(user.email) : null,
          trailing: FutureBuilder<bool>(
            future: Provider.of<ProfileStateManager>(context, listen: false)
                .isFollowing(user.uid),
            builder: (context, snapshot) {
              final isFollowingUser = snapshot.data ?? false;
              return ElevatedButton(
                onPressed: _isLoading ? null : () => _toggleFollow(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowingUser ? AppColors.error : AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isFollowingUser ? '언팔로우' : '팔로우'),
              );
            },
          ),
        );
      },
    );
  }
}
