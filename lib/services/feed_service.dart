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
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      userNickname: userNickname ?? this.userNickname,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
    );
  }
}

/// 피드 데이터를 관리하는 서비스 클래스
class FeedService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();
  static const int _pageSize = 10;

  /// 공개 피드 및 사용자 산책 기록 로드 (페이지네이션)
  /// 
  /// [lastDocument] 마지막으로 로드한 문서 (null이면 첫 페이지)
  /// 반환: FeedItem 리스트와 마지막 문서
  Future<({List<FeedItem> items, DocumentSnapshot? lastDoc})> loadPublicFeed({
    DocumentSnapshot? lastDocument,
    required Map<String, bool> likeStatusMap,
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid;

      // 공개된 산책 기록 쿼리
      Query publicQuery = _firestore
          .collection('walks')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      // 현재 사용자의 산책 기록 쿼리 (공개 여부와 관계없이)
      Query? userQuery;
      if (userId != null) {
        userQuery = _firestore
            .collection('walks')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true);
      }

      // 페이지네이션을 위해 충분한 수의 문서를 가져옴
      final fetchLimit = _pageSize * 3; // 중복 제거를 위해 더 많이 가져옴
      
      // 두 쿼리를 병렬로 실행
      QuerySnapshot publicSnapshot;
      QuerySnapshot? userSnapshot;
      
      if (userQuery != null) {
        final userFuture = userQuery.limit(fetchLimit).get();
        final results = await Future.wait<QuerySnapshot>([
          publicQuery.limit(fetchLimit).get(),
          userFuture,
        ]);
        if (results.isNotEmpty) {
          publicSnapshot = results[0];
        } else {
          publicSnapshot = await publicQuery.limit(fetchLimit).get();
        }
        if (results.length >= 2) {
          userSnapshot = results[1];
        } else {
          userSnapshot = null;
        }
      } else {
        publicSnapshot = await publicQuery.limit(fetchLimit).get();
        userSnapshot = null;
      }

      // 모든 문서를 합치고 중복 제거 (walkId 기준)
      final allDocs = <String, QueryDocumentSnapshot>{};
      
      for (var doc in publicSnapshot.docs) {
        allDocs[doc.id] = doc;
      }
      
      if (userSnapshot != null) {
        for (var doc in userSnapshot.docs) {
          allDocs[doc.id] = doc; // 중복이면 덮어쓰기 (같은 문서)
        }
      }

      // createdAt 기준으로 정렬
      final sortedDocs = allDocs.values.toList()
        ..sort((a, b) {
          final aCreatedAt = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bCreatedAt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aCreatedAt == null && bCreatedAt == null) return 0;
          if (aCreatedAt == null) return 1;
          if (bCreatedAt == null) return -1;
          return bCreatedAt.compareTo(aCreatedAt); // 내림차순
        });

      // 페이지네이션 처리
      List<QueryDocumentSnapshot> paginatedDocs;
      if (lastDocument == null) {
        // 첫 페이지
        paginatedDocs = sortedDocs.take(_pageSize).toList();
      } else {
        // 마지막 문서 이후의 문서들만 가져오기
        final lastDocId = lastDocument.id;
        final lastIndex = sortedDocs.indexWhere((doc) => doc.id == lastDocId);
        if (lastIndex == -1 || lastIndex >= sortedDocs.length - 1) {
          return (items: const <FeedItem>[], lastDoc: null);
        }
        paginatedDocs = sortedDocs.skip(lastIndex + 1).take(_pageSize).toList();
      }

      if (paginatedDocs.isEmpty) {
        return (items: const <FeedItem>[], lastDoc: null);
      }

      // 사용자 ID 목록 추출
      final userIds = paginatedDocs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['userId'] as String;
          })
          .toSet()
          .toList();

      // 사용자 정보 일괄 조회
      final userMap = await _fetchUsers(userIds);

      // FeedItem 리스트 생성
      final items = <FeedItem>[];
      for (var doc in paginatedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;
        final userInfo = userMap[userId];

        final startTime = (data['startTime'] as Timestamp).toDate();
        final endTime = (data['endTime'] as Timestamp).toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? 
                         DateTime.now();
        
        items.add(FeedItem(
          walkId: doc.id,
          userId: userId,
          startTime: startTime,
          endTime: endTime,
          totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
          memo: data['memo'] as String?,
          mood: data['mood'] as String? ?? '😊',
          imageUrls: (data['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
          createdAt: createdAt,
          likeCount: (data['likeCount'] as int?) ?? 0,
          isLiked: likeStatusMap[doc.id] ?? false,
          userNickname: userInfo?['nickname'] as String?,
          userProfileImageUrl: userInfo?['photoURL'] as String?,
        ));
      }

      final DocumentSnapshot? lastDoc = paginatedDocs.isNotEmpty 
          ? paginatedDocs.last 
          : null;

      return (items: items, lastDoc: lastDoc);
    } catch (e) {
      print('피드 로드 오류: $e');
      rethrow;
    }
  }

  /// 사용자 정보 일괄 조회
  /// 
  /// [userIds] 조회할 사용자 ID 목록
  /// 반환: userId를 키로 하는 사용자 정보 Map
  Future<Map<String, Map<String, dynamic>>> _fetchUsers(
      List<String> userIds) async {
    if (userIds.isEmpty) {
      return {};
    }

    try {
      // Firestore의 whereIn은 최대 10개까지만 지원
      final userMap = <String, Map<String, dynamic>>{};
      
      // 10개씩 나누어 조회
      for (var i = 0; i < userIds.length; i += 10) {
        final batch = userIds.skip(i).take(10).toList();
        final userSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in userSnapshot.docs) {
          userMap[doc.id] = doc.data();
        }
      }

      return userMap;
    } catch (e) {
      print('사용자 정보 조회 오류: $e');
      return {};
    }
  }
}
