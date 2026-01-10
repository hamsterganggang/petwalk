import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

/// 좋아요 기능을 관리하는 서비스 클래스
class LikeService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();

  /// 좋아요 토글 (추가/취소)
  /// 
  /// [walkId] 대상 산책 기록 ID
  /// 반환: 좋아요 상태 (true: 좋아요 추가됨, false: 좋아요 취소됨)
  Future<bool> toggleLike(String walkId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final userId = user.uid;

    try {
      // 먼저 기존 좋아요 문서 확인 (Transaction 외부에서)
      final likeSnapshot = await _firestore
          .collection('likes')
          .where('walkId', isEqualTo: walkId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      final bool isLiked = likeSnapshot.docs.isNotEmpty;
      final walkRef = _firestore.collection('walks').doc(walkId);

      // Transaction을 사용하여 원자적 처리
      return await _firestore.runTransaction<bool>((transaction) async {
        // Walk 문서 확인
        final walkDoc = await transaction.get(walkRef);
        if (!walkDoc.exists) {
          throw Exception('산책 기록을 찾을 수 없습니다.');
        }

        if (isLiked) {
          // 좋아요 취소
          final likeDocId = likeSnapshot.docs.first.id;
          final likeDocRef = _firestore.collection('likes').doc(likeDocId);
          transaction.delete(likeDocRef);
          
          // likeCount 감소
          transaction.update(walkRef, {
            'likeCount': FieldValue.increment(-1),
          });
          
          return false;
        } else {
          // 좋아요 추가
          final newLikeRef = _firestore.collection('likes').doc();
          transaction.set(newLikeRef, {
            'walkId': walkId,
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          // likeCount 증가
          transaction.update(walkRef, {
            'likeCount': FieldValue.increment(1),
          });
          
          return true;
        }
      });
    } catch (e) {
      print('좋아요 토글 오류: $e');
      rethrow;
    }
  }

  /// 현재 사용자가 해당 산책 기록을 좋아요 했는지 확인
  /// 
  /// [walkId] 확인할 산책 기록 ID
  /// 반환: 좋아요 상태 (true: 좋아요 함, false: 좋아요 안 함)
  Future<bool> hasLiked(String walkId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final likeSnapshot = await _firestore
          .collection('likes')
          .where('walkId', isEqualTo: walkId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      return likeSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('좋아요 상태 확인 오류: $e');
      return false;
    }
  }

  /// 여러 산책 기록에 대한 좋아요 상태를 일괄 확인
  /// 
  /// [walkIds] 확인할 산책 기록 ID 목록
  /// 반환: walkId를 키로 하는 Map (true: 좋아요 함, false: 좋아요 안 함)
  Future<Map<String, bool>> checkLikesStatus(List<String> walkIds) async {
    final user = _auth.currentUser;
    if (user == null || walkIds.isEmpty) {
      return {for (var id in walkIds) id: false};
    }

    try {
      final likedWalkIds = <String>{};
      
      // Firestore의 whereIn은 최대 10개까지만 지원하므로 배치로 처리
      for (var i = 0; i < walkIds.length; i += 10) {
        final batch = walkIds.skip(i).take(10).toList();
        final likeSnapshot = await _firestore
            .collection('likes')
            .where('walkId', whereIn: batch)
            .where('userId', isEqualTo: user.uid)
            .get();

        likedWalkIds.addAll(
          likeSnapshot.docs.map((doc) => doc.data()['walkId'] as String),
        );
      }

      return {for (var id in walkIds) id: likedWalkIds.contains(id)};
    } catch (e) {
      print('좋아요 상태 일괄 확인 오류: $e');
      return {for (var id in walkIds) id: false};
    }
  }
}
