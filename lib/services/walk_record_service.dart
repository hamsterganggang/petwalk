import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'firebase_service.dart';

class WalkRecordService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseAuth _auth = FirebaseService.getAuth();

  Future<void> saveWalkData({
    required DateTime startTime,
    required DateTime endTime,
    required double totalDistance,
    required List<LatLng> routeCoordinates,
    required String memo,
    required String mood,
    List<String> selectedPetNames = const [],
    List<String> imageUrls = const [],
    bool isPublic = true, // 공개 여부 기본값 추가
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final walkData = {
      'userId': user.uid,
      'startTime': startTime,
      'endTime': endTime,
      'totalDistance': totalDistance,
      'memo': memo,
      'mood': mood,
      'petNames': selectedPetNames,
      'imageUrls': imageUrls,
      'isPublic': isPublic, // 필드 추가
      'route': routeCoordinates.map((point) => {
        'lat': point.latitude,
        'lng': point.longitude,
      }).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('walks').add(walkData);
    } catch (e) {
      print('Error saving walk data: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> fetchWalkHistory() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('walks')
        .where('userId', isEqualTo: user.uid)
        .orderBy('startTime', descending: true)
        .snapshots();
  }

  /// 기록 삭제
  Future<void> deleteWalkRecord(String docId) async {
    try {
      await _firestore.collection('walks').doc(docId).delete();
    } catch (e) {
      print('Error deleting walk record: $e');
      rethrow;
    }
  }

  /// 공개 여부 상태 변경
  Future<void> updateVisibility(String docId, bool isPublic) async {
    try {
      await _firestore.collection('walks').doc(docId).update({
        'isPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating visibility: $e');
      rethrow;
    }
  }
}
