import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'utils/theme_config.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_page.dart';
import 'providers/user_auth_state.dart';
import 'providers/profile_state_manager.dart';
import 'providers/animal_list_provider.dart';
import 'providers/walk_session_provider.dart';

// 백그라운드 메시지 핸들러 (최상위에 있어야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseService.initializeFirebaseServices();
  print("백그라운드 메시지 수신: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  await FirebaseService.initializeFirebaseServices();
  
  // FCM 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // 알림 서비스 초기화
  await NotificationService.initialize();
  
  // intl 패키지 로케일 데이터 초기화 (한국어 지원)
  await initializeDateFormatting('ko_KR', null);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserAuthState()),
        ChangeNotifierProvider(create: (_) => ProfileStateManager()),
        ChangeNotifierProvider(create: (_) => AnimalListProvider()),
        ChangeNotifierProvider(create: (_) => WalkSessionProvider()),
      ],
      child: MaterialApp(
        title: '3팀 프로젝트',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
