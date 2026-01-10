import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

/// 사용자 차단 서비스
class BlockService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();
  
  // 차단된 사용자 ID 목록 (메모리 캐시)
  Set<String> _blockedUserIds = {};
  bool _isInitialized = false;

  /// 차단 목록 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final user = _auth.currentUser;
    if (user == null) {
      _blockedUserIds = {};
      _isInitialized = true;
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: user.uid)
          .get();

      _blockedUserIds = snapshot.docs
          .map((doc) => doc.data()['blockedId'] as String)
          .toSet();
      
      _isInitialized = true;
    } catch (e) {
      print('차단 목록 초기화 오류: $e');
      _blockedUserIds = {};
      _isInitialized = true;
    }
  }

  /// 차단 목록 새로고침
  Future<void> refresh() async {
    _isInitialized = false;
    await initialize();
  }

  /// 사용자 차단
  /// 
  /// [blockedUserId] 차단할 사용자 ID
  Future<void> blockUser(String blockedUserId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (user.uid == blockedUserId) {
      throw Exception('자기 자신을 차단할 수 없습니다.');
    }

    try {
      // 중복 체크
      final existingBlock = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: user.uid)
          .where('blockedId', isEqualTo: blockedUserId)
          .limit(1)
          .get();

      if (existingBlock.docs.isNotEmpty) {
        return; // 이미 차단됨
      }

      await _firestore.collection('blocks').add({
        'blockerId': user.uid,
        'blockedId': blockedUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 캐시 업데이트
      _blockedUserIds.add(blockedUserId);
    } catch (e) {
      print('사용자 차단 오류: $e');
      rethrow;
    }
  }

  /// 차단 해제
  /// 
  /// [blockedUserId] 차단 해제할 사용자 ID
  Future<void> unblockUser(String blockedUserId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      final blockDocs = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: user.uid)
          .where('blockedId', isEqualTo: blockedUserId)
          .get();

      final batch = _firestore.batch();
      for (var doc in blockDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // 캐시 업데이트
      _blockedUserIds.remove(blockedUserId);
    } catch (e) {
      print('차단 해제 오류: $e');
      rethrow;
    }
  }

  /// 차단된 사용자 목록 조회
  /// 
  /// 반환: 차단된 사용자 정보 리스트
  Future<List<Map<String, dynamic>>> getBlockedList() async {
    final user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: user.uid)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final blockedIds = snapshot.docs
          .map((doc) => doc.data()['blockedId'] as String)
          .toList();

      // 사용자 정보 조회 (users와 profiles 컬렉션 모두 확인)
      final users = <Map<String, dynamic>>[];
      final foundIds = <String>{};
      
      for (var i = 0; i < blockedIds.length; i += 10) {
        final batch = blockedIds.skip(i).take(10).toList();
        
        // users 컬렉션에서 조회
        try {
          final userSnapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (var doc in userSnapshot.docs) {
            final data = doc.data();
            data['uid'] = doc.id; // 문서 ID를 uid로 추가
            final blockDoc = snapshot.docs.firstWhere(
              (blockDoc) => blockDoc.data()['blockedId'] == doc.id,
            );
            data['blockId'] = blockDoc.id;
            users.add(data);
            foundIds.add(doc.id);
          }
        } catch (e) {
          print('users 컬렉션 조회 오류: $e');
        }
        
        // profiles 컬렉션에서도 조회 (users에서 찾지 못한 경우)
        final notFound = batch.where((id) => !foundIds.contains(id)).toList();
        if (notFound.isNotEmpty) {
          try {
            final profileSnapshot = await _firestore
                .collection('profiles')
                .where(FieldPath.documentId, whereIn: notFound)
                .get();

            for (var doc in profileSnapshot.docs) {
              final data = doc.data();
              data['uid'] = doc.id; // 문서 ID를 uid로 추가
              // blockId 찾기 (blockedId가 doc.id와 일치하는 문서 찾기)
              final blockDoc = snapshot.docs.firstWhere(
                (blockDoc) => blockDoc.data()['blockedId'] == doc.id,
              );
              data['blockId'] = blockDoc.id;
              users.add(data);
              foundIds.add(doc.id);
            }
          } catch (e) {
            print('profiles 컬렉션 조회 오류: $e');
            // 오류가 발생해도 계속 진행
          }
        }
        
        // users/profiles 컬렉션에서 모두 찾지 못한 경우, 최소한의 정보로 추가
        final stillNotFound = batch.where((id) => !foundIds.contains(id)).toList();
        for (var blockedId in stillNotFound) {
          // 최소한의 사용자 정보 생성 (blockedId를 nickname으로 사용)
          final blockDoc = snapshot.docs.firstWhere(
            (doc) => doc.data()['blockedId'] == blockedId,
          );
          users.add({
            'uid': blockedId,
            'nickname': '사용자 ${blockedId.length > 8 ? blockedId.substring(0, 8) + '...' : blockedId}',
            'photoURL': null,
            'photoUrl': null,
            'profileImageUrl': null,
            'blockId': blockDoc.id,
          });
        }
      }

      return users;
    } catch (e) {
      print('차단 목록 조회 오류: $e');
      return [];
    }
  }

  /// 사용자가 차단되었는지 확인
  /// 
  /// [userId] 확인할 사용자 ID
  /// 반환: 차단 여부
  bool isBlocked(String userId) {
    if (!_isInitialized) {
      // 초기화되지 않았으면 동기적으로 확인
      return false;
    }
    return _blockedUserIds.contains(userId);
  }

  /// 차단된 사용자 ID 목록 반환
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  /// 사용자 목록에서 차단된 사용자 필터링
  /// 
  /// [users] 필터링할 사용자 목록 (UserModel 또는 userId를 포함하는 객체)
  /// 반환: 필터링된 사용자 목록
  List<T> filterBlockedUsers<T>(List<T> users) {
    if (!_isInitialized || _blockedUserIds.isEmpty) {
      return users;
    }

    return users.where((user) {
      String? userId;
      
      // UserProfile 타입 체크
      if (user.runtimeType.toString() == 'UserProfile') {
        try {
          final dynamicUser = user as dynamic;
          userId = dynamicUser.uid;
        } catch (e) {
          return true;
        }
      } else if (user.runtimeType.toString() == 'UserModel') {
        // UserModel 타입 체크
        try {
          final dynamicUser = user as dynamic;
          userId = dynamicUser.uid;
        } catch (e) {
          return true;
        }
      } else if (user.runtimeType.toString() == 'UserLocationModel') {
        // UserLocationModel 타입 체크
        try {
          final dynamicUser = user as dynamic;
          userId = dynamicUser.userId;
        } catch (e) {
          return true;
        }
      } else if (user is Map) {
        userId = user['uid'] as String? ?? user['id'] as String?;
      } else {
        // 동적으로 userId 추출 시도
        try {
          final dynamicUser = user as dynamic;
          userId = dynamicUser.uid ?? dynamicUser.userId ?? dynamicUser.id;
        } catch (e) {
          return true; // 추출 실패 시 포함
        }
      }
      
      if (userId == null) return true;
      return !_blockedUserIds.contains(userId);
    }).toList();
  }

  /// 피드 아이템 목록에서 차단된 사용자의 게시물 필터링
  /// 
  /// [items] 필터링할 피드 아이템 목록
  /// 반환: 필터링된 피드 아이템 목록
  List<T> filterBlockedContent<T>(List<T> items) {
    if (!_isInitialized || _blockedUserIds.isEmpty) {
      return items;
    }

    return items.where((item) {
      String? userId;
      
      // FeedItem 타입 체크
      if (item.runtimeType.toString() == 'FeedItem') {
        try {
          final dynamicItem = item as dynamic;
          userId = dynamicItem.userId;
        } catch (e) {
          return true;
        }
      } else if (item is Map) {
        userId = item['userId'] as String?;
      } else {
        // 동적으로 userId 추출 시도
        try {
          final dynamicItem = item as dynamic;
          userId = dynamicItem.userId;
        } catch (e) {
          return true; // 추출 실패 시 포함
        }
      }
      
      if (userId == null) return true;
      return !_blockedUserIds.contains(userId);
    }).toList();
  }
}
