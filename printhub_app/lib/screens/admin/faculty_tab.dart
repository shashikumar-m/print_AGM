import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/printer_location_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class FacultyTab extends StatefulWidget {
  final List<UserModel> faculty;
  final String token;
  final VoidCallback onRefresh;

  const FacultyTab({
    super.key,
    required this.faculty,
    required this.token,
    required this.onRefresh,
  });

  @override
  State<FacultyTab> createState() => _FacultyTabState();
}

class _FacultyTabState extends State<FacultyTab> {
  List<PrinterLocationModel> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final locs = await ApiService.getAdminPrinterLocations(widget.token);
    if (mounted) setState(() => _locations = locs);
  }

  void _showAddFacultySheet(BuildContext context) {
    final nameCtrl   = TextEditingController();
    final emailCtrl  = TextEditingController();
    final passCtrl   = TextEditingController(text: 'faculty123');
    final deptCtrl   = TextEditingController();
    String? selectedLocationId;
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
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Faculty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        SizedBox(height: 2),
                        Text('Faculty get free unlimited printing', style: TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    )),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 16),
                  _field(nameCtrl,  'Full Name *',   'Dr. / Prof. name',   Icons.person_outline),
                  const SizedBox(height: 12),
                  _field(emailCtrl, 'Email *',       'faculty@college.com', Icons.email_outlined, type: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _field(passCtrl,  'Password *',    'Min 6 characters',   Icons.lock_outline, obscure: true),
                  const SizedBox(height: 12),
                  _field(deptCtrl,  'Department',    'e.g. CSE, ECE',      Icons.business_outlined),
                  const SizedBox(height: 12),

                  // Printer location assignment
                  const Text('Assign Printer Location',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  if (_locations.isEmpty)
                    const Text('No printer locations configured yet.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
                  else
                    ..._locations.map((loc) {
                      final sel = selectedLocationId == loc.id;
                      return GestureDetector(
                        onTap: () => setSheet(() => selectedLocationId = loc.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: sel ? AppTheme.primary.withValues(alpha: 0.06) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? AppTheme.primary : AppTheme.divider,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Icon(Icons.print_rounded,
                                color: sel ? AppTheme.primary : AppTheme.textSecondary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.name, style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14,
                                    color: sel ? AppTheme.primary : AppTheme.textPrimary)),
                                if (loc.description.isNotEmpty)
                                  Text(loc.description, style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            )),
                            if (sel) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                          ]),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final pass = passCtrl.text;
                        if (name.isEmpty || email.isEmpty || pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Fill all required fields'),
                            backgroundColor: AppTheme.error,
                          ));
                          return;
                        }
                        setSheet(() => saving = true);
                        final data = await ApiService.createFaculty(widget.token, {
                          'name': name,
                          'email': email,
                          'password': pass,
                          'department': deptCtrl.text.trim(),
                          'printerLocationId': selectedLocationId ?? '',
                        });
                        setSheet(() => saving = false);
                        if (!ctx.mounted) return;
                        if (data['error'] != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(data['error']), backgroundColor: AppTheme.error));
                        } else {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Faculty "$name" added!'),
                            backgroundColor: AppTheme.success));
                          widget.onRefresh();
                        }
                      },
                      child: saving
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Add Faculty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFacultySheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Faculty',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: () async { widget.onRefresh(); await _loadLocations(); },
        color: AppTheme.primary,
        child: widget.faculty.isEmpty
            ? const Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: AppTheme.textSecondary),
                  SizedBox(height: 12),
                  Text('No faculty yet', style: TextStyle(color: AppTheme.textSecondary)),
                  SizedBox(height: 6),
                  Text('Tap + to add faculty', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: widget.faculty.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final f = widget.faculty[i];
                  final assignedLoc = _locations.where((l) => l.id == f.section).firstOrNull;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(
                          f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w700, fontSize: 18),
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                          Text(f.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(children: [
                            if (f.department.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(f.department,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (assignedLoc != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.print_rounded, size: 10, color: AppTheme.success),
                                  const SizedBox(width: 3),
                                  Text(assignedLoc.name,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success)),
                                ]),
                              ),
                          ]),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Free', style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
