import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/feed_service.dart';
import '../../services/like_service.dart';
import '../../services/share_service.dart';
import '../../services/walk_record_service.dart';
import '../../utils/theme_config.dart';
import '../../screens/walk_detail_view.dart';

/// 피드 아이템 위젯 (삭제 및 비공개 기능 추가)
class FeedItemWidget extends StatefulWidget {
  final FeedItem item;
  final VoidCallback? onLikeChanged;
  final VoidCallback? onContentChanged; // 삭제나 상태 변경 시 호출될 콜백

  const FeedItemWidget({
    super.key,
    required this.item,
    this.onLikeChanged,
    this.onContentChanged,
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
  final WalkRecordService _walkService = WalkRecordService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
    _likeCount = widget.item.likeCount;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 더보기 메뉴 (삭제/비공개)
  void _showMoreMenu() {
    // 실제 isPublic 상태는 walkData에 담겨있거나 item에 있어야 함
    // FeedItem 모델에 isPublic이 없으므로 일단 true 가정하고 service를 통해 처리
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('비공개로 전환'),
              onTap: () async {
                Navigator.pop(context);
                await _updateVisibility(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('삭제하기', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateVisibility(bool isPublic) async {
    try {
      await _walkService.updateVisibility(widget.item.walkId, isPublic);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시물 상태가 변경되었습니다.')));
        if (widget.onContentChanged != null) widget.onContentChanged!();
      }
    } catch (_) {}
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 산책 기록을 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRecord();
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord() async {
    try {
      await _walkService.deleteWalkRecord(widget.item.walkId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록이 삭제되었습니다.')));
        if (widget.onContentChanged != null) widget.onContentChanged!();
      }
    } catch (_) {}
  }

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

  Future<void> _toggleLike() async {
    final originalLiked = _isLiked;
    final originalCount = _likeCount;
    setState(() { _isLiked = !_isLiked; _likeCount += _isLiked ? 1 : -1; });
    _animationController.forward().then((_) => _animationController.reverse());
    try {
      await _likeService.toggleLike(widget.item.walkId);
      if (widget.onLikeChanged != null) widget.onLikeChanged!();
    } catch (e) {
      if (mounted) setState(() { _isLiked = originalLiked; _likeCount = originalCount; });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMine = widget.item.userId == _currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _navigateToDetail,
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
                        ? NetworkImage(widget.item.userProfileImageUrl!) : null,
                    child: (widget.item.userProfileImageUrl == null || widget.item.userProfileImageUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 20) : null,
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
                  // 내 게시물일 때만 더보기 버튼 표시
                  if (isMine)
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: _showMoreMenu,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                      Text('${(widget.item.endTime.difference(widget.item.startTime).inMinutes)}분', style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 16),
                      Icon(Icons.straighten, size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text('${widget.item.totalDistance.toStringAsFixed(1)}km', style: theme.textTheme.bodyMedium),
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
                    onPressed: () async => await _shareService.shareWalkRecord(widget.item.toWalkDataMap()),
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
