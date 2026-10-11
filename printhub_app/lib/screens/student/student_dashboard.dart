import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import '../../models/print_job_model.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'upload_screen.dart';
import 'print_history_screen.dart';

class StudentDashboard extends StatefulWidget {
  final bool isFaculty;
  const StudentDashboard({super.key, this.isFaculty = false});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  UserModel?    _user;
  String?       _token;
  double        _wallet   = 0;
  SettingsModel _settings = const SettingsModel();
  bool          _loading  = true;

  // Printer status
  String _printerName    = '';
  bool   _printerOnline  = false;
  bool   _printerLoaded  = false;

  // Active job tracker (most recent pending/printing job)
  PrintJobModel? _activeJob;
  Timer?         _jobPollTimer;
  Timer?         _printerPollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _jobPollTimer?.cancel();
    _printerPollTimer?.cancel();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _wallet   = ((results[0] as Map)['wallet'] ?? 0).toDouble();
        _settings = results[1] as SettingsModel;
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() { _wallet = _user?.wallet ?? 0; _loading = false; });
    }

    // Load printer status + active jobs in background
    if (!widget.isFaculty) {
      _loadPrinterStatus();
      _loadActiveJob();
      // Poll printer status every 30s
      _printerPollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadPrinterStatus());
    }
  }

  Future<void> _loadPrinterStatus() async {
    try {
      final data = await ApiService.getMyPrinterStatus(_token!);
      if (!mounted) return;
      setState(() {
        _printerName   = data['name']     ?? '';
        _printerOnline = data['isOnline'] ?? false;
        _printerLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _loadActiveJob() async {
    try {
      final jobs = await ApiService.getMyJobs(_token!);
      if (!mounted) return;
      // Find most recent pending or printing job
      final active = jobs.where((j) => j.isPending || j.isPrinting).toList();
      setState(() => _activeJob = active.isEmpty ? null : active.first);
      if (_activeJob != null) _startJobPolling();
    } catch (_) {}
  }

  void _startJobPolling() {
    _jobPollTimer?.cancel();
    _jobPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_activeJob == null) { _jobPollTimer?.cancel(); return; }
      try {
        final data = await ApiService.getJobStatus(_token!, _activeJob!.id);
        if (!mounted) return;
        final newStatus = data['status'] ?? _activeJob!.status;
        setState(() => _activeJob = PrintJobModel(
          id: _activeJob!.id,
          fileName: data['fileName'] ?? _activeJob!.fileName,
          pages: data['pages'] ?? _activeJob!.pages,
          cost: _activeJob!.cost,
          status: newStatus,
          duplex: _activeJob!.duplex,
          printerLocationName: data['printerLocationName'] ?? _activeJob!.printerLocationName,
          createdAt: _activeJob!.createdAt,
          studentName: _activeJob!.studentName,
        ));
        if (newStatus == 'completed' || newStatus == 'failed') {
          _jobPollTimer?.cancel();
          // Refresh wallet after completion
          if (newStatus == 'completed') {
            final w = await ApiService.getWallet(_token!);
            if (mounted) setState(() => _wallet = (w['wallet'] ?? _wallet).toDouble());
          }
        }
      } catch (_) {}
    });
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
            // ── App bar ──────────────────────────────────────────────────
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
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(_user?.email ?? '',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                            if ((_user?.section ?? '').isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(_user!.section,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Printer status banner ──────────────────────
                          if (!widget.isFaculty && _printerLoaded)
                            _PrinterStatusBanner(
                              name: _printerName,
                              isOnline: _printerOnline,
                            ),
                          if (!widget.isFaculty && _printerLoaded)
                            const SizedBox(height: 16),

                          // ── Wallet card ────────────────────────────────
                          _WalletCard(
                              wallet: _wallet,
                              settings: _settings,
                              isFaculty: widget.isFaculty),
                          const SizedBox(height: 16),

                          // ── Active job live tracker ────────────────────
                          if (_activeJob != null) ...[
                            _LiveJobCard(job: _activeJob!),
                            const SizedBox(height: 16),
                          ],

                          // ── Quick actions ──────────────────────────────
                          const Text('Quick Actions',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 12),

                          // Upload & Print
                          _ActionCard(
                            icon: Icons.upload_file_rounded,
                            title: 'Upload & Print',
                            subtitle: widget.isFaculty
                                ? 'Free printing — choose your printer'
                                : 'Select a PDF with custom print options',
                            color: AppTheme.primary,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UploadScreen(
                                    token: _token!,
                                    wallet: _wallet,
                                    settings: _settings,
                                    isFaculty: widget.isFaculty,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadData();
                                _loadActiveJob();
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Print History
                          _ActionCard(
                            icon: Icons.history_rounded,
                            title: 'Print History',
                            subtitle: 'View all your past print jobs',
                            color: AppTheme.accent,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrintHistoryScreen(token: _token!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Permissions card (students only)
                          if (!widget.isFaculty) _PermissionsCard(settings: _settings),
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

// ── Printer Status Banner ─────────────────────────────────────────────────────
class _PrinterStatusBanner extends StatelessWidget {
  final String name;
  final bool   isOnline;
  const _PrinterStatusBanner({required this.name, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isOnline
            ? AppTheme.success.withValues(alpha: 0.08)
            : AppTheme.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOnline
              ? AppTheme.success.withValues(alpha: 0.35)
              : AppTheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isOnline
                ? AppTheme.success.withValues(alpha: 0.15)
                : AppTheme.error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.print_rounded,
            size: 18,
            color: isOnline ? AppTheme.success : AppTheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? 'Printer' : name,
              style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13,
                color: isOnline ? AppTheme.success : AppTheme.error,
              ),
            ),
            Text(
              isOnline ? 'Online — ready to print' : 'Offline — contact admin',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        )),
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: isOnline ? AppTheme.success : AppTheme.error,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isOnline ? AppTheme.success : AppTheme.error).withValues(alpha: 0.4),
                blurRadius: 6, spreadRadius: 1,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Live Job Tracker Card ─────────────────────────────────────────────────────
class _LiveJobCard extends StatelessWidget {
  final PrintJobModel job;
  const _LiveJobCard({required this.job});

  Color get _color {
    if (job.isPrinting) return AppTheme.primary;
    if (job.isCompleted) return AppTheme.success;
    if (job.isFailed) return AppTheme.error;
    return AppTheme.warning;
  }

  String get _headline {
    if (job.isPrinting)  return 'Printing now…';
    if (job.isCompleted) return 'Ready to collect!';
    if (job.isFailed)    return 'Print failed';
    return 'Waiting in queue…';
  }

  String get _sub {
    if (job.isPrinting)  return '${job.fileName} is being printed';
    if (job.isCompleted) return '${job.fileName} is ready';
    if (job.isFailed)    return 'Something went wrong — try again';
    return '${job.fileName} — ${job.pages} pages';
  }

  IconData get _icon {
    if (job.isPrinting)  return Icons.print_rounded;
    if (job.isCompleted) return Icons.check_circle_rounded;
    if (job.isFailed)    return Icons.error_rounded;
    return Icons.hourglass_top_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _color.withValues(alpha: 0.12),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_headline,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14, color: _color)),
                  const SizedBox(height: 2),
                  Text(_sub,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (job.printerLocationName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.print_rounded, size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(job.printerLocationName,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                  ],
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${job.pages}p · ₹${job.cost.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _color)),
              ),
            ]),
          ),
          // Progress bar for pending/printing
          if (job.isPending || job.isPrinting)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: _color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(_color.withValues(alpha: 0.6)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Wallet Card ───────────────────────────────────────────────────────────────
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
        boxShadow: [
          BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Wallet Balance',
                style: TextStyle(
                    color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 16),
          Text(
            isFaculty ? '∞  Free' : '₹${wallet.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
              isFaculty ? 'Faculty — unlimited free printing' : '₹${settings.pricePerPage} per page',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Action Card ───────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});

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
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: color.withValues(alpha: 0.6)),
        ]),
      ),
    );
  }
}

// ── Permissions Card ──────────────────────────────────────────────────────────
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
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Print Options',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              _tag('B&W', true),
              if (settings.allowColor) _tag('Color', true),
              if (settings.allowDuplex) _tag('Duplex', true),
              if (settings.allowPageRange) _tag('Page Range', true),
              if (settings.allowPagesPerSheet) _tag('Multi-up', true),
              if (settings.maxPagesPerJob > 0)
                _tag('Max ${settings.maxPagesPerJob}p', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, bool allowed) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: allowed
          ? AppTheme.success.withValues(alpha: 0.1)
          : AppTheme.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
          allowed ? Icons.check_circle_outline : Icons.info_outline,
          size: 12,
          color: allowed ? AppTheme.success : AppTheme.warning),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: allowed ? AppTheme.success : AppTheme.warning)),
    ]),
  );
}
