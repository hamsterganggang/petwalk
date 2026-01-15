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

  // 사용자 정보
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

/// 피드 데이터를 관리하는 서비스 클래스
class FeedService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();
  static const int _pageSize = 10;

  /// 공개 피드 로드 (비공개 계정 필터링 포함)
  Future<({List<FeedItem> items, DocumentSnapshot? lastDoc})> loadPublicFeed({
    DocumentSnapshot? lastDocument,
    required Map<String, bool> likeStatusMap,
  }) async {
    try {
      final user = _auth.currentUser;
      final currentUserId = user?.uid;

      // 1. 기본 쿼리: 공개 설정된 게시물들
      Query publicQuery = _firestore
          .collection('walks')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      // 페이지네이션을 위해 넉넉히 불러옴 (필터링 대비)
      final fetchLimit = _pageSize * 4;
      QuerySnapshot publicSnapshot = await publicQuery.limit(fetchLimit).get();

      // 2. 내 게시물도 추가로 불러옴 (비공개여도 나는 보여야 함)
      QuerySnapshot? userSnapshot;
      if (currentUserId != null) {
        userSnapshot = await _firestore
            .collection('walks')
            .where('userId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .limit(fetchLimit)
            .get();
      }

      // 3. 합치기 및 중복 제거
      final allDocs = <String, QueryDocumentSnapshot>{};
      for (var doc in publicSnapshot.docs) allDocs[doc.id] = doc;
      if (userSnapshot != null) {
        for (var doc in userSnapshot.docs) allDocs[doc.id] = doc;
      }

      final sortedDocs = allDocs.values.toList()
        ..sort((a, b) {
          Timestamp? aTime = ((a.data() as Map)['createdAt'] ?? (a.data() as Map)['startTime']) as Timestamp?;
          Timestamp? bTime = ((b.data() as Map)['createdAt'] ?? (b.data() as Map)['startTime']) as Timestamp?;
          return (bTime ?? Timestamp.now()).compareTo(aTime ?? Timestamp.now());
        });

      // 4. 사용자 정보 일괄 조회
      final userIds = sortedDocs.map((doc) => (doc.data() as Map)['userId'] as String).toSet().toList();
      final userMap = await _fetchUsers(userIds);

      // 5. 비공개 계정 게시물 필터링
      final filteredItems = <FeedItem>[];
      for (var doc in sortedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;
        final userInfo = userMap[userId];
        
        // 필터링 로직:
        // - 내 게시물은 무조건 노출
        // - 타인의 게시물인데 계정이 비공개(isPrivate: true)면 제외
        final bool isPrivateAccount = userInfo?['isPrivate'] ?? false;
        if (userId != currentUserId && isPrivateAccount) {
          continue; // 비공개 계정 게시물 건너뛰기
        }

        final startTime = (data['startTime'] as Timestamp).toDate();
        filteredItems.add(FeedItem(
          walkId: doc.id,
          userId: userId,
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
        ));
      }

      // 6. 결과 반환 (페이지네이션 적용)
      final items = filteredItems.take(_pageSize).toList();
      final lastDoc = items.isNotEmpty ? sortedDocs.firstWhere((doc) => doc.id == items.last.walkId) : null;

      return (items: items, lastDoc: lastDoc);
    } catch (e) {
      print('피드 로드 오류: $e');
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final userMap = <String, Map<String, dynamic>>{};
    final foundIds = <String>{};

    for (var i = 0; i < userIds.length; i += 10) {
      final batch = userIds.skip(i).take(10).toList();
      try {
        final profilesSnapshot = await _firestore.collection('profiles').where(FieldPath.documentId, whereIn: batch).get();
        for (var doc in profilesSnapshot.docs) {
          userMap[doc.id] = doc.data();
          foundIds.add(doc.id);
        }
      } catch (_) {}

      final notFound = batch.where((id) => !foundIds.contains(id)).toList();
      if (notFound.isNotEmpty) {
        try {
          final usersSnapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: notFound).get();
          for (var doc in usersSnapshot.docs) userMap[doc.id] = doc.data();
        } catch (_) {}
      }
    }
    return userMap;
  }
}
