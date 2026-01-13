import 'package:flutter/material.dart';
import '../../services/feed_service.dart';
import '../../services/like_service.dart';
import '../../services/share_service.dart';
import '../../utils/theme_config.dart';
import '../../screens/walk_detail_view.dart';

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

  /// 상세 페이지로 이동
  void _navigateToDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WalkDetailView(
          docId: widget.item.walkId,
          walkData: widget.item.toWalkDataMap(),
        ),
      ),
    );
  }

  /// 좋아요 토글
  Future<void> _toggleLike() async {
    final originalLiked = _isLiked;
    final originalCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    try {
      await _likeService.toggleLike(widget.item.walkId);
      if (widget.onLikeChanged != null) {
        widget.onLikeChanged!();
      }
    } catch (e) {
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}일 전';
    if (difference.inHours > 0) return '${difference.inHours}시간 전';
    if (difference.inMinutes > 0) return '${difference.inMinutes}분 전';
    return '방금 전';
  }

  String _formatDuration(DateTime startTime, DateTime endTime) {
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return hours > 0 ? '${hours}시간 ${minutes}분' : '${minutes}분';
  }

  String _formatDistance(double distance) {
    return distance >= 1.0 ? '${distance.toStringAsFixed(1)}km' : '${(distance * 1000).toStringAsFixed(0)}m';
  }

  Future<void> _shareWalkRecord() async {
    try {
      final success = await _shareService.shareWalkRecord(widget.item.toWalkDataMap());
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유 중 오류가 발생했습니다.'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유 중 오류가 발생했습니다: $e'), backgroundColor: AppColors.error),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _navigateToDetail, // 전체 카드 클릭 시 상세 페이지 이동
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: widget.item.userProfileImageUrl != null && widget.item.userProfileImageUrl!.isNotEmpty
                        ? NetworkImage(widget.item.userProfileImageUrl!)
                        : null,
                    child: widget.item.userProfileImageUrl == null || widget.item.userProfileImageUrl!.isEmpty
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.userNickname ?? '이름 없음', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text(_formatTimeAgo(widget.item.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body: 이미지
            if (widget.item.imageUrls.isNotEmpty)
              Image.network(
                widget.item.imageUrls.first,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250, color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.error_outline, size: 48)),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_walk, size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text(_formatDuration(widget.item.startTime, widget.item.endTime), style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 16),
                      Icon(Icons.straighten, size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text(_formatDistance(widget.item.totalDistance), style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 16),
                      Text(widget.item.mood, style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  if (widget.item.memo != null && widget.item.memo!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(widget.item.memo!, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: IconButton(
                      icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : AppColors.textGrey),
                      onPressed: _toggleLike,
                    ),
                  ),
                  Text(_likeCount.toString(), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share),
                    color: AppColors.textGrey,
                    onPressed: _shareWalkRecord,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
