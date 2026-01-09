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
    List<String> imageUrls = const [],
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
      'imageUrls': imageUrls,
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

  Future<void> deleteWalkRecord(String docId) async {
    await _firestore.collection('walks').doc(docId).delete();
  }
}
