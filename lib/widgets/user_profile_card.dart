import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petwalk/models/user_model.dart';
import 'package:petwalk/services/follow_service.dart';
import 'package:petwalk/services/block_service.dart';
import 'package:petwalk/utils/theme_config.dart';

class UserProfileCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onBlocked; // 차단 후 콜백

  const UserProfileCard({
    super.key,
    required this.user,
    this.onBlocked,
  });

  @override
  State<UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<UserProfileCard> {
  final FollowService _followService = FollowService();
  final BlockService _blockService = BlockService();
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _isLoading = true; // 로딩 상태 추가
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (_currentUserId == widget.user.uid) {
      setState(() => _isLoading = false);
      return;
    }

    // BlockService 초기화
    await _blockService.initialize();

    // 팔로우 상태 및 차단 상태 확인
    final isFollowing = await _followService.isFollowing(_currentUserId, widget.user.uid);
    final isBlocked = _blockService.isBlocked(widget.user.uid);

    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isBlocked = isBlocked;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfFollowing() async {
    if (_currentUserId == widget.user.uid) {
      return;
    }
    final isFollowing = await _followService.isFollowing(_currentUserId, widget.user.uid);
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
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

  /// 사용자 차단
  Future<void> _blockUser() async {
    if (_isBlocked) {
      // 이미 차단된 경우 차단 해제
      await _unblockUser();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 차단'),
        content: Text('${widget.user.nickname ?? '이 사용자'}를 차단하시겠습니까?\n차단된 사용자의 게시물은 피드와 검색 결과에서 제외됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('차단'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _blockService.blockUser(widget.user.uid);

        // 양방향 팔로우 관계 모두 취소 (내가 팔로우하는 경우 + 상대방이 나를 팔로우하는 경우)
        await _followService.removeAllFollowRelationships(
          _currentUserId,
          widget.user.uid,
        );

        await _blockService.refresh();

        if (mounted) {
          setState(() {
            _isBlocked = true;
            _isFollowing = false; // 차단 시 팔로우 상태도 false로 설정
          });

          // 차단 후 콜백 호출 (검색 결과에서 제거)
          widget.onBlocked?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자가 차단되었습니다.'),
              backgroundColor: AppColors.success,
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
      }
    }
  }

  /// 사용자 차단 해제
  Future<void> _unblockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차단 해제'),
        content: Text('${widget.user.nickname ?? '이 사용자'}의 차단을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('차단 해제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _blockService.unblockUser(widget.user.uid);
        await _blockService.refresh();

        if (mounted) {
          setState(() {
            _isBlocked = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('차단이 해제되었습니다.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('차단 해제 중 오류가 발생했습니다: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
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
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'block' || value == 'unblock') {
                        _blockUser();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _isBlocked ? 'unblock' : 'block',
                        child: Row(
                          children: [
                            Icon(
                              _isBlocked ? Icons.check_circle_outline : Icons.block,
                              size: 20,
                              color: _isBlocked ? AppColors.primaryGreen : AppColors.textGrey,
                            ),
                            const SizedBox(width: 8),
                            Text(_isBlocked ? '차단 해제' : '차단'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
