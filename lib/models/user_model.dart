import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? nickname;
  final String? profileImageUrl;
  final int followerCount;
  final int followingCount;

  UserModel({
    required this.uid,
    this.nickname,
    this.profileImageUrl,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      nickname: data['nickname'] as String?,
      profileImageUrl: data['profileImageUrl'] as String?,
      followerCount: data['followerCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
    );
  }
}
