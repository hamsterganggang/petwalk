import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/profile_state_manager.dart';
import '../services/feed_service.dart';
import '../utils/theme_config.dart';
import 'walk_detail_view.dart';
import 'followers_page.dart';
import 'following_page.dart';

/// 타 사용자 프로필 보기 (인스타그램 스타일)
class OtherUserProfileView extends StatefulWidget {
  final String userId;
  final String? nickname;
  final String? profileImageUrl;

  const OtherUserProfileView({
    super.key,
    required this.userId,
    this.nickname,
    this.profileImageUrl,
  });

  @override
  State<OtherUserProfileView> createState() => _OtherUserProfileViewState();
}

class _OtherUserProfileViewState extends State<OtherUserProfileView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FeedService _feedService = FeedService();
  
  Map<String, dynamic>? _userData;
  List<FeedItem> _userFeeds = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUserData(),
      _loadUserFeeds(),
      _checkFollowStatus(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  /// 사용자 기본 정보 로드 (프로필)
  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('profiles').doc(widget.userId).get();
      if (doc.exists && mounted) {
        setState(() => _userData = doc.data());
      }
    } catch (e) {
      print('사용자 정보 로드 오류: $e');
    }
  }

  /// 사용자의 게시물(피드) 목록 로드
  Future<void> _loadUserFeeds() async {
    try {
      // FeedService를 활용하여 해당 사용자의 공개된 산책 기록만 가져옴
      final result = await _feedService.loadPublicFeed(
        likeStatusMap: {}, // 여기서는 좋아요 상태까지는 일단 무시
      );
      
      // 전체 피드 중 해당 사용자의 게시물만 필터링 (간이 구현)
      // 실제로는 별도의 query가 좋으나 기존 FeedService 호환성을 위해 필터링 사용
      final filtered = result.items.where((item) => item.userId == widget.userId).toList();
      
      if (mounted) {
        setState(() => _userFeeds = filtered);
      }
    } catch (e) {
      print('피드 로드 오류: $e');
    }
  }

  Future<void> _checkFollowStatus() async {
    final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
    final following = await profileManager.isFollowing(widget.userId);
    if (mounted) setState(() => _isFollowing = following);
  }

  @override
  Widget build(BuildContext context) {
    final profileManager = Provider.of<ProfileStateManager>(context);
    final nickname = _userData?['nickname'] ?? widget.nickname ?? '사용자';
    final photoUrl = _userData?['photoUrl'] ?? _userData?['photoURL'] ?? widget.profileImageUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: CustomScrollView(
                slivers: [
                  // 1. 프로필 헤더 영역
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                                child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 40) : null,
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem('게시물', _userFeeds.length),
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersPage(userId: widget.userId))),
                                      child: _buildStatItem('팔로워', _userData?['followers'] ?? 0),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowingPage(userId: widget.userId))),
                                      child: _buildStatItem('팔로잉', _userData?['following'] ?? 0),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (_userData?['bio'] != null && _userData!['bio'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(_userData!['bio']),
                            ),
                          const SizedBox(height: 20),
                          
                          // 팔로우 버튼
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_isFollowing) {
                                  await profileManager.unfollowUser(widget.userId);
                                } else {
                                  await profileManager.followUser(widget.userId);
                                }
                                _checkFollowStatus(); // 상태 갱신
                                _loadUserData(); // 팔로워 수 갱신
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing ? Colors.grey[200] : AppColors.primaryGreen,
                                foregroundColor: _isFollowing ? Colors.black : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(_isFollowing ? '팔로잉' : '팔로우', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. 피드 그리드 영역 (사진들)
                  const SliverToBoxAdapter(child: Divider(height: 1)),
                  SliverPadding(
                    padding: const EdgeInsets.all(2),
                    sliver: _userFeeds.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(60.0),
                              child: Center(child: Text('게시물이 없습니다.', style: TextStyle(color: Colors.grey))),
                            ),
                          )
                        : SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _userFeeds[index];
                                final hasImage = item.imageUrls.isNotEmpty;
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WalkDetailView(docId: item.walkId, walkData: item.toWalkDataMap()),
                                    ),
                                  ),
                                  child: Container(
                                    color: Colors.grey[200],
                                    child: hasImage 
                                        ? Image.network(item.imageUrls.first, fit: BoxFit.cover)
                                        : const Center(child: Icon(Icons.pets, color: Colors.white)),
                                  ),
                                );
                              },
                              childCount: _userFeeds.length,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
