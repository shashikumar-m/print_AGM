import 'package:flutter/material.dart';
import '../../models/section_model.dart';
import '../../models/printer_location_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class SectionsTab extends StatefulWidget {
  final List<SectionModel> sections;
  final String token;
  final VoidCallback onRefresh;

  const SectionsTab({
    super.key,
    required this.sections,
    required this.token,
    required this.onRefresh,
  });

  @override
  State<SectionsTab> createState() => _SectionsTabState();
}

class _SectionsTabState extends State<SectionsTab> {
  List<PrinterLocationModel> _printers = [];

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    final p = await ApiService.getAdminPrinterLocations(widget.token);
    if (mounted) setState(() => _printers = p);
  }

  void _showCreateDialog(BuildContext context) {
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Create Section',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 4),
            const Text('e.g. CSE, ECE, MECH, MBA',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Section Name', hintText: 'e.g. CSE',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  final nav = Navigator.of(context);
                  final msg = ScaffoldMessenger.of(context);
                  final data = await ApiService.createSection(widget.token, name);
                  nav.pop();
                  if (data['error'] != null) {
                    msg.showSnackBar(SnackBar(content: Text(data['error']), backgroundColor: AppTheme.error));
                  } else {
                    msg.showSnackBar(const SnackBar(content: Text('Section created'), backgroundColor: AppTheme.success));
                    widget.onRefresh();
                  }
                },
                child: const Text('Create Section'),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showAssignPrinterSheet(BuildContext context, SectionModel section) {
    String? selectedPrinterId = section.assignedPrinterId.isEmpty ? null : section.assignedPrinterId;
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
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Assign Printer — ${section.name}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  const Text('All students in this section will print to the selected printer automatically.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ])),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),

              if (_printers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('No printers added yet. Go to Printers tab first.',
                        style: TextStyle(color: AppTheme.warning, fontSize: 13))),
                  ]),
                )
              else ...[
                // None option
                GestureDetector(
                  onTap: () => setSheet(() => selectedPrinterId = null),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selectedPrinterId == null ? AppTheme.error.withValues(alpha: 0.06) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedPrinterId == null ? AppTheme.error : AppTheme.divider,
                        width: selectedPrinterId == null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      const Icon(Icons.print_disabled_rounded, color: AppTheme.error, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('No printer (remove assignment)',
                          style: TextStyle(fontSize: 14, color: AppTheme.error, fontWeight: FontWeight.w500))),
                      if (selectedPrinterId == null)
                        const Icon(Icons.check_circle_rounded, color: AppTheme.error, size: 18),
                    ]),
                  ),
                ),
                ..._printers.map((p) {
                  final sel = selectedPrinterId == p.id;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedPrinterId = p.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary.withValues(alpha: 0.06) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider, width: sel ? 1.5 : 1),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: p.isOnline ? AppTheme.success : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.print_rounded, color: sel ? AppTheme.primary : AppTheme.textSecondary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14,
                              color: sel ? AppTheme.primary : AppTheme.textPrimary)),
                          if (p.description.isNotEmpty)
                            Text(p.description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ])),
                        if (sel) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                      ]),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: saving || _printers.isEmpty ? null : () async {
                    setSheet(() => saving = true);
                    final result = await ApiService.assignPrinterToSection(
                        widget.token, section.id, selectedPrinterId ?? '');
                    setSheet(() => saving = false);
                    if (!ctx.mounted) return;
                    if (result['error'] != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(result['error']), backgroundColor: AppTheme.error));
                    } else {
                      Navigator.pop(ctx);
                      final printerName = selectedPrinterId == null
                          ? 'removed'
                          : _printers.firstWhere((p) => p.id == selectedPrinterId).name;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(selectedPrinterId == null
                              ? 'Printer assignment removed from ${section.name}'
                              : '${section.name} → $printerName'),
                          backgroundColor: AppTheme.success));
                      widget.onRefresh();
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save Assignment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Section', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: () async { widget.onRefresh(); await _loadPrinters(); },
        color: AppTheme.primary,
        child: widget.sections.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.category_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('No sections yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 6),
                const Text('Tap + to create one', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: widget.sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final section = widget.sections[i];
                  final assignedPrinter = _printers.where((p) => p.id == section.assignedPrinterId).firstOrNull;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: assignedPrinter != null ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.divider,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.category_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(section.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        // Printer assignment status
                        if (assignedPrinter != null)
                          Row(children: [
                            Container(width: 6, height: 6,
                                decoration: BoxDecoration(
                                    color: assignedPrinter.isOnline ? AppTheme.success : Colors.grey,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('🖨️ ${assignedPrinter.name}',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: assignedPrinter.isOnline ? AppTheme.success : AppTheme.textSecondary)),
                          ])
                        else
                          const Text('No printer assigned',
                              style: TextStyle(fontSize: 12, color: AppTheme.warning)),
                      ])),
                      // Assign printer button
                      GestureDetector(
                        onTap: () => _showAssignPrinterSheet(context, section),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.print_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(assignedPrinter != null ? 'Change' : 'Assign',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Delete Section'),
                            content: Text('Delete "${section.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () async {
                                  final nav = Navigator.of(context);
                                  final msg = ScaffoldMessenger.of(context);
                                  await ApiService.deleteSection(widget.token, section.id);
                                  nav.pop();
                                  msg.showSnackBar(SnackBar(
                                      content: Text('"${section.name}" deleted'),
                                      backgroundColor: AppTheme.success));
                                  widget.onRefresh();
                                },
                                child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
