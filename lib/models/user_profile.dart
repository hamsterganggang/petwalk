import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String nickname;
  final String? photoUrl;
  final String bio;
  final bool locationEnabled; // 탐색 위치 표시 여부
  final bool notificationsEnabled;
  final bool isPrivate; // 프로필 비공개 여부 추가
  final int followers;
  final int following;

  UserProfile({
    required this.uid,
    required this.email,
    required this.nickname,
    this.photoUrl,
    this.bio = '',
    required this.locationEnabled,
    this.notificationsEnabled = true,
    this.isPrivate = false, // 기본값 공개
    this.followers = 0,
    this.following = 0,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      nickname: data['nickname'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'] ?? '',
      locationEnabled: data['locationEnabled'] ?? false,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      isPrivate: data['isPrivate'] ?? false,
      followers: (data['followers'] ?? 0) as int,
      following: (data['following'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'photoUrl': photoUrl,
      'bio': bio,
      'locationEnabled': locationEnabled,
      'notificationsEnabled': notificationsEnabled,
      'isPrivate': isPrivate,
      'followers': followers,
      'following': following,
    };
  }

  UserProfile copyWith({
    String? nickname,
    String? photoUrl,
    String? bio,
    bool? locationEnabled,
    bool? notificationsEnabled,
    bool? isPrivate,
    int? followers,
    int? following,
  }) {
    return UserProfile(
      uid: this.uid,
      email: this.email,
      nickname: nickname ?? this.nickname,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isPrivate: isPrivate ?? this.isPrivate,
      followers: followers ?? this.followers,
      following: following ?? this.following,
    );
  }
}
