import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 위치 정보 모델
class UserLocationModel {
  final String userId;
  final String? nickname;
  final String? profileImageUrl;
  final double latitude;
  final double longitude;
  final DateTime lastActiveAt;
  final double distanceInMeters; // 현재 사용자로부터의 거리

  UserLocationModel({
    required this.userId,
    this.nickname,
    this.profileImageUrl,
    required this.latitude,
    required this.longitude,
    required this.lastActiveAt,
    required this.distanceInMeters,
  });

  /// Firestore 문서에서 생성
  factory UserLocationModel.fromFirestore(
    DocumentSnapshot doc,
    double currentLat,
    double currentLng,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as GeoPoint?;
    
    if (location == null) {
      throw Exception('Location data is missing');
    }

    final lastActiveAt = (data['lastActiveAt'] as Timestamp?)?.toDate() ?? 
                        DateTime.now();
    
    // 거리 계산 (Haversine formula)
    final distance = _calculateDistance(
      currentLat,
      currentLng,
      location.latitude,
      location.longitude,
    );

    return UserLocationModel(
      userId: doc.id,
      nickname: data['nickname'] as String?,
      profileImageUrl: (data['photoURL'] as String?) ?? (data['photoUrl'] as String?),
      latitude: location.latitude,
      longitude: location.longitude,
      lastActiveAt: lastActiveAt,
      distanceInMeters: distance,
    );
  }

  /// Haversine formula를 사용한 거리 계산 (미터 단위)
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }
}
