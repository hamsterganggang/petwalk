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
  Timer? _locationUpdateTimer;
  
  static const double _searchRadiusInMeters = 1000.0; // 1km
  static const Duration _locationUpdateInterval = Duration(seconds: 30);
  static const int _minDistanceForUpdate = 10; // 10m 이동 시 업데이트

  /// 내 위치를 Firestore에 업데이트
  /// 
  /// [position] 현재 위치
  /// [isWalking] 산책 중 여부
  Future<void> updateUserLocation(Position position, bool isWalking) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // profiles 컬렉션에 위치 정보 저장 (문서가 없으면 생성, 있으면 업데이트)
      await _firestore.collection('profiles').doc(user.uid).set({
        'location': GeoPoint(position.latitude, position.longitude),
        'isWalking': isWalking,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('위치 업데이트 오류: $e');
    }
  }

  /// 산책 종료 시 위치 정보 초기화
  Future<void> stopWalking() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // profiles 컬렉션에 isWalking 상태 업데이트
      await _firestore.collection('profiles').doc(user.uid).set({
        'isWalking': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('산책 종료 처리 오류: $e');
    }
  }

  /// 주변 산책러 탐색 스트림
  /// 
  /// [currentPosition] 현재 위치
  /// 반환: 주변 산책러 목록 스트림
  Stream<List<UserLocationModel>> findNearbyWalkers(Position currentPosition) {
    final controller = StreamController<List<UserLocationModel>>();
    
    // Firestore에서 산책 중인 사용자 스트림 구독 (profiles 컬렉션에서 조회)
    _walkersSubscription = _firestore
        .collection('profiles')
        .where('isWalking', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      try {
        final nearbyWalkers = <UserLocationModel>[];
        
        for (var doc in snapshot.docs) {
          // 현재 사용자는 제외
          if (doc.id == _auth.currentUser?.uid) continue;
          
          try {
            final userLocation = UserLocationModel.fromFirestore(
              doc,
              currentPosition.latitude,
              currentPosition.longitude,
            );
            
            // 1km 이내만 필터링
            if (userLocation.distanceInMeters <= _searchRadiusInMeters) {
              nearbyWalkers.add(userLocation);
            }
          } catch (e) {
            // 위치 데이터가 없는 경우 무시
            print('사용자 위치 파싱 오류: ${doc.id} - $e');
          }
        }
        
        // 거리순으로 정렬
        nearbyWalkers.sort((a, b) => 
            a.distanceInMeters.compareTo(b.distanceInMeters));
        
        controller.add(nearbyWalkers);
      } catch (e) {
        print('주변 사용자 필터링 오류: $e');
        controller.add([]);
      }
    });

    return controller.stream;
  }

  /// 위치 업데이트 시작 (산책 중일 때)
  /// 
  /// [onLocationUpdate] 위치 업데이트 콜백
  void startLocationUpdates(void Function(Position) onLocationUpdate) {
    _stopLocationUpdates(); // 기존 구독 정리

    Position? lastPosition;
    
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _minDistanceForUpdate,
      ),
    ).listen((position) {
      lastPosition = position;
      onLocationUpdate(position);
    });

    // 주기적으로 위치 업데이트 (이동 거리가 적어도)
    _locationUpdateTimer = Timer.periodic(_locationUpdateInterval, (timer) {
      if (lastPosition != null) {
        onLocationUpdate(lastPosition!);
      }
    });
  }

  /// 위치 업데이트 중지
  void stopLocationUpdates() {
    _stopLocationUpdates();
  }

  void _stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  /// 리소스 정리
  void dispose() {
    _stopLocationUpdates();
    _walkersSubscription?.cancel();
    _walkersSubscription = null;
  }
}
