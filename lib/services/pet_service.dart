import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/pet.dart';
import '../services/firebase_service.dart';

class PetService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseStorage _storage = FirebaseService.getStorage();
  static const String _collectionName = 'pets';

  /// 반려동물 등록
  Future<String> createPet({
    required String ownerId,
    required String name,
    required String type,
    String? breed,
    required int age,
    required String gender,
    File? imageFile,
    bool isRepresentative = false,
  }) async {
    try {
      String? imageUrl;
      
      // 이미지 업로드
      if (imageFile != null) {
        imageUrl = await _uploadPetImage(ownerId, imageFile);
      }

      // Firestore에 저장
      final docRef = await _firestore.collection(_collectionName).add({
        'ownerId': ownerId,
        'name': name,
        'type': type,
        'breed': breed,
        'age': age,
        'gender': gender,
        'imageUrl': imageUrl,
        'isRepresentative': isRepresentative,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 대표 반려동물로 설정된 경우, 다른 반려동물들의 대표 상태 해제
      if (isRepresentative) {
        await _setAsRepresentative(docRef.id, ownerId);
      }

      return docRef.id;
    } catch (e) {
      print('반려동물 등록 오류: $e');
      rethrow;
    }
  }

  /// 반려동물 정보 업데이트
  Future<bool> updatePet({
    required String petId,
    String? name,
    String? type,
    String? breed,
    int? age,
    String? gender,
    File? imageFile,
    bool? isRepresentative,
  }) async {
    try {
      String? imageUrl;
      
      // 이미지 업로드
      if (imageFile != null) {
        final pet = await getPet(petId);
        if (pet != null) {
          imageUrl = await _uploadPetImage(pet.ownerId, imageFile);
        }
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (type != null) updateData['type'] = type;
      if (breed != null) updateData['breed'] = breed;
      if (age != null) updateData['age'] = age;
      if (gender != null) updateData['gender'] = gender;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (isRepresentative != null) {
        updateData['isRepresentative'] = isRepresentative;
        
        // 대표 반려동물로 설정된 경우
        if (isRepresentative) {
          final pet = await getPet(petId);
          if (pet != null) {
            await _setAsRepresentative(petId, pet.ownerId);
          }
        }
      }

      await _firestore.collection(_collectionName).doc(petId).update(updateData);
      return true;
    } catch (e) {
      print('반려동물 업데이트 오류: $e');
      return false;
    }
  }

  /// 반려동물 정보 가져오기
  Future<Pet?> getPet(String petId) async {
    try {
      final docSnapshot = await _firestore.collection(_collectionName).doc(petId).get();
      
      if (!docSnapshot.exists) {
        return null;
      }

      return Pet.fromFirestore(docSnapshot);
    } catch (e) {
      print('반려동물 정보 가져오기 오류: $e');
      return null;
    }
  }

  /// 사용자의 모든 반려동물 가져오기
  Future<List<Pet>> getUserPets(String ownerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Pet.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('사용자 반려동물 목록 가져오기 오류: $e');
      return [];
    }
  }

  /// 대표 반려동물 가져오기
  Future<Pet?> getRepresentativePet(String ownerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .where('isRepresentative', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return Pet.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      print('대표 반려동물 가져오기 오류: $e');
      return null;
    }
  }

  /// 반려동물 삭제
  Future<bool> deletePet(String petId) async {
    try {
      await _firestore.collection(_collectionName).doc(petId).delete();
      return true;
    } catch (e) {
      print('반려동물 삭제 오류: $e');
      return false;
    }
  }

  /// 반려동물 이미지 업로드
  Future<String> _uploadPetImage(String ownerId, File imageFile) async {
    try {
      final storageRef = _storage
          .ref()
          .child('pets/$ownerId/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(imageFile);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('반려동물 이미지 업로드 오류: $e');
      rethrow;
    }
  }

  /// 대표 반려동물 설정
  Future<void> _setAsRepresentative(String petId, String ownerId) async {
    try {
      // 해당 사용자의 다른 모든 반려동물의 대표 상태 해제
      final batch = _firestore.batch();
      
      final otherPetsSnapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .where('isRepresentative', isEqualTo: true)
          .get();

      for (final doc in otherPetsSnapshot.docs) {
        if (doc.id != petId) {
          batch.update(doc.reference, {'isRepresentative': false});
        }
      }

      // 선택한 반려동물을 대표로 설정
      batch.update(_firestore.collection(_collectionName).doc(petId), {
        'isRepresentative': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      print('대표 반려동물 설정 오류: $e');
      rethrow;
    }
  }
}
