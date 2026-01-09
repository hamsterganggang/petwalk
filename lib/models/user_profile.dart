import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String nickname;
  final String? photoUrl;
  final bool locationEnabled;

  UserProfile({
    required this.uid,
    required this.email,
    required this.nickname,
    this.photoUrl,
    required this.locationEnabled,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      nickname: data['nickname'] ?? '',
      photoUrl: data['photoUrl'],
      locationEnabled: data['locationEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'photoUrl': photoUrl,
      'locationEnabled': locationEnabled,
    };
  }

  UserProfile copyWith({
    String? nickname,
    String? photoUrl,
    bool? locationEnabled,
  }) {
    return UserProfile(
      uid: this.uid,
      email: this.email,
      nickname: nickname ?? this.nickname,
      photoUrl: photoUrl ?? this.photoUrl,
      locationEnabled: locationEnabled ?? this.locationEnabled,
    );
  }
}