import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 유저를 팔로우/언팔로우하는 메인 함수
  Future<void> toggleFollowStatus(String currentUserId, String targetUserId, bool isCurrentlyFollowing) async {
    if (isCurrentlyFollowing) {
      await _unfollowUser(currentUserId, targetUserId);
    } else {
      await _followUser(currentUserId, targetUserId);
    }
  }

  // 팔로우 로직 (트랜잭션 사용)
  Future<void> _followUser(String currentUserId, String targetUserId) async {
    final followDocRef = _firestore.collection('follows').doc('${currentUserId}_$targetUserId');

    await _firestore.runTransaction((transaction) async {
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      // 트랜잭션 내에서 팔로우 문서 생성
      transaction.set(followDocRef, {
        'followerId': currentUserId,
        'followingId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 내(current)가 팔로우하는 사람 수 (followingCount) +1
      transaction.update(currentUserRef, {'followingCount': FieldValue.increment(1)});
      // 상대방(target)의 팔로워 수 (followerCount) +1
      transaction.update(targetUserRef, {'followerCount': FieldValue.increment(1)});
    });
  }

  // 언팔로우 로직 (트랜잭션 사용)
  Future<void> _unfollowUser(String currentUserId, String targetUserId) async {
    final followDocRef = _firestore.collection('follows').doc('${currentUserId}_$targetUserId');

    await _firestore.runTransaction((transaction) async {
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      // 트랜잭션 내에서 팔로우 문서 삭제
      transaction.delete(followDocRef);

      // 내(current)가 팔로우하는 사람 수 (followingCount) -1
      transaction.update(currentUserRef, {'followingCount': FieldValue.increment(-1)});
      // 상대방(target)의 팔로워 수 (followerCount) -1
      transaction.update(targetUserRef, {'followerCount': FieldValue.increment(-1)});
    });
  }

  // 특정 유저를 팔로우하고 있는지 확인
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final followDoc = await _firestore.collection('follows').doc('${currentUserId}_$targetUserId').get();
    return followDoc.exists;
  }

  // 닉네임으로 유저 검색
  Future<List<QueryDocumentSnapshot>> searchUsers(String nickname) async {
    if (nickname.isEmpty) {
      return [];
    }
    final querySnapshot = await _firestore
        .collection('users')
        .where('nickname', isGreaterThanOrEqualTo: nickname)
    // 'isLessThanOrEqualTo'를 'isLessThan'으로 수정하여 정확한 starts-with 검색 구현
        .where('nickname', isLessThan: '$nickname\uf8ff')
        .limit(20)
        .get();
    return querySnapshot.docs;
  }
}
