import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'follow_service.dart';

/// 사용자 차단 서비스 (팔로우 관계 단절 통합)
class BlockService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();
  final FollowService _followService = FollowService();
  
  Set<String> _blockedUserIds = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final user = _auth.currentUser;
    if (user == null) { _blockedUserIds = {}; _isInitialized = true; return; }
    try {
      final snapshot = await _firestore.collection('blocks').where('blockerId', isEqualTo: user.uid).get();
      _blockedUserIds = snapshot.docs.map((doc) => doc.data()['blockedId'] as String).toSet();
      _isInitialized = true;
    } catch (e) {
      _blockedUserIds = {}; _isInitialized = true;
    }
  }

  Future<void> refresh() async { _isInitialized = false; await initialize(); }

  /// 사용자 차단 (팔로우 관계 즉시 단절 포함)
  Future<void> blockUser(String blockedUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    if (user.uid == blockedUserId) throw Exception('자기 자신을 차단할 수 없습니다.');

    try {
      // 1. 이미 차단되어 있는지 확인
      if (_blockedUserIds.contains(blockedUserId)) return;

      // 2. 양방향 팔로우 관계 즉시 삭제 (좋아요 수는 건드리지 않음 - 필터링으로 처리)
      // 이 과정에서 follow_service의 트랜잭션을 호출하여 데이터 일관성 확보
      await _followService.removeAllFollowRelationships(user.uid, blockedUserId);

      // 3. 차단 기록 추가
      await _firestore.collection('blocks').add({
        'blockerId': user.uid,
        'blockedId': blockedUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _blockedUserIds.add(blockedUserId);
    } catch (e) {
      print('사용자 차단 오류: $e');
      rethrow;
    }
  }

  /// 차단 해제 (팔로우는 복구되지 않음)
  Future<void> unblockUser(String blockedUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');

    try {
      final blockDocs = await _firestore.collection('blocks')
          .where('blockerId', isEqualTo: user.uid)
          .where('blockedId', isEqualTo: blockedUserId).get();

      final batch = _firestore.batch();
      for (var doc in blockDocs.docs) { batch.delete(doc.reference); }
      await batch.commit();

      _blockedUserIds.remove(blockedUserId);
    } catch (e) {
      print('차단 해제 오류: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getBlockedList() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    try {
      final snapshot = await _firestore.collection('blocks').where('blockerId', isEqualTo: user.uid).get();
      if (snapshot.docs.isEmpty) return [];
      final blockedIds = snapshot.docs.map((doc) => doc.data()['blockedId'] as String).toList();
      final users = <Map<String, dynamic>>[];
      for (var i = 0; i < blockedIds.length; i += 10) {
        final batch = blockedIds.skip(i).take(10).toList();
        final profileSnapshot = await _firestore.collection('profiles').where(FieldPath.documentId, whereIn: batch).get();
        for (var doc in profileSnapshot.docs) {
          final data = doc.data();
          data['uid'] = doc.id;
          final blockDoc = snapshot.docs.firstWhere((b) => b.data()['blockedId'] == doc.id);
          data['blockId'] = blockDoc.id;
          users.add(data);
        }
      }
      return users;
    } catch (e) { return []; }
  }

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);

  List<T> filterBlockedUsers<T>(List<T> users) {
    if (!_isInitialized || _blockedUserIds.isEmpty) return users;
    return users.where((user) {
      String? userId;
      if (user is Map) userId = user['uid'] as String? ?? user['userId'];
      else {
        try { final d = user as dynamic; userId = d.uid ?? d.userId; } catch (_) {}
      }
      return userId == null || !_blockedUserIds.contains(userId);
    }).toList();
  }

  List<T> filterBlockedContent<T>(List<T> items) {
    if (!_isInitialized || _blockedUserIds.isEmpty) return items;
    return items.where((item) {
      String? userId;
      if (item is Map) userId = item['userId'] as String?;
      else { try { userId = (item as dynamic).userId; } catch (_) {} }
      return userId == null || !_blockedUserIds.contains(userId);
    }).toList();
  }
}
