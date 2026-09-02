import 'package:fast_bingo_web/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_telegram_miniapp/flutter_telegram_miniapp.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/ws_service.dart';
import 'state/admin_state.dart';
import 'state/auth_state.dart';
import 'state/buy_cards_state.dart';
import 'state/game_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    WebApp().init();
  } catch (e) {
    debugPrint('WebApp init error (e.g. running outside Telegram): $e');
  }

  final apiService = ApiService();
  final authService = AuthService();
  final wsService = WsService();
  final soundService = SoundService(wsService: wsService);
  soundService.start();

  runApp(
    MultiProvider(
      providers: [
        // Services
        Provider<ApiService>.value(value: apiService),
        Provider<AuthService>.value(value: authService),
        Provider<WsService>.value(value: wsService),
        Provider<SoundService>.value(value: soundService),

        ChangeNotifierProvider<AuthState>(
          create: (_) =>
              AuthState(apiService: apiService, authService: authService),
        ),
        ChangeNotifierProvider<GameState>(
          create: (_) =>
              GameState(apiService: apiService, wsService: wsService),
        ),
        ChangeNotifierProvider<BuyCardsState>(
          create: (_) => BuyCardsState(apiService: apiService),
        ),
        ChangeNotifierProvider<AdminState>(
          create: (_) =>
              AdminState(apiService: apiService, wsService: wsService),
        ),
      ],
      child: const FastBingoApp(),
    ),
  );
}

class FastBingoApp extends StatelessWidget {
  const FastBingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fast Bingo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const SplashScreen(),
    );
  }
}
