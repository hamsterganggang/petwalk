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

  /// 좋아요 상태와 카운트를 업데이트한 새 인스턴스 생성
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

  /// WalkDetailView에서 사용할 수 있도록 Map으로 변환 (likeCount 추가)
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
      'likeCount': likeCount, // 상세 페이지를 위해 추가
    };
  }
}

/// 피드 데이터를 관리하는 서비스 클래스
class FeedService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();
  static const int _pageSize = 10;

  /// 공개 피드 및 사용자 산책 기록 로드 (페이지네이션)
  Future<({List<FeedItem> items, DocumentSnapshot? lastDoc})> loadPublicFeed({
    DocumentSnapshot? lastDocument,
    required Map<String, bool> likeStatusMap,
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid;

      Query publicQuery = _firestore
          .collection('walks')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      Query? userQuery;
      if (userId != null) {
        userQuery = _firestore
            .collection('walks')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true);
      }

      List<String> followingIds = [];
      if (userId != null) {
        final followsSnapshot = await _firestore
            .collection('follows')
            .where('followerId', isEqualTo: userId)
            .get();
        followingIds = followsSnapshot.docs
            .map((doc) => doc.data()['followingId'] as String)
            .toList();
      }

      final fetchLimit = _pageSize * 3;
      QuerySnapshot publicSnapshot;
      QuerySnapshot? userSnapshot;

      if (userQuery != null) {
        final results = await Future.wait<QuerySnapshot>([
          publicQuery.limit(fetchLimit).get(),
          userQuery.limit(fetchLimit).get(),
        ]);
        publicSnapshot = results[0];
        userSnapshot = results[1];
      } else {
        publicSnapshot = await publicQuery.limit(fetchLimit).get();
        userSnapshot = null;
      }

      List<QuerySnapshot> followingSnapshots = [];
      if (followingIds.isNotEmpty) {
        for (var i = 0; i < followingIds.length; i += 10) {
          final batch = followingIds.skip(i).take(10).toList();
          final snapshot = await _firestore
              .collection('walks')
              .where('userId', whereIn: batch)
              .orderBy('createdAt', descending: true)
              .limit(fetchLimit)
              .get();
          followingSnapshots.add(snapshot);
        }
      }

      final allDocs = <String, QueryDocumentSnapshot>{};
      for (var doc in publicSnapshot.docs) allDocs[doc.id] = doc;
      if (userSnapshot != null) {
        for (var doc in userSnapshot.docs) allDocs[doc.id] = doc;
      }
      for (var snapshot in followingSnapshots) {
        for (var doc in snapshot.docs) allDocs[doc.id] = doc;
      }

      final sortedDocs = allDocs.values.toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          Timestamp? aTime = (aData['createdAt'] ?? aData['startTime']) as Timestamp?;
          Timestamp? bTime = (bData['createdAt'] ?? bData['startTime']) as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

      List<QueryDocumentSnapshot> paginatedDocs;
      if (lastDocument == null) {
        paginatedDocs = sortedDocs.take(_pageSize).toList();
      } else {
        final lastIndex = sortedDocs.indexWhere((doc) => doc.id == lastDocument.id);
        if (lastIndex == -1 || lastIndex >= sortedDocs.length - 1) {
          return (items: const <FeedItem>[], lastDoc: null);
        }
        paginatedDocs = sortedDocs.skip(lastIndex + 1).take(_pageSize).toList();
      }

      if (paginatedDocs.isEmpty) return (items: const <FeedItem>[], lastDoc: null);

      final userIds = paginatedDocs
          .map((doc) => (doc.data() as Map<String, dynamic>)['userId'] as String)
          .toSet().toList();
      final userMap = await _fetchUsers(userIds);

      final items = paginatedDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;
        final userInfo = userMap[userId];
        final startTime = (data['startTime'] as Timestamp).toDate();

        return FeedItem(
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
        );
      }).toList();

      return (items: items, lastDoc: paginatedDocs.last);
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
