import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petwalk/models/user_model.dart';
import 'package:petwalk/services/follow_service.dart';

class UserProfileCard extends StatefulWidget {
  final UserModel user;

  const UserProfileCard({super.key, required this.user});

  @override
  State<UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<UserProfileCard> {
  final FollowService _followService = FollowService();
  bool _isFollowing = false;
  bool _isLoading = true; // 로딩 상태 추가
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _checkIfFollowing();
  }

  Future<void> _checkIfFollowing() async {
    if (_currentUserId == widget.user.uid) {
      setState(() => _isLoading = false);
      return;
    }
    final isFollowing = await _followService.isFollowing(_currentUserId, widget.user.uid);
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final originalFollowStatus = _isFollowing;
    // 1. 낙관적 UI 업데이트
    setState(() {
      _isFollowing = !_isFollowing;
    });

    try {
      // 2. 서비스 로직 호출
      await _followService.toggleFollowStatus(_currentUserId, widget.user.uid, originalFollowStatus);
    } catch (e) {
      // 3. 에러 처리
      if (mounted) {
        // UI 롤백
        setState(() {
          _isFollowing = originalFollowStatus;
        });
        // SnackBar로 에러 알림
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('작업에 실패했습니다: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isCurrentUser = _currentUserId == widget.user.uid;

    // Null 체크 추가
    final profileImageUrl = widget.user.profileImageUrl;
    final nickname = widget.user.nickname;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl) // null이 아닐 때만 NetworkImage 사용
                  : null,
              child: profileImageUrl == null || profileImageUrl.isEmpty
                  ? const Icon(Icons.person, size: 28) // null이거나 비어있을 때 아이콘 표시
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                nickname ?? '이름 없음', // null일 경우 '이름 없음'으로 표시
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (!isCurrentUser) // 내 프로필이 아닐 때만 버튼 표시
              _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? Colors.grey[300] : theme.colorScheme.primary,
                          foregroundColor: _isFollowing ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: theme.textTheme.labelLarge,
                        ),
                        child: Text(_isFollowing ? '언팔로우' : '팔로우'),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}
