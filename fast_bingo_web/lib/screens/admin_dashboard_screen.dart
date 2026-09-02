import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ws_service.dart';
import '../state/admin_state.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/admin/create_game_form.dart';
import '../widgets/admin/manage_game_panel.dart';
import '../widgets/gradient_background.dart';
import '../widgets/stat_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authState = context.read<AuthState>();
    context.read<AdminState>().loadAdminData(authState.token);
  }

  @override
  Widget build(BuildContext context) {
    final adminState = context.watch<AdminState>();
    final authState = context.watch<AuthState>();

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopAdminBar(context, adminState, authState),

              Expanded(
                child: adminState.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        color: AppTheme.bingoButton,
                        backgroundColor: AppTheme.badgeBackground,
                        child: adminState.currentGame == null
                            ? const CreateGameForm()
                            : ManageGamePanel(game: adminState.currentGame!),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAdminBar(
    BuildContext context,
    AdminState adminState,
    AuthState authState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.bingoO,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FAST BINGO',
                    style: AppTheme.headerStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Text(
                    'Admin Control Console',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFD54F),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Row(
            children: [
              if (adminState.connectionState ==
                  WsConnectionState.reconnecting) ...[
                const StatBadge(
                  icon: Icons.sync,
                  text: 'Reconnecting',
                  textColor: AppTheme.bingoI,
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white70,
                  size: 20,
                ),
                tooltip: 'Refresh Game State',
                onPressed: _loadData,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
