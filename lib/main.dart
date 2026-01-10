import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'utils/theme_config.dart';
import 'services/firebase_service.dart';
import 'screens/splash_page.dart';
import 'providers/user_auth_state.dart';
import 'providers/profile_state_manager.dart';
import 'providers/animal_list_provider.dart';
import 'providers/walk_session_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화 (에러 발생 시에도 앱 실행)
  await FirebaseService.initializeFirebaseServices();
  
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
        title: 'PetWalk',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
