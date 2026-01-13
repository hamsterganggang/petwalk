import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_location_model.dart';
import 'firebase_service.dart';

/// 위치 기반 쿼리 서비스
class LocationQueryService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<QuerySnapshot>? _walkersSubscription;
  StreamSubscription<QuerySnapshot>? _friendsSubscription;
  Timer? _locationUpdateTimer;
  
  static const double _searchRadiusInMeters = 1000.0; // 1km
  static const Duration _locationUpdateInterval = Duration(seconds: 30);
  static const int _minDistanceForUpdate = 10; // 10m 이동 시 업데이트

  /// 내 위치를 Firestore에 업데이트
  Future<void> updateUserLocation(Position position, bool isWalking) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('profiles').doc(user.uid).set({
        'location': GeoPoint(position.latitude, position.longitude),
        'isWalking': isWalking,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('위치 업데이트 오류: $e');
    }
  }

  /// 주변 사용자 탐색 스트림 (1km 이내)
  Stream<List<UserLocationModel>> findNearbyWalkers(Position currentPosition) {
    final controller = StreamController<List<UserLocationModel>>();
    
    _walkersSubscription = _firestore
        .collection('profiles')
        .snapshots()
        .listen((snapshot) {
      try {
        final nearbyWalkers = <UserLocationModel>[];
        for (var doc in snapshot.docs) {
          if (doc.id == _auth.currentUser?.uid) continue;
          final data = doc.data();
          if (data['location'] == null) continue;
          
          final userLocation = UserLocationModel.fromFirestore(
            doc,
            currentPosition.latitude,
            currentPosition.longitude,
          );
          
          if (userLocation.distanceInMeters <= _searchRadiusInMeters) {
            nearbyWalkers.add(userLocation);
          }
        }
        nearbyWalkers.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
        controller.add(nearbyWalkers);
      } catch (e) {
        controller.add([]);
      }
    });

    return controller.stream;
  }

  /// 맞팔 친구 위치 탐색 스트림 (거리 제한 없음)
  Stream<List<UserLocationModel>> findMutualFollowers(Position currentPosition) {
    final controller = StreamController<List<UserLocationModel>>();
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    _friendsSubscription = _firestore
        .collection('profiles')
        .snapshots()
        .listen((snapshot) async {
      try {
        final followsSnapshot = await _firestore.collection('follows').where('followerId', isEqualTo: userId).get();
        final followersSnapshot = await _firestore.collection('follows').where('followingId', isEqualTo: userId).get();

        final followingIds = followsSnapshot.docs.map((doc) => doc.data()['followingId'] as String).toSet();
        final followerIds = followersSnapshot.docs.map((doc) => doc.data()['followerId'] as String).toSet();

        final mutualIds = followingIds.intersection(followerIds);

        final friends = <UserLocationModel>[];
        for (var doc in snapshot.docs) {
          if (mutualIds.contains(doc.id)) {
            final data = doc.data();
            if (data['location'] == null) continue;
            
            friends.add(UserLocationModel.fromFirestore(
              doc,
              currentPosition.latitude,
              currentPosition.longitude,
            ));
          }
        }
        friends.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
        controller.add(friends);
      } catch (e) {
        print('맞팔 친구 필터링 오류: $e');
        controller.add([]);
      }
    });

    return controller.stream;
  }

  /// 위치 업데이트 시작
  void startLocationUpdates(void Function(Position) onLocationUpdate) {
    _stopLocationUpdates();
    Position? lastPosition;
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _minDistanceForUpdate),
    ).listen((position) {
      lastPosition = position;
      onLocationUpdate(position);
    });
    _locationUpdateTimer = Timer.periodic(_locationUpdateInterval, (timer) {
      if (lastPosition != null) onLocationUpdate(lastPosition!);
    });
  }

  /// 위치 업데이트 중지 (외부 호출용)
  void stopLocationUpdates() {
    _stopLocationUpdates();
  }

  /// 내부 업데이트 중지 로직
  void _stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  void dispose() {
    _stopLocationUpdates();
    _walkersSubscription?.cancel();
    _friendsSubscription?.cancel();
  }
}
