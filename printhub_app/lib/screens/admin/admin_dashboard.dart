import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/print_job_model.dart';
import '../../models/settings_model.dart';
import '../../models/section_model.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'students_tab.dart';
import 'print_jobs_tab.dart';
import 'settings_tab.dart';
import 'sections_tab.dart';
import 'faculty_tab.dart';
import 'printers_tab.dart';
import 'stats_tab.dart';
import 'printer_queue_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  UserModel? _user;
  String?    _token;
  List<UserModel>     _students  = [];
  List<UserModel>     _faculty   = [];
  List<PrintJobModel> _printJobs = [];
  List<SectionModel>  _sections  = [];
  SettingsModel       _settings  = const SettingsModel();
  bool _loading = true;

  // Menu items definition — single source of truth
  static const _menuItems = [
    _MenuItem(Icons.bar_chart_rounded,        Icons.bar_chart_outlined,        'Stats',     'Dashboard overview'),
    _MenuItem(Icons.people_rounded,           Icons.people_outline_rounded,    'Students',  'Manage students'),
    _MenuItem(Icons.print_rounded,            Icons.print_outlined,            'Print Jobs','View all jobs'),
    _MenuItem(Icons.queue_rounded,            Icons.queue_outlined,            'Queue',     'Live printer queue'),
    _MenuItem(Icons.school_rounded,           Icons.school_outlined,           'Faculty',   'Manage faculty'),
    _MenuItem(Icons.print_rounded,            Icons.print_outlined,            'Printers',  'Printer locations'),
    _MenuItem(Icons.category_rounded,         Icons.category_outlined,         'Sections',  'Manage sections'),
    _MenuItem(Icons.settings_rounded,         Icons.settings_outlined,         'Settings',  'System settings'),
  ];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _token = await AuthService.getToken();
    _user  = await AuthService.getUser();
    try {
      final results = await Future.wait([
        ApiService.getStudents(_token!),
        ApiService.getPrintJobs(_token!),
        ApiService.getSettings(),
        ApiService.getSections(),
        ApiService.getFaculty(_token!),
      ]);
      setState(() {
        _students  = results[0] as List<UserModel>;
        _printJobs = results[1] as List<PrintJobModel>;
        _settings  = results[2] as SettingsModel;
        _sections  = results[3] as List<SectionModel>;
        _faculty   = results[4] as List<UserModel>;
        _loading   = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.clearSession();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _navigate(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context); // close drawer
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Drawer header ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _user?.name ?? 'Admin',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _user?.email ?? '',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    _pill('${_students.length} students'),
                    _pill('${_faculty.length} faculty'),
                    _pill('${_printJobs.length} jobs'),
                  ]),
                ],
              ),
            ),

            // ── Menu items ───────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _menuItems.length,
                itemBuilder: (context, i) {
                  final item    = _menuItems[i];
                  final active  = _currentIndex == i;
                  return _DrawerItem(
                    icon:     active ? item.iconFilled : item.iconOutline,
                    label:    item.label,
                    subtitle: item.subtitle,
                    active:   active,
                    onTap:    () => _navigate(i),
                  );
                },
              ),
            ),

            // ── Divider + logout ─────────────────────────────────
            const Divider(height: 1, color: AppTheme.divider),
            ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppTheme.error, size: 20),
              ),
              title: const Text('Logout',
                  style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              onTap: _logout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label,
        style: const TextStyle(color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w500)),
  );

  @override
  Widget build(BuildContext context) {
    final tabs = [
      StatsTab(token: _token ?? ''),
      StudentsTab(students: _students, sections: _sections, token: _token ?? '', onRefresh: _loadData),
      PrintJobsTab(jobs: _printJobs, onRefresh: _loadData),
      PrinterQueueTab(token: _token ?? ''),
      FacultyTab(faculty: _faculty, token: _token ?? '', onRefresh: _loadData),
      PrintersTab(token: _token ?? '', sections: _sections, students: _students, faculty: _faculty, onRefresh: _loadData),
      SectionsTab(sections: _sections, token: _token ?? '', onRefresh: _loadData),
      SettingsTab(token: _token ?? '', settings: _settings, onUpdated: _loadData),
    ];

    final currentItem = _menuItems[_currentIndex];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      drawer: _buildDrawer(),
      appBar: AppBar(
        // Hamburger button (auto-added by Scaffold when drawer exists,
        // but we style it explicitly)
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: Row(children: [
          Icon(currentItem.iconFilled, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(currentItem.label),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : tabs[_currentIndex],
    );
  }
}

// ── Data class for menu items ─────────────────────────────────
class _MenuItem {
  final IconData iconFilled;
  final IconData iconOutline;
  final String   label;
  final String   subtitle;
  const _MenuItem(this.iconFilled, this.iconOutline, this.label, this.subtitle);
}

// ── Drawer item widget ────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final bool     active;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primary.withValues(alpha: 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: active
                  ? Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      width: 1)
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: active ? AppTheme.primary : AppTheme.textSecondary,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        )),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (active)
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
