import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/section_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class StudentsTab extends StatefulWidget {
  final List<UserModel> students;
  final List<SectionModel> sections;
  final String token;
  final VoidCallback onRefresh;

  const StudentsTab({
    super.key,
    required this.students,
    required this.sections,
    required this.token,
    required this.onRefresh,
  });

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _searchCtrl = TextEditingController();
  String _query          = '';
  String _selectedSection = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // All unique sections from the student list + "All"
  List<String> get _sections {
    final set = <String>{};
    for (final s in widget.students) {
      if (s.section.isNotEmpty) set.add(s.section);
    }
    final sorted = set.toList()..sort();
    return ['All', ...sorted];
  }

  List<UserModel> get _filtered {
    return widget.students.where((s) {
      final matchSection = _selectedSection == 'All' || s.section == _selectedSection;
      final q = _query.toLowerCase();
      final matchSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.section.toLowerCase().contains(q);
      return matchSection && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final sections = _sections;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentSheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Student',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        color: AppTheme.primary,
        child: Column(
          children: [
          // ── Search bar ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, email or section…',
                hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
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
          ),

          // ── Section filter chips ────────────────────────────────────────
          if (sections.length > 1)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: sections.map((sec) {
                    final active = _selectedSection == sec;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedSection = sec),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? AppTheme.primary : AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active ? AppTheme.primary : AppTheme.divider,
                            ),
                          ),
                          child: Text(
                            sec == 'All'
                                ? 'All (${widget.students.length})'
                                : '$sec (${widget.students.where((s) => s.section == sec).length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          const Divider(height: 1, color: AppTheme.divider),

          // ── Result count ────────────────────────────────────────────────
          if (_query.isNotEmpty || _selectedSection != 'All')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.surface,
              child: Text(
                '${filtered.length} student${filtered.length == 1 ? '' : 's'} found',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _query.isNotEmpty ? Icons.search_off_rounded : Icons.people_outline,
                          size: 56,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty
                              ? 'No students match "$_query"'
                              : 'No students in this section',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _StudentCard(
                      student: filtered[i],
                      token: widget.token,
                      onUpdated: widget.onRefresh,
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  // ── Add Student bottom sheet ──────────────────────────────────────────────
  void _showAddStudentSheet(BuildContext context) {
    final nameCtrl   = TextEditingController();
    final emailCtrl  = TextEditingController();
    final passCtrl   = TextEditingController(text: 'student123');
    final walletCtrl = TextEditingController(text: '0');
    String? selectedSection;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Add Student', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        SizedBox(height: 2),
                        Text('Create account and assign to section', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 16),
                  _sheetField(nameCtrl,  'Full Name *',  'Student full name',  Icons.person_outline),
                  const SizedBox(height: 12),
                  _sheetField(emailCtrl, 'Email *',      'student@email.com',  Icons.email_outlined, type: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _sheetField(passCtrl,  'Password *',   'Min 6 characters',   Icons.lock_outline,   obscure: true),
                  const SizedBox(height: 12),
                  // Section dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedSection,
                    decoration: InputDecoration(
                      labelText: 'Section',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No section')),
                      ...widget.sections.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))),
                    ],
                    onChanged: (v) => setSheetState(() => selectedSection = v),
                  ),
                  const SizedBox(height: 12),
                  _sheetField(walletCtrl, 'Initial Wallet (₹)', '0', Icons.account_balance_wallet_outlined, type: TextInputType.number),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        final name   = nameCtrl.text.trim();
                        final email  = emailCtrl.text.trim();
                        final pass   = passCtrl.text;
                        final wallet = int.tryParse(walletCtrl.text) ?? 0;
                        if (name.isEmpty || email.isEmpty || pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Fill all required fields (password min 6 chars)'),
                            backgroundColor: AppTheme.error,
                          ));
                          return;
                        }
                        setSheetState(() => saving = true);
                        final data = await ApiService.createStudent(widget.token, {
                          'name': name, 'email': email, 'password': pass,
                          'section': selectedSection ?? '', 'wallet': wallet,
                        });
                        setSheetState(() => saving = false);
                        if (!ctx.mounted) return;
                        if (data['error'] != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(data['error']), backgroundColor: AppTheme.error));
                        } else {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Student "$name" added!'), backgroundColor: AppTheme.success));
                          widget.onRefresh();
                        }
                      },
                      child: saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Add Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _sheetField(TextEditingController ctrl, String label, String hint, IconData icon,
      {TextInputType type = TextInputType.text, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
}

// ── Student card ──────────────────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final UserModel student;
  final String token;
  final VoidCallback onUpdated;

  const _StudentCard({
    required this.student,
    required this.token,
    required this.onUpdated,
  });

  void _showAddFunds(BuildContext context) {
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
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Add Wallet Funds',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${student.name}${student.section.isNotEmpty ? " · ${student.section}" : ""}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: 'Enter amount',
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
                    final data = await ApiService.addWallet(token, student.id, amount);
                    nav.pop();
                    if (data['error'] != null) {
                      msg.showSnackBar(SnackBar(content: Text(data['error']), backgroundColor: AppTheme.error));
                    } else {
                      msg.showSnackBar(SnackBar(
                        content: Text('Added ₹$amount to ${student.name}'),
                        backgroundColor: AppTheme.success,
                      ));
                      onUpdated();
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

  // Section badge color — consistent per section name
  Color _sectionColor(String section) {
    const colors = [
      Color(0xFF6366F1), Color(0xFF06B6D4), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6),
    ];
    if (section.isEmpty) return AppTheme.textSecondary;
    return colors[section.codeUnits.first % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final sectionColor = _sectionColor(student.section);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: sectionColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: TextStyle(color: sectionColor, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + email + section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(student.email,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (student.section.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sectionColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(student.section,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sectionColor)),
                  ),
                ],
              ],
            ),
          ),

          // Wallet + add funds
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${student.wallet.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showAddFunds(context),
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
            ],
          ),
        ],
      ),
    );
  }
}
