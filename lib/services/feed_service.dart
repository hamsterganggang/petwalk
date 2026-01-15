import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

/// 피드 아이템 데이터 모델
class FeedItem {
  final String walkId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final double totalDistance;
  final String? memo;
  final String mood;
  final List<String> imageUrls;
  final List<dynamic> route;
  final List<dynamic> petNames;
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;

  final String? userNickname;
  final String? userProfileImageUrl;

  FeedItem({
    required this.walkId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.totalDistance,
    this.memo,
    required this.mood,
    required this.imageUrls,
    this.route = const [],
    this.petNames = const [],
    required this.createdAt,
    required this.likeCount,
    required this.isLiked,
    this.userNickname,
    this.userProfileImageUrl,
  });

  FeedItem copyWith({
    String? walkId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    double? totalDistance,
    String? memo,
    String? mood,
    List<String>? imageUrls,
    List<dynamic>? route,
    List<dynamic>? petNames,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
    String? userNickname,
    String? userProfileImageUrl,
  }) {
    return FeedItem(
      walkId: walkId ?? this.walkId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalDistance: totalDistance ?? this.totalDistance,
      memo: memo ?? this.memo,
      mood: mood ?? this.mood,
      imageUrls: imageUrls ?? this.imageUrls,
      route: route ?? this.route,
      petNames: petNames ?? this.petNames,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      userNickname: userNickname ?? this.userNickname,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
    );
  }

  Map<String, dynamic> toWalkDataMap() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'totalDistance': totalDistance,
      'memo': memo,
      'mood': mood,
      'imageUrls': imageUrls,
      'route': route,
      'petNames': petNames,
      'userId': userId,
      'likeCount': likeCount,
    };
  }
}

class FeedService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();
  static const int _pageSize = 10;

  /// [개선] 공개 피드 로드 (팔로우 중인 비공개 계정 허용)
  Future<({List<FeedItem> items, DocumentSnapshot? lastDoc})> loadPublicFeed({
    DocumentSnapshot? lastDocument,
    required Map<String, bool> likeStatusMap,
  }) async {
    try {
      final user = _auth.currentUser;
      final currentUserId = user?.uid;

      // 1. 내 팔로잉 목록 가져오기 (비공개 필터링용)
      List<String> followingIds = [];
      if (currentUserId != null) {
        final followsSnapshot = await _firestore.collection('follows').where('followerId', isEqualTo: currentUserId).get();
        followingIds = followsSnapshot.docs.map((doc) => doc.data()['followingId'] as String).toList();
      }

      // 2. 기본 공개 게시물 쿼리
      Query publicQuery = _firestore.collection('walks').where('isPublic', isEqualTo: true).orderBy('createdAt', descending: true);
      final fetchLimit = _pageSize * 4;
      QuerySnapshot publicSnapshot = await publicQuery.limit(fetchLimit).get();

      // 3. 내 게시물
      QuerySnapshot? userSnapshot;
      if (currentUserId != null) {
        userSnapshot = await _firestore.collection('walks').where('userId', isEqualTo: currentUserId).orderBy('createdAt', descending: true).limit(fetchLimit).get();
      }

      final allDocs = <String, QueryDocumentSnapshot>{};
      for (var doc in publicSnapshot.docs) allDocs[doc.id] = doc;
      if (userSnapshot != null) for (var doc in userSnapshot.docs) allDocs[doc.id] = doc;

      final sortedDocs = allDocs.values.toList()
        ..sort((a, b) {
          Timestamp? aTime = ((a.data() as Map)['createdAt'] ?? (a.data() as Map)['startTime']) as Timestamp?;
          Timestamp? bTime = ((b.data() as Map)['createdAt'] ?? (b.data() as Map)['startTime']) as Timestamp?;
          return (bTime ?? Timestamp.now()).compareTo(aTime ?? Timestamp.now());
        });

      final userIds = sortedDocs.map((doc) => (doc.data() as Map)['userId'] as String).toSet().toList();
      final userMap = await _fetchUsers(userIds);

      final filteredItems = <FeedItem>[];
      for (var doc in sortedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;
        final userInfo = userMap[userId];
        
        final bool isPrivateAccount = userInfo?['isPrivate'] ?? false;
        // 필터링: (내꺼 아님) AND (비공개 계정임) AND (팔로우 안함) 이면 숨김
        if (userId != currentUserId && isPrivateAccount && !followingIds.contains(userId)) {
          continue;
        }

        filteredItems.add(_mapToFeedItem(doc, userInfo, likeStatusMap));
      }

      final items = filteredItems.take(_pageSize).toList();
      final lastDoc = items.isNotEmpty ? sortedDocs.firstWhere((doc) => doc.id == items.last.walkId) : null;
      return (items: items, lastDoc: lastDoc);
    } catch (e) { rethrow; }
  }

  /// [신규] 특정 사용자의 피드 로드 (팔로워면 모든 게시물, 아니면 공개만)
  Future<List<FeedItem>> loadUserFeeds({
    required String targetUserId,
    required bool isFollower,
    required Map<String, bool> likeStatusMap,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      Query query = _firestore.collection('walks').where('userId', isEqualTo: targetUserId);
      
      // 본인이거나 팔로워가 아니면 'isPublic: true' 게시물만 가져옴
      if (targetUserId != currentUserId && !isFollower) {
        query = query.where('isPublic', isEqualTo: true);
      }
      
      final snapshot = await query.orderBy('createdAt', descending: true).get();
      final userMap = await _fetchUsers([targetUserId]);
      final userInfo = userMap[targetUserId];

      return snapshot.docs.map((doc) => _mapToFeedItem(doc, userInfo, likeStatusMap)).toList();
    } catch (e) {
      print('사용자 피드 로드 오류: $e');
      return [];
    }
  }

  FeedItem _mapToFeedItem(DocumentSnapshot doc, Map<String, dynamic>? userInfo, Map<String, bool> likeStatusMap) {
    final data = doc.data() as Map<String, dynamic>;
    final startTime = (data['startTime'] as Timestamp).toDate();
    return FeedItem(
      walkId: doc.id,
      userId: data['userId'] as String,
      startTime: startTime,
      endTime: (data['endTime'] as Timestamp).toDate(),
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
      memo: data['memo'] as String?,
      mood: data['mood'] as String? ?? '😊',
      imageUrls: (data['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      route: data['route'] as List<dynamic>? ?? [],
      petNames: data['petNames'] as List<dynamic>? ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? startTime,
      likeCount: (data['likeCount'] as int?) ?? 0,
      isLiked: likeStatusMap[doc.id] ?? false,
      userNickname: userInfo?['nickname'] as String?,
      userProfileImageUrl: (userInfo?['photoURL'] ?? userInfo?['photoUrl'] ?? userInfo?['profileImageUrl']) as String?,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final userMap = <String, Map<String, dynamic>>{};
    for (var i = 0; i < userIds.length; i += 10) {
      final batch = userIds.skip(i).take(10).toList();
      final profilesSnapshot = await _firestore.collection('profiles').where(FieldPath.documentId, whereIn: batch).get();
      for (var doc in profilesSnapshot.docs) userMap[doc.id] = doc.data();
    }
    return userMap;
  }
}
