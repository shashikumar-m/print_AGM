import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/printer_location_model.dart';
import '../../models/section_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class PrintersTab extends StatefulWidget {
  final String token;
  final List<SectionModel> sections;
  final List<UserModel> students;
  final List<UserModel> faculty;
  final VoidCallback onRefresh;

  const PrintersTab({
    super.key,
    required this.token,
    required this.sections,
    required this.students,
    required this.faculty,
    required this.onRefresh,
  });

  @override
  State<PrintersTab> createState() => _PrintersTabState();
}

class _PrintersTabState extends State<PrintersTab> {
  List<PrinterLocationModel> _printers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await ApiService.getAdminPrinterLocations(widget.token);
    if (mounted) setState(() { _printers = p; _loading = false; });
  }

  void _showAddSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
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
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Add Printer Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text('e.g. HOD Room, Lab 1, Library', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ])),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),
              _field(nameCtrl, 'Printer Name *', 'e.g. HOD Room Printer', Icons.print_rounded),
              const SizedBox(height: 12),
              _field(descCtrl, 'Description', 'e.g. Ground floor, near reception', Icons.location_on_outlined),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name required'), backgroundColor: AppTheme.error));
                      return;
                    }
                    setSheet(() => saving = true);
                    final data = await ApiService.createPrinterLocation(widget.token, name, descCtrl.text.trim());
                    setSheet(() => saving = false);
                    if (!ctx.mounted) return;
                    if (data['error'] != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error']), backgroundColor: AppTheme.error));
                    } else {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Printer "$name" added'), backgroundColor: AppTheme.success));
                      _load();
                    }
                  },
                  child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Add Printer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  void _showAssignSheet(BuildContext context, PrinterLocationModel printer) {
    // Track what's currently assigned to this printer for context
    int _tabIndex = 0; // 0 = Students (by section), 1 = Faculty
    String? selectedSectionId;
    String? selectedFacultyId;

    // Which sections already have this printer assigned
    final assignedSections = widget.sections
        .where((s) => s.assignedPrinterId == printer.id)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final content = _tabIndex == 0
              // ── STUDENTS TAB (section-based) ──────────────────
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Students print to this printer based on their section.\nSelect a section to assign:',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    // Show already-assigned sections with remove buttons
                    if (assignedSections.isNotEmpty) ...[
                      const Text('Currently assigned — tap ✕ to remove:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: assignedSections.map((s) => Container(
                          padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.success),
                            const SizedBox(width: 4),
                            Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(ctx);
                                await ApiService.assignPrinterToSection(widget.token, s.id, '');
                                widget.onRefresh();
                                _load();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('"${s.name}" removed'),
                                    backgroundColor: AppTheme.success,
                                  ));
                                }
                              },
                              child: Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Icon(Icons.close_rounded, size: 12, color: AppTheme.error),
                              ),
                            ),
                          ]),
                        )).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    DropdownButtonFormField<String>(
                      value: selectedSectionId,
                      decoration: InputDecoration(
                        labelText: 'Select Section (Students)',
                        hintText: 'Choose a section',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: widget.sections.map((s) {
                        final alreadyHere = s.assignedPrinterId == printer.id;
                        return DropdownMenuItem(
                          value: s.id,
                          child: Row(children: [
                            Text(s.name),
                            if (alreadyHere) ...[
                              const SizedBox(width: 6),
                              const Text('(current)', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                            ],
                          ]),
                        );
                      }).toList(),
                      onChanged: (v) => setSheet(() => selectedSectionId = v),
                    ),
                  ],
                )
              // ── FACULTY TAB ───────────────────────────────────
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Faculty can choose any printer when uploading.\nYou can also set a default printer for a faculty member:',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    // Show faculty already assigned to this printer with remove buttons
                    Builder(builder: (_) {
                      final assignedFaculty = widget.faculty
                          .where((f) => f.section == printer.id)
                          .toList();
                      if (assignedFaculty.isEmpty) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Currently assigned — tap ✕ to remove:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6,
                          children: assignedFaculty.map((f) => Container(
                            padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.school_rounded, size: 12, color: AppTheme.success),
                              const SizedBox(width: 4),
                              Text(f.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  // Remove by assigning empty printer
                                  await ApiService.assignPrinterToUser(widget.token, f.id, '');
                                  widget.onRefresh();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text('"${f.name}" printer assignment removed'),
                                      backgroundColor: AppTheme.success,
                                    ));
                                  }
                                },
                                child: Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 12, color: AppTheme.error),
                                ),
                              ),
                            ]),
                          )).toList(),
                        ),
                        const SizedBox(height: 14),
                      ]);
                    }),
                    DropdownButtonFormField<String>(
                      value: selectedFacultyId,
                      decoration: InputDecoration(
                        labelText: 'Assign new faculty member',
                        hintText: 'Choose faculty',
                        prefixIcon: const Icon(Icons.school_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: widget.faculty.isEmpty
                          ? [const DropdownMenuItem(value: null, child: Text('No faculty added yet'))]
                          : widget.faculty.map((u) {
                              final hasPrinter = u.section == printer.id;
                              return DropdownMenuItem(
                                value: u.id,
                                child: Row(children: [
                                  Text(u.name),
                                  if (u.department.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Text('(${u.department})',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                  if (hasPrinter) ...[
                                    const SizedBox(width: 6),
                                    const Text('(current)', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                                  ],
                                ]),
                              );
                            }).toList(),
                      onChanged: widget.faculty.isEmpty ? null : (v) => setSheet(() => selectedFacultyId = v),
                    ),
                  ],
                );

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  // Header
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Assign  "${printer.name}"',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        const Text('Choose who prints to this printer',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 16),

                  // Tab selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      _tabBtn('👥 Students (Section)', _tabIndex == 0,
                          () => setSheet(() { _tabIndex = 0; selectedSectionId = null; })),
                      const SizedBox(width: 4),
                      _tabBtn('🎓 Faculty', _tabIndex == 1,
                          () => setSheet(() { _tabIndex = 1; selectedFacultyId = null; })),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Tab content
                  content,
                  const SizedBox(height: 20),

                  // Assign button
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: (_tabIndex == 0 ? selectedSectionId : selectedFacultyId) == null
                          ? null
                          : () async {
                              Map<String, dynamic> result;
                              if (_tabIndex == 0) {
                                result = await ApiService.assignPrinterToSection(
                                    widget.token, selectedSectionId!, printer.id);
                              } else {
                                result = await ApiService.assignPrinterToUser(
                                    widget.token, selectedFacultyId!, printer.id);
                              }
                              if (!ctx.mounted) return;
                              if (result['error'] != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(result['error']), backgroundColor: AppTheme.error));
                              } else {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(_tabIndex == 0
                                        ? 'Section assigned — students will print here'
                                        : 'Faculty default printer set'),
                                    backgroundColor: AppTheme.success));
                                widget.onRefresh();
                                _load();
                              }
                            },
                      child: Text(
                        _tabIndex == 0 ? 'Assign Section to this Printer' : 'Set as Faculty Default Printer',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [const BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 2))]
              : [],
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? AppTheme.primary : AppTheme.textSecondary,
            )),
      ),
    ),
  );

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label, hintText: hint, prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Printer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: () async { _load(); widget.onRefresh(); },
              color: AppTheme.primary,
              child: _printers.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.print_disabled_outlined, size: 64, color: AppTheme.textSecondary),
                      SizedBox(height: 12),
                      Text('No printers yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      SizedBox(height: 6),
                      Text('Tap + to add a printer location', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _printers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final p = _printers[i];
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.isOnline ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.divider),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: p.maintenanceMode
                                      ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                                      : p.isOnline ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(
                                      color: p.maintenanceMode
                                          ? const Color(0xFF7C3AED)
                                          : p.isOnline ? AppTheme.success : Colors.grey,
                                      shape: BoxShape.circle)),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.maintenanceMode ? 'Maintenance' : (p.isOnline ? 'Online' : 'Offline'),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                        color: p.maintenanceMode
                                            ? const Color(0xFF7C3AED)
                                            : p.isOnline ? AppTheme.success : Colors.grey),
                                  ),
                                ]),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                                onPressed: () async {
                                  if (!context.mounted) return;
                                  final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                                    title: const Text('Delete Printer'),
                                    content: Text('Delete "${p.name}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
                                    ],
                                  ));
                                  if (confirm == true) {
                                    await ApiService.deletePrinterLocation(widget.token, p.id);
                                    _load();
                                  }
                                },
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Text('🖨️ ${p.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            if (p.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(p.description, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                            const SizedBox(height: 14),
                            // Agent key
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Agent Key — copy to print-agent/.env',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Expanded(child: Text(p.agentKey,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppTheme.primary),
                                      overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: p.agentKey));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agent key copied!'), backgroundColor: AppTheme.success));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                                      child: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ]),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            // Show which sections are assigned to this printer
                            Builder(builder: (context) {
                              final assigned = widget.sections.where((s) => s.assignedPrinterId == p.id).toList();
                              if (assigned.isEmpty) return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: const Text('No sections assigned yet',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              );
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sections printing here:',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 6, runSpacing: 6,
                                    children: assigned.map((s) {
                                      final count = widget.students.where((st) => st.section == s.name).length;
                                      return Container(
                                        padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                        ),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Text('${s.name} · $count students',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: const Text('Remove Section'),
                                                  content: Text('Remove "${s.name}" from "${p.name}"?\nStudents in this section will have no printer assigned.'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                // Assign empty string to remove
                                                await ApiService.assignPrinterToSection(widget.token, s.id, '');
                                                widget.onRefresh();
                                                _load();
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                    content: Text('"${s.name}" removed from "${p.name}"'),
                                                    backgroundColor: AppTheme.success,
                                                  ));
                                                }
                                              }
                                            },
                                            child: Container(
                                              width: 22, height: 22,
                                              decoration: BoxDecoration(
                                                color: AppTheme.error.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.close_rounded, size: 13, color: AppTheme.error),
                                            ),
                                          ),
                                        ]),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            }),
                            // Assign buttons
                            Row(children: [
                              Expanded(child: OutlinedButton.icon(
                                onPressed: () => _showAssignSheet(context, p),
                                icon: const Icon(Icons.link_rounded, size: 16),
                                label: const Text('Assign to...'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(color: AppTheme.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              )),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await ApiService.toggleMaintenanceMode(widget.token, p.id);
                                  if (!context.mounted) return;
                                  if (result['error'] != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(result['error']), backgroundColor: AppTheme.error));
                                  } else {
                                    final inMaintenance = result['maintenanceMode'] ?? false;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(inMaintenance
                                          ? '🔧 "${p.name}" set to maintenance mode'
                                          : '✅ "${p.name}" back to normal'),
                                      backgroundColor: inMaintenance ? const Color(0xFF7C3AED) : AppTheme.success,
                                    ));
                                    _load();
                                    widget.onRefresh();
                                  }
                                },
                                icon: Icon(
                                  p.maintenanceMode ? Icons.check_circle_outline_rounded : Icons.build_outlined,
                                  size: 16,
                                  color: p.maintenanceMode ? AppTheme.success : const Color(0xFF7C3AED),
                                ),
                                label: Text(
                                  p.maintenanceMode ? 'End Maintenance' : 'Maintenance',
                                  style: TextStyle(
                                      color: p.maintenanceMode ? AppTheme.success : const Color(0xFF7C3AED)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: p.maintenanceMode ? AppTheme.success : const Color(0xFF7C3AED)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ]),
                          ]),
                        );
                      },
                    ),
            ),
    );
  }
}
