import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart';

/// Firebase 서비스 초기화 및 설정 클래스
class FirebaseService {
  static FirebaseApp? firebaseApp;
  static FirebaseFirestore? firestoreInstance;
  static FirebaseAuth? authInstance;
  static FirebaseStorage? storageInstance;

  /// Firebase 서비스 초기화
  /// 
  /// 에러 발생 시에도 앱이 실행되도록 예외 처리를 포함합니다.
  static Future<void> initializeFirebaseServices() async {
    try {
      // Firebase 초기화
      firebaseApp = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Firestore 초기화 및 오프라인 모드 설정
      await setupFirestoreConfig();

      // Firebase Auth 인스턴스 가져오기
      authInstance = FirebaseAuth.instance;

      // Firebase Storage 인스턴스 가져오기
      storageInstance = FirebaseStorage.instance;

      print('Firebase initialized successfully');
    } catch (e) {
      print('Error initializing Firebase: $e');
      // 에러 발생 시에도 앱은 계속 실행됨
    }
  }

  /// Firestore 설정 (오프라인 캐시 활성화)
  static Future<void> setupFirestoreConfig() async {
    try {
      firestoreInstance = FirebaseFirestore.instance;

      // 오프라인 모드 활성화
      // PERSISTENCE_ENABLED는 기본적으로 활성화되어 있지만 명시적으로 설정
      await firestoreInstance!.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );

      print('Firestore configured with offline persistence');
    } catch (e) {
      print('Error configuring Firestore: $e');
      // 오프라인 모드 활성화 실패 시에도 계속 진행
      if (firestoreInstance == null) {
        firestoreInstance = FirebaseFirestore.instance;
      }
    }
  }

  /// Firestore 인스턴스 가져오기
  static FirebaseFirestore getFirestore() {
    if (firestoreInstance == null) {
      firestoreInstance = FirebaseFirestore.instance;
    }
    return firestoreInstance!;
  }

  /// Firebase Auth 인스턴스 가져오기
  static FirebaseAuth getAuth() {
    if (authInstance == null) {
      authInstance = FirebaseAuth.instance;
    }
    return authInstance!;
  }

  /// Firebase Storage 인스턴스 가져오기
  static FirebaseStorage getStorage() {
    if (storageInstance == null) {
      storageInstance = FirebaseStorage.instance;
    }
    return storageInstance!;
  }

  /// Firebase 연결 상태 확인
  static bool isInitialized() {
    return firebaseApp != null;
  }
}
