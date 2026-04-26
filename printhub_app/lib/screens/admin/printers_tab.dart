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
    String assignType = 'section';
    String? selectedId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Assign "${printer.name}"', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),
              // Type selector
              Row(children: [
                _typeChip('Section', assignType == 'section', () => setSheet(() { assignType = 'section'; selectedId = null; })),
                const SizedBox(width: 8),
                _typeChip('Student', assignType == 'student', () => setSheet(() { assignType = 'student'; selectedId = null; })),
                const SizedBox(width: 8),
                _typeChip('Faculty', assignType == 'faculty', () => setSheet(() { assignType = 'faculty'; selectedId = null; })),
              ]),
              const SizedBox(height: 16),
              // Dropdown
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: InputDecoration(
                  labelText: assignType == 'section' ? 'Select Section' : 'Select Person',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: assignType == 'section'
                    ? widget.sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList()
                    : assignType == 'student'
                        ? widget.students.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList()
                        : widget.faculty.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                onChanged: (v) => setSheet(() => selectedId = v),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: selectedId == null ? null : () async {
                    Map<String, dynamic> result;
                    if (assignType == 'section') {
                      result = await ApiService.assignPrinterToSection(widget.token, selectedId!, printer.id);
                    } else {
                      result = await ApiService.assignPrinterToUser(widget.token, selectedId!, printer.id);
                    }
                    if (!ctx.mounted) return;
                    if (result['error'] != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error']), backgroundColor: AppTheme.error));
                    } else {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printer assigned!'), backgroundColor: AppTheme.success));
                      widget.onRefresh();
                    }
                  },
                  child: const Text('Assign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppTheme.primary : AppTheme.divider),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppTheme.textSecondary)),
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
                                  color: p.isOnline ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: p.isOnline ? AppTheme.success : Colors.grey, shape: BoxShape.circle)),
                                  const SizedBox(width: 5),
                                  Text(p.isOnline ? 'Online' : 'Offline',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.isOnline ? AppTheme.success : Colors.grey)),
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
                            ]),
                          ]),
                        );
                      },
                    ),
            ),
    );
  }
}
