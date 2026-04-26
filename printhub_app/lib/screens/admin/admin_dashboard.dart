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

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  UserModel? _user;
  String? _token;
  List<UserModel>     _students  = [];
  List<UserModel>     _faculty   = [];
  List<PrintJobModel> _printJobs = [];
  List<SectionModel>  _sections  = [];
  SettingsModel       _settings  = const SettingsModel();
  bool _loading = true;

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
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      StudentsTab(students: _students, sections: _sections, token: _token ?? '', onRefresh: _loadData),
      PrintJobsTab(jobs: _printJobs, onRefresh: _loadData),
      FacultyTab(faculty: _faculty, token: _token ?? '', onRefresh: _loadData),
      PrintersTab(token: _token ?? '', sections: _sections, students: _students, faculty: _faculty, onRefresh: _loadData),
      SectionsTab(sections: _sections, token: _token ?? '', onRefresh: _loadData),
      SettingsTab(token: _token ?? '', settings: _settings, onUpdated: _loadData),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  color: AppTheme.primary,
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_user?.name ?? 'Admin',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('${_students.length} students • ${_printJobs.length} jobs • ${_faculty.length} faculty • ${_sections.length} sections',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                    ]),
                  ]),
                ),
                Expanded(child: tabs[_currentIndex]),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: AppTheme.primary),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.print_outlined),
            selectedIcon: Icon(Icons.print_rounded, color: AppTheme.primary),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded, color: AppTheme.primary),
            label: 'Faculty',
          ),
          NavigationDestination(
            icon: Icon(Icons.print_outlined),
            selectedIcon: Icon(Icons.print_rounded, color: AppTheme.primary),
            label: 'Printers',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category_rounded, color: AppTheme.primary),
            label: 'Sections',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
