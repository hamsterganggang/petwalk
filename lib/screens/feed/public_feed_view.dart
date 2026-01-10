import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/feed_service.dart';
import '../../services/like_service.dart';
import '../../services/block_service.dart';
import '../../utils/theme_config.dart';
import '../../widgets/feed/feed_item_widget.dart';

/// 공개 피드 화면 (무한 스크롤)
class PublicFeedView extends StatefulWidget {
  const PublicFeedView({super.key});

  @override
  State<PublicFeedView> createState() => _PublicFeedViewState();
}

class _PublicFeedViewState extends State<PublicFeedView> {
  final FeedService _feedService = FeedService();
  final LikeService _likeService = LikeService();
  final BlockService _blockService = BlockService();
  final ScrollController _scrollController = ScrollController();

  List<FeedItem> _feedItems = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
    _scrollController.addListener(_onScroll);
  }

  /// BlockService 초기화 후 피드 로드
  Future<void> _initializeAndLoad() async {
    // BlockService 초기화 (비동기)
    await _blockService.initialize();
    _loadInitialFeed();
  }


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 스크롤 리스너: 바닥에 도달하면 다음 페이지 로드
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreFeed();
    }
  }

  /// 초기 피드 로드
  Future<void> _loadInitialFeed() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // BlockService 초기화 확인
      await _blockService.initialize();
      
      // 좋아요 상태 확인을 위한 walkId 목록 (초기에는 빈 리스트)
      final likeStatusMap = <String, bool>{};

      final result = await _feedService.loadPublicFeed(
        lastDocument: null,
        likeStatusMap: likeStatusMap,
      );

      // 로드된 아이템들의 좋아요 상태 확인
      List<FeedItem> items = result.items;
      if (items.isNotEmpty) {
        final walkIds = items.map((item) => item.walkId).toList();
        final likesMap = await _likeService.checkLikesStatus(walkIds);

      // 좋아요 상태 업데이트
      items = items.map((item) {
        return item.copyWith(
          isLiked: likesMap[item.walkId] ?? false,
        );
      }).toList();
      }

      // 차단된 사용자의 게시물 필터링
      items = _blockService.filterBlockedContent(items);

      if (mounted) {
        setState(() {
          _feedItems = items;
          _lastDocument = result.lastDoc;
          _hasMoreData = result.lastDoc != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// 추가 피드 로드 (무한 스크롤)
  Future<void> _loadMoreFeed() async {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // BlockService 초기화 확인
      await _blockService.initialize();
      
      // 현재 아이템들의 좋아요 상태 확인
      final currentWalkIds = _feedItems.map((item) => item.walkId).toList();
      final likeStatusMap = await _likeService.checkLikesStatus(currentWalkIds);

      final result = await _feedService.loadPublicFeed(
        lastDocument: _lastDocument,
        likeStatusMap: likeStatusMap,
      );

      if (result.items.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMoreData = false;
            _isLoadingMore = false;
          });
        }
        return;
      }

      // 새 아이템들의 좋아요 상태 확인
      final newWalkIds = result.items.map((item) => item.walkId).toList();
      final newLikesMap = await _likeService.checkLikesStatus(newWalkIds);

      // 좋아요 상태 업데이트
      var updatedItems = result.items.map((item) {
        return item.copyWith(
          isLiked: newLikesMap[item.walkId] ?? false,
        );
      }).toList();

      // 차단된 사용자의 게시물 필터링
      updatedItems = _blockService.filterBlockedContent(updatedItems);

      if (mounted) {
        setState(() {
          _feedItems.addAll(updatedItems);
          _lastDocument = result.lastDoc;
          _hasMoreData = result.lastDoc != null;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// 좋아요 상태 새로고침
  Future<void> _refreshLikeStatus() async {
    if (_feedItems.isEmpty) return;

    try {
      final walkIds = _feedItems.map((item) => item.walkId).toList();
      final likesMap = await _likeService.checkLikesStatus(walkIds);

      if (mounted) {
        setState(() {
          _feedItems = _feedItems.map((item) {
            return item.copyWith(
              isLiked: likesMap[item.walkId] ?? false,
            );
          }).toList();
        });
      }
    } catch (e) {
      // 에러는 무시 (백그라운드 업데이트)
      print('좋아요 상태 새로고침 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError && _feedItems.isEmpty) {
      final isIndexError = _errorMessage?.contains('index') == true || 
                          _errorMessage?.contains('FAILED_PRECONDITION') == true;
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isIndexError ? Icons.build : Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                isIndexError 
                    ? 'Firestore 인덱스가 필요합니다'
                    : '피드를 불러올 수 없습니다',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (isIndexError) ...[
                Text(
                  '피드를 표시하려면 Firestore 인덱스가 필요합니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '오류 메시지에 포함된 링크를 클릭하여\n인덱스를 생성해주세요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '인덱스 생성 후 몇 분 정도 기다려주세요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryGreen,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  _errorMessage ?? '알 수 없는 오류',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadInitialFeed,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_feedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 64,
              color: AppColors.textGrey,
            ),
            const SizedBox(height: 16),
            Text(
              '아직 공개된 산책 기록이 없습니다',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '산책 기록을 공개하면 여기에 표시됩니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialFeed,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _feedItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _feedItems.length) {
            // 로딩 인디케이터
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return FeedItemWidget(
            item: _feedItems[index],
            onLikeChanged: _refreshLikeStatus,
          );
        },
      ),
    );
  }
}
