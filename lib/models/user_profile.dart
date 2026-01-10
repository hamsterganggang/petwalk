import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String nickname;
  final String? photoUrl;
  final String bio;
  final bool locationEnabled;
  final bool notificationsEnabled; // 알림 설정 추가
  final int followers;
  final int following;

  UserProfile({
    required this.uid,
    required this.email,
    required this.nickname,
    this.photoUrl,
    this.bio = '',
    required this.locationEnabled,
    this.notificationsEnabled = true, // 기본값 true
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
      followers: followers ?? this.followers,
      following: following ?? this.following,
    );
  }
}
