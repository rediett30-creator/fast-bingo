import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_background.dart';
import 'admin_dashboard_screen.dart';
import 'dashboard_screen.dart';

/// Initial splash / auth screen.
/// Automatically verifies stored JWT or authenticates via Telegram WebApp initData.
/// Has no manual login form — auth feels instant on repeat visits.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthState>().initAuth();
    });
  }

  void _onAuthStateChanged(AuthState authState) {
    if (authState.isAuthenticated) {
      if (authState.role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        // Trigger navigation when authenticated
        if (authState.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onAuthStateChanged(authState);
          });
        }

        return Scaffold(
          body: GradientBackground(
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Bingo Logo / Badge ───────────────────────────────
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.bingoButton,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF86E863),
                              AppTheme.bingoButton,
                              Color(0xFF388E1E),
                            ],
                          ),
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.bingoButton.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.casino_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── App Title ────────────────────────────────────────
                      Text(
                        'FAST BINGO',
                        style: AppTheme.headerStyle.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.4),
                              offset: const Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Real-time Telegram Bingo',
                        style: AppTheme.subheaderStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ── Loading / Error State ─────────────────────────────
                      if (authState.isLoading || authState.status == AuthStatus.initial) ...[
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Connecting to Telegram...',
                          style: AppTheme.emptyStateStyle.copyWith(fontSize: 14),
                        ),
                      ] else if (authState.status == AuthStatus.error ||
                          authState.status == AuthStatus.unauthenticated) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.errorRed.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.errorRed,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                authState.errorMessage ?? 'Authentication required',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<AuthState>().initAuth();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.bingoButton,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
