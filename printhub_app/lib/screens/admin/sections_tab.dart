import 'package:flutter/material.dart';
import '../../models/section_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class SectionsTab extends StatelessWidget {
  final List<SectionModel> sections;
  final String token;
  final VoidCallback onRefresh;

  const SectionsTab({
    super.key,
    required this.sections,
    required this.token,
    required this.onRefresh,
  });

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                  child: Text('Create Section',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ),
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
                  labelText: 'Section Name',
                  hintText: 'e.g. CSE',
                  prefixIcon: const Icon(Icons.category_outlined),
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
                    final name = ctrl.text.trim();
                    if (name.isEmpty) return;
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final data = await ApiService.createSection(token, name);
                    navigator.pop();
                    if (data['error'] != null) {
                      messenger.showSnackBar(SnackBar(
                        content: Text(data['error']),
                        backgroundColor: AppTheme.error,
                      ));
                    } else {
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Section created'),
                        backgroundColor: AppTheme.success,
                      ));
                      onRefresh();
                    }
                  },
                  child: const Text('Create Section'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SectionModel section) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Section'),
        content: Text('Delete "${section.name}"? Students in this section will not be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await ApiService.deleteSection(token, section.id);
              navigator.pop();
              messenger.showSnackBar(SnackBar(
                content: Text('"${section.name}" deleted'),
                backgroundColor: AppTheme.success,
              ));
              onRefresh();
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
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
        onRefresh: () async => onRefresh(),
        color: AppTheme.primary,
        child: sections.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('No sections yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text('Tap + to create one', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final section = sections[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.category_rounded, color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(section.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                          onPressed: () => _confirmDelete(context, section),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
