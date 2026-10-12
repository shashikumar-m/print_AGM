import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import '../../models/print_job_model.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../student/upload_screen.dart';
import '../student/print_history_screen.dart';

class FacultyDashboard extends StatefulWidget {
  const FacultyDashboard({super.key});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  int _tabIndex = 0; // 0 = Print, 1 = My Students, 2 = History

  UserModel? _user;
  String? _token;
  SettingsModel _settings = const SettingsModel();
  List<UserModel> _students = [];
  bool _loading = true;
  bool _studentsLoading = false;

  // Active job tracker
  PrintJobModel? _activeJob;
  Timer?         _jobPollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _jobPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _token = await AuthService.getToken();
    _user  = await AuthService.getUser();
    try {
      final s = await ApiService.getSettings();
      setState(() { _settings = s; _loading = false; });
      _loadActiveJob();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadActiveJob() async {
    try {
      final jobs = await ApiService.getMyJobs(_token!);
      if (!mounted) return;
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
          id: _activeJob!.id, fileName: data['fileName'] ?? _activeJob!.fileName,
          pages: data['pages'] ?? _activeJob!.pages, cost: _activeJob!.cost,
          status: newStatus, duplex: _activeJob!.duplex,
          printerLocationName: data['printerLocationName'] ?? _activeJob!.printerLocationName,
          createdAt: _activeJob!.createdAt, studentName: _activeJob!.studentName,
        ));
        if (newStatus == 'completed' || newStatus == 'failed' || newStatus == 'cancelled') {
          _jobPollTimer?.cancel();
        }
      } catch (_) {}
    });
  }

  Future<void> _cancelJob() async {
    if (_activeJob == null || !_activeJob!.isPending) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Print Job'),
        content: Text('Cancel "${_activeJob!.fileName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, keep it')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await ApiService.cancelJob(_token!, _activeJob!.id);
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error']), backgroundColor: AppTheme.error));
    } else {
      _jobPollTimer?.cancel();
      setState(() => _activeJob = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Job cancelled'), backgroundColor: AppTheme.success));
    }
  }

  Future<void> _loadStudents() async {
    setState(() => _studentsLoading = true);
    try {
      final list = await ApiService.getFacultyStudents(_token!);
      setState(() { _students = list; _studentsLoading = false; });
    } catch (_) {
      setState(() => _studentsLoading = false);
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
      appBar: AppBar(
        title: const Text('Faculty Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (_user?.name.isNotEmpty ?? false) ? _user!.name[0].toUpperCase() : 'F',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_user?.name ?? 'Faculty',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(_user?.email ?? '',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                        if ((_user?.assignedSection ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Section: ${_user!.assignedSection}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Free Printing',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),

                // Tab bar
                Container(
                  color: Colors.white,
                  child: Row(
                    children: [
                      _tabBtn(0, Icons.print_rounded, 'Print'),
                      _tabBtn(1, Icons.people_rounded, 'My Students'),
                      _tabBtn(2, Icons.history_rounded, 'History'),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.divider),

                // Tab content
                Expanded(
                  child: _tabIndex == 0
                      ? _PrintTab(
                          token: _token!,
                          settings: _settings,
                          activeJob: _activeJob,
                          onCancel: _activeJob?.isPending == true ? _cancelJob : null,
                          onJobSubmitted: _loadActiveJob,
                        )
                      : _tabIndex == 1
                          ? _StudentsTab(
                              token: _token!,
                              students: _students,
                              loading: _studentsLoading,
                              assignedSection: _user?.assignedSection ?? '',
                              onLoad: _loadStudents,
                            )
                          : PrintHistoryScreen(token: _token!),
                ),
              ],
            ),
    );
  }

  Widget _tabBtn(int index, IconData icon, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _tabIndex = index);
          if (index == 1 && _students.isEmpty) _loadStudents();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppTheme.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: active ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: active ? AppTheme.primary : AppTheme.textSecondary,
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Print tab ─────────────────────────────────────────────────────────────────
class _PrintTab extends StatelessWidget {
  final String token;
  final SettingsModel settings;
  final PrintJobModel? activeJob;
  final VoidCallback? onCancel;
  final VoidCallback? onJobSubmitted;

  const _PrintTab({
    required this.token,
    required this.settings,
    this.activeJob,
    this.onCancel,
    this.onJobSubmitted,
  });

  Color _jobColor(PrintJobModel job) {
    if (job.isPrinting) return AppTheme.primary;
    if (job.isCompleted) return AppTheme.success;
    if (job.isFailed) return AppTheme.error;
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active job card
          if (activeJob != null) ...[
            _buildActiveJobCard(context, activeJob!),
            const SizedBox(height: 16),
          ],
          // Free printing card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: AppTheme.success.withValues(alpha: 0.3),
                blurRadius: 20, offset: const Offset(0, 8),
              )],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Faculty Printing', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 16),
              const Text('∞  Unlimited Free',
                  style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('No cost — all options available',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),

          const SizedBox(height: 20),
          const Text('Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),

          // Upload card
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => UploadScreen(
                  token: token, wallet: 0, settings: settings, isFaculty: true,
                ),
              ));
              onJobSubmitted?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Upload & Print', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text('Free printing — choose your section\'s printer', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.primary.withValues(alpha: 0.6)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveJobCard(BuildContext context, PrintJobModel job) {
    final c = _jobColor(job);
    final labels = {
      'pending': 'Waiting in queue…',
      'printing': 'Printing now…',
      'completed': 'Ready to collect!',
      'failed': 'Print failed',
      'cancelled': 'Job cancelled',
    };
    final icons = {
      'pending': Icons.hourglass_top_rounded,
      'printing': Icons.print_rounded,
      'completed': Icons.check_circle_rounded,
      'failed': Icons.error_rounded,
      'cancelled': Icons.cancel_rounded,
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icons[job.status] ?? Icons.print_rounded, color: c, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(labels[job.status] ?? job.status,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: c)),
              Text(job.fileName,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (job.printerLocationName.isNotEmpty)
                Row(children: [
                  const Icon(Icons.print_rounded, size: 11, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Text(job.printerLocationName,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${job.pages}p', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
            ),
          ]),
        ),
        if (job.isPending || job.isPrinting)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: c.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(c.withValues(alpha: 0.6)),
            ),
          ),
        if (job.isPending && onCancel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: GestureDetector(
              onTap: onCancel,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cancel_outlined, size: 15, color: AppTheme.error),
                  SizedBox(width: 6),
                  Text('Cancel Print Job',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.error)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Students tab ──────────────────────────────────────────────────────────────
class _StudentsTab extends StatefulWidget {
  final String token;
  final List<UserModel> students;
  final bool loading;
  final String assignedSection;
  final VoidCallback onLoad;

  const _StudentsTab({
    required this.token,
    required this.students,
    required this.loading,
    required this.assignedSection,
    required this.onLoad,
  });

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.students.isEmpty && !widget.loading) widget.onLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserModel> get _filtered {
    if (_query.isEmpty) return widget.students;
    final q = _query.toLowerCase();
    return widget.students.where((s) =>
        s.name.toLowerCase().contains(q) ||
        s.email.toLowerCase().contains(q) ||
        s.usn.toLowerCase().contains(q)).toList();
  }

  void _showAddStudent(BuildContext context) {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController(text: 'student123');
    final usnCtrl   = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Add Student',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Will be added to ${widget.assignedSection} section',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ])),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 16),
                  _field(nameCtrl,  'Full Name *',    'Student full name',  Icons.person_outline),
                  const SizedBox(height: 12),
                  _field(usnCtrl,   'USN / Roll No',  'e.g. 1AG22CS001',   Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _field(emailCtrl, 'Email *',        'student@email.com',  Icons.email_outlined,
                      type: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _field(passCtrl,  'Password *',     'Min 6 characters',   Icons.lock_outline,
                      obscure: true),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        final name  = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final pass  = passCtrl.text;
                        final usn   = usnCtrl.text.trim();
                        if (name.isEmpty || email.isEmpty || pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Fill all required fields (password min 6 chars)'),
                            backgroundColor: AppTheme.error));
                          return;
                        }
                        setSheet(() => saving = true);
                        final data = await ApiService.facultyAddStudent(widget.token, {
                          'name': name, 'email': email,
                          'password': pass, 'usn': usn,
                        });
                        setSheet(() => saving = false);
                        if (!ctx.mounted) return;
                        if (data['error'] != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(data['error']), backgroundColor: AppTheme.error));
                        } else {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Student "$name" added to ${widget.assignedSection}'),
                              backgroundColor: AppTheme.success));
                          widget.onLoad();
                        }
                      },
                      child: saving
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Add Student',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon,
      {TextInputType type = TextInputType.text, bool obscure = false}) {
    return TextField(
      controller: ctrl, keyboardType: type, obscureText: obscure,
      decoration: InputDecoration(
        labelText: label, hintText: hint, prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showAddFunds(BuildContext context, UserModel student) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Add Wallet Funds',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${student.name} · Section ${student.section}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ])),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 4),
              // Current balance
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text('Current balance: ₹${student.wallet.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: 'Enter amount to add',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = int.tryParse(ctrl.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Enter a valid amount'),
                        backgroundColor: AppTheme.error,
                      ));
                      return;
                    }
                    final nav = Navigator.of(context);
                    final msg = ScaffoldMessenger.of(context);
                    final data = await ApiService.facultyAddWallet(widget.token, student.id, amount);
                    nav.pop();
                    if (data['error'] != null) {
                      msg.showSnackBar(SnackBar(content: Text(data['error']), backgroundColor: AppTheme.error));
                    } else {
                      msg.showSnackBar(SnackBar(
                        content: Text('Added ₹$amount to ${student.name}'),
                        backgroundColor: AppTheme.success,
                      ));
                      widget.onLoad(); // refresh list
                    }
                  },
                  child: const Text('Add Funds'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: widget.assignedSection.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddStudent(context),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('Add Student',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Column(
      children: [
        // Search bar + section label
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.assignedSection.isNotEmpty) ...[
                Row(children: [
                  const Icon(Icons.category_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text('Section: ${widget.assignedSection}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  const SizedBox(width: 8),
                  Text('${widget.students.length} student${widget.students.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search name, email or USN…',
                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.divider),

        Expanded(
          child: widget.students.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      widget.assignedSection.isEmpty
                          ? 'No section assigned to you yet'
                          : 'No students in ${widget.assignedSection}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    const Text('Ask admin to assign you a section',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: () async => widget.onLoad(),
                  color: AppTheme.primary,
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary),
                            const SizedBox(height: 12),
                            Text('No students match "$_query"',
                                style: const TextStyle(color: AppTheme.textSecondary)),
                          ]),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final student = filtered[i];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(children: [
                                // Avatar
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text(
                                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 18),
                                  )),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(student.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(student.email,
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    if (student.usn.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const Icon(Icons.badge_outlined, size: 11, color: AppTheme.textSecondary),
                                        const SizedBox(width: 3),
                                        Text(student.usn,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                                                fontWeight: FontWeight.w500)),
                                      ]),
                                    ],
                                  ],
                                )),
                                // Wallet + add funds
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('₹${student.wallet.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _showAddFunds(context, student),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('+ Funds',
                                          style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ]),
                              ]),
                            );
                          },
                        ),
                ),
        ),
      ],
    ),
  );
  }
}
