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
  static bool _isInitializing = false;
  static bool _isInitialized = false;

  /// Firebase 서비스 초기화
  /// 
  /// 에러 발생 시에도 앱이 실행되도록 예외 처리를 포함합니다.
  static Future<void> initializeFirebaseServices() async {
    // 이미 초기화되었거나 초기화 중이면 스킵
    if (_isInitialized || _isInitializing) {
      return;
    }

    _isInitializing = true;

    try {
      // Firebase가 이미 초기화되어 있는지 확인
      if (Firebase.apps.isEmpty) {
        // Firebase 초기화
        firebaseApp = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('Firebase initialized successfully');
      } else {
        // 이미 초기화되어 있으면 기존 앱 사용
        try {
          firebaseApp = Firebase.app();
          print('Firebase already initialized, using existing app');
        } catch (e) {
          // DEFAULT 앱이 없는 경우 새로 초기화 시도
          if (e.toString().contains('No Firebase App')) {
            firebaseApp = await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
            print('Firebase initialized after checking existing apps');
          } else {
            rethrow;
          }
        }
      }

      // Firestore 초기화 및 오프라인 모드 설정
      await setupFirestoreConfig();

      // Firebase Auth 인스턴스 가져오기
      authInstance = FirebaseAuth.instance;

      // Firebase Storage 인스턴스 가져오기
      storageInstance = FirebaseStorage.instance;

      _isInitialized = true;
    } catch (e) {
      // 중복 앱 에러는 무시 (이미 초기화된 경우)
      if (e.toString().contains('duplicate-app') || 
          e.toString().contains('already exists')) {
        try {
          firebaseApp = Firebase.app();
          authInstance = FirebaseAuth.instance;
          storageInstance = FirebaseStorage.instance;
          await setupFirestoreConfig();
          _isInitialized = true;
          print('Firebase already initialized, recovered from duplicate error');
        } catch (recoveryError) {
          print('Error recovering Firebase: $recoveryError');
        }
      } else {
        print('Error initializing Firebase: $e');
      }
      // 에러 발생 시에도 앱은 계속 실행됨
      // 인스턴스가 null이어도 getAuth(), getFirestore() 등에서 자동으로 생성됨
    } finally {
      _isInitializing = false;
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
      firestoreInstance ??= FirebaseFirestore.instance;
    }
  }

  /// Firestore 인스턴스 가져오기
  static FirebaseFirestore getFirestore() {
    firestoreInstance ??= FirebaseFirestore.instance;
    return firestoreInstance!;
  }

  /// Firebase Auth 인스턴스 가져오기
  static FirebaseAuth getAuth() {
    authInstance ??= FirebaseAuth.instance;
    return authInstance!;
  }

  /// Firebase Storage 인스턴스 가져오기
  static FirebaseStorage getStorage() {
    storageInstance ??= FirebaseStorage.instance;
    return storageInstance!;
  }

  /// Firebase 연결 상태 확인
  static bool isInitialized() {
    return firebaseApp != null;
  }
}
