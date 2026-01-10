import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

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
      final currentUserRef = _firestore.collection('profiles').doc(currentUserId);
      final targetUserRef = _firestore.collection('profiles').doc(targetUserId);

      // 트랜잭션 내에서 팔로우 문서 생성
      transaction.set(followDocRef, {
        'followerId': currentUserId,
        'followingId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 내(current)가 팔로우하는 사람 수 (following) +1
      transaction.update(currentUserRef, {'following': FieldValue.increment(1)});
      // 상대방(target)의 팔로워 수 (followers) +1
      transaction.update(targetUserRef, {'followers': FieldValue.increment(1)});
    });
  }

  // 언팔로우 로직 (트랜잭션 사용)
  Future<void> _unfollowUser(String currentUserId, String targetUserId) async {
    final followDocRef = _firestore.collection('follows').doc('${currentUserId}_$targetUserId');

    await _firestore.runTransaction((transaction) async {
      final currentUserRef = _firestore.collection('profiles').doc(currentUserId);
      final targetUserRef = _firestore.collection('profiles').doc(targetUserId);

      // 트랜잭션 내에서 팔로우 문서 삭제
      transaction.delete(followDocRef);

      // 내(current)가 팔로우하는 사람 수 (following) -1
      transaction.update(currentUserRef, {'following': FieldValue.increment(-1)});
      // 상대방(target)의 팔로워 수 (followers) -1
      transaction.update(targetUserRef, {'followers': FieldValue.increment(-1)});
    });
  }

  // 특정 유저를 팔로우하고 있는지 확인
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final followDoc = await _firestore.collection('follows').doc('${currentUserId}_$targetUserId').get();
    return followDoc.exists;
  }

  // 상대방이 나를 팔로우하고 있는지 확인
  Future<bool> isFollowedBy(String currentUserId, String targetUserId) async {
    final followDoc = await _firestore.collection('follows').doc('${targetUserId}_$currentUserId').get();
    return followDoc.exists;
  }

  // 양방향 팔로우 관계 모두 취소 (차단 시 사용)
  /// [currentUserId] 현재 사용자 ID
  /// [targetUserId] 차단할 사용자 ID
  Future<void> removeAllFollowRelationships(String currentUserId, String targetUserId) async {
    await _firestore.runTransaction((transaction) async {
      final currentUserRef = _firestore.collection('profiles').doc(currentUserId);
      final targetUserRef = _firestore.collection('profiles').doc(targetUserId);

      // 1. 내가 상대방을 팔로우하는 경우 취소
      final myFollowDocRef = _firestore.collection('follows').doc('${currentUserId}_$targetUserId');
      final myFollowDoc = await myFollowDocRef.get();

      if (myFollowDoc.exists) {
        transaction.delete(myFollowDocRef);
        transaction.update(currentUserRef, {'following': FieldValue.increment(-1)});
        transaction.update(targetUserRef, {'followers': FieldValue.increment(-1)});
      }

      // 2. 상대방이 나를 팔로우하는 경우 취소
      final theirFollowDocRef = _firestore.collection('follows').doc('${targetUserId}_$currentUserId');
      final theirFollowDoc = await theirFollowDocRef.get();

      if (theirFollowDoc.exists) {
        transaction.delete(theirFollowDocRef);
        transaction.update(targetUserRef, {'following': FieldValue.increment(-1)});
        transaction.update(currentUserRef, {'followers': FieldValue.increment(-1)});
      }
    });
  }

  // 닉네임으로 유저 검색
  Future<List<QueryDocumentSnapshot>> searchUsers(String nickname) async {
    if (nickname.isEmpty) {
      return [];
    }
    final querySnapshot = await _firestore
        .collection('profiles')
        .where('nickname', isGreaterThanOrEqualTo: nickname)
        .where('nickname', isLessThan: '$nickname\uf8ff')
        .limit(20)
        .get();
    return querySnapshot.docs;
  }

  // 팔로워 목록 가져오기
  Future<List<UserProfile>> getFollowers(String userId) async {
    try {
      final followsSnapshot = await _firestore
          .collection('follows')
          .where('followingId', isEqualTo: userId)
          .get();

      List<UserProfile> followers = [];

      for (final followDoc in followsSnapshot.docs) {
        final followerId = followDoc['followerId'] as String;
        final userDoc = await _firestore.collection('profiles').doc(followerId).get();

        if (userDoc.exists) {
          followers.add(UserProfile.fromFirestore(userDoc));
        }
      }

      // 팔로워 수가 많은 순서로 정렬 (선택적)
      followers.sort((a, b) => b.followers.compareTo(a.followers));

      return followers;
    } catch (e) {
      print('팔로워 목록 가져오기 오류: $e');
      return [];
    }
  }

  // 팔로잉 목록 가져오기
  Future<List<UserProfile>> getFollowing(String userId) async {
    try {
      final followsSnapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .get();

      List<UserProfile> following = [];

      for (final followDoc in followsSnapshot.docs) {
        final followingId = followDoc['followingId'] as String;
        final userDoc = await _firestore.collection('profiles').doc(followingId).get();

        if (userDoc.exists) {
          following.add(UserProfile.fromFirestore(userDoc));
        }
      }

      // 팔로잉 수가 많은 순서로 정렬 (선택적)
      following.sort((a, b) => b.following.compareTo(a.following));

      return following;
    } catch (e) {
      print('팔로잉 목록 가져오기 오류: $e');
      return [];
    }
  }
}
