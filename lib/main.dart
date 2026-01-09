import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/theme_config.dart';
import 'services/firebase_service.dart';
import 'screens/splash_page.dart';
import 'providers/user_auth_state.dart';
import 'providers/profile_state_manager.dart';
import 'providers/animal_list_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화 (에러 발생 시에도 앱 실행)
  await FirebaseService.initializeFirebaseServices();
  
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
