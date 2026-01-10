import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/feed_service.dart';
import '../../services/like_service.dart';
import '../../services/share_service.dart';
import '../../utils/theme_config.dart';

/// 피드 아이템 위젯
class FeedItemWidget extends StatefulWidget {
  final FeedItem item;
  final VoidCallback? onLikeChanged;

  const FeedItemWidget({
    super.key,
    required this.item,
    this.onLikeChanged,
  });

  @override
  State<FeedItemWidget> createState() => _FeedItemWidgetState();
}

class _FeedItemWidgetState extends State<FeedItemWidget>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final LikeService _likeService = LikeService();
  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
    _likeCount = widget.item.likeCount;

    // 좋아요 애니메이션 설정
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 좋아요 토글
  Future<void> _toggleLike() async {
    final originalLiked = _isLiked;
    final originalCount = _likeCount;

    // 낙관적 UI 업데이트
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    // 애니메이션 실행
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    try {
      await _likeService.toggleLike(widget.item.walkId);
      if (widget.onLikeChanged != null) {
        widget.onLikeChanged!();
      }
    } catch (e) {
      // 에러 발생 시 롤백
      if (mounted) {
        setState(() {
          _isLiked = originalLiked;
          _likeCount = originalCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('좋아요 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 시간 포맷팅 (예: '2시간 전')
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  /// 산책 시간 포맷팅
  String _formatDuration(DateTime startTime, DateTime endTime) {
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}시간 ${minutes}분';
    } else {
      return '${minutes}분';
    }
  }

  /// 거리 포맷팅
  String _formatDistance(double distance) {
    if (distance >= 1.0) {
      return '${distance.toStringAsFixed(1)}km';
    } else {
      return '${(distance * 1000).toStringAsFixed(0)}m';
    }
  }

  /// 산책 기록 공유
  Future<void> _shareWalkRecord() async {
    try {
      // FeedItem을 Map으로 변환
      final walkData = {
        'startTime': widget.item.startTime,
        'endTime': widget.item.endTime,
        'totalDistance': widget.item.totalDistance,
        'memo': widget.item.memo,
        'mood': widget.item.mood,
      };

      final success = await _shareService.shareWalkRecord(walkData);
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공유 중 오류가 발생했습니다.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('공유 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: 프로필 이미지, 닉네임, 작성 시간
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.item.userProfileImageUrl != null &&
                          widget.item.userProfileImageUrl!.isNotEmpty
                      ? NetworkImage(widget.item.userProfileImageUrl!)
                      : null,
                  child: widget.item.userProfileImageUrl == null ||
                          widget.item.userProfileImageUrl!.isEmpty
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.userNickname ?? '이름 없음',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(widget.item.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body: 산책 정보 및 사진
          if (widget.item.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Image.network(
                widget.item.imageUrls.first,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error_outline, size: 48),
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 산책 요약 정보
                Row(
                  children: [
                    Icon(Icons.directions_walk,
                        size: 18, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(widget.item.startTime, widget.item.endTime),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.straighten,
                        size: 18, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      _formatDistance(widget.item.totalDistance),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      widget.item.mood,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),

                // 메모
                if (widget.item.memo != null && widget.item.memo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.item.memo!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),

          // Footer: 좋아요 버튼 및 공유 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : AppColors.textGrey,
                    ),
                    onPressed: _toggleLike,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _likeCount.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share),
                  color: AppColors.textGrey,
                  onPressed: _shareWalkRecord,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
