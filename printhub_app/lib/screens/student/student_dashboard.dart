import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'upload_screen.dart';

class StudentDashboard extends StatefulWidget {
  final bool isFaculty;
  const StudentDashboard({super.key, this.isFaculty = false});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  UserModel? _user;
  String? _token;
  double _wallet = 0;
  SettingsModel _settings = const SettingsModel();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _token = await AuthService.getToken();
    _user  = await AuthService.getUser();
    try {
      final results = await Future.wait([
        ApiService.getWallet(_token!),
        ApiService.getSettings(),
      ]);
      setState(() {
        _wallet   = ((results[0] as Map)['wallet'] ?? 0).toDouble();
        _settings = results[1] as SettingsModel;
        _loading  = false;
      });
    } catch (_) {
      setState(() { _wallet = _user?.wallet ?? 0; _loading = false; });
    }
  }

  Future<void> _logout() async {
    await AuthService.clearSession();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppTheme.primary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: _logout,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Hello, ${_user?.name ?? 'Student'} 👋',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(_user?.email ?? '',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                            if ((_user?.section ?? '').isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(_user!.section,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _WalletCard(wallet: _wallet, settings: _settings, isFaculty: widget.isFaculty),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Quick Actions',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          ),
                          const SizedBox(height: 12),
                          _ActionCard(
                            icon: Icons.upload_file_rounded,
                            title: 'Upload & Print',
                            subtitle: widget.isFaculty
                                ? 'Free printing — choose your printer'
                                : 'Select a PDF with custom print options',
                            color: AppTheme.primary,
                            onTap: () async {
                              final result = await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => UploadScreen(
                                    token: _token!,
                                    wallet: _wallet,
                                    settings: _settings,
                                    isFaculty: widget.isFaculty,
                                  )));
                              if (result == true) _loadData();
                            },
                          ),
                          const SizedBox(height: 12),
                          _PermissionsCard(settings: _settings),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final double wallet;
  final SettingsModel settings;
  final bool isFaculty;
  const _WalletCard({required this.wallet, required this.settings, this.isFaculty = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 16),
          Text(
            isFaculty ? '∞  Free' : '₹${wallet.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(
              isFaculty ? 'Faculty — unlimited free printing' : '₹${settings.pricePerPage} per page',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            )),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  final SettingsModel settings;
  const _PermissionsCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Print Options',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              _tag('B&W', true),
              if (settings.allowColor)      _tag('Color', true),
              if (settings.allowDuplex)     _tag('Duplex', true),
              if (settings.allowPageRange)  _tag('Page Range', true),
              if (settings.allowPagesPerSheet) _tag('Multi-up', true),
              if (settings.maxPagesPerJob > 0) _tag('Max ${settings.maxPagesPerJob}p', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, bool allowed) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: allowed ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(allowed ? Icons.check_circle_outline : Icons.info_outline,
          size: 12, color: allowed ? AppTheme.success : AppTheme.warning),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: allowed ? AppTheme.success : AppTheme.warning)),
    ]),
  );
}
