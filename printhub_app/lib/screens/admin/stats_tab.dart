import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class StatsTab extends StatefulWidget {
  final String token;
  const StatsTab({super.key, required this.token});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await ApiService.getAdminStats(widget.token);
    if (mounted) setState(() { _stats = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Today banner
                _SectionTitle('Today'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _StatCard(
                    icon: Icons.print_rounded,
                    label: 'Jobs Today',
                    value: '${_stats['jobsToday'] ?? 0}',
                    color: AppTheme.primary,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    icon: Icons.currency_rupee,
                    label: 'Revenue Today',
                    value: '₹${(_stats['todayRevenue'] ?? 0).toStringAsFixed(0)}',
                    color: AppTheme.success,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _StatCard(
                    icon: Icons.description_outlined,
                    label: 'Pages Today',
                    value: '${_stats['todayPages'] ?? 0}',
                    color: AppTheme.accent,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    icon: Icons.hourglass_top_rounded,
                    label: 'In Queue',
                    value: '${(_stats['pendingJobs'] ?? 0) + (_stats['printingJobs'] ?? 0)}',
                    color: AppTheme.warning,
                  )),
                ]),

                const SizedBox(height: 20),
                _SectionTitle('All Time'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _StatCard(
                    icon: Icons.people_rounded,
                    label: 'Students',
                    value: '${_stats['totalStudents'] ?? 0}',
                    color: const Color(0xFF7C3AED),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    icon: Icons.school_rounded,
                    label: 'Faculty',
                    value: '${_stats['totalFaculty'] ?? 0}',
                    color: const Color(0xFF7C3AED),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _StatCard(
                    icon: Icons.print_rounded,
                    label: 'Total Jobs',
                    value: '${_stats['totalJobs'] ?? 0}',
                    color: AppTheme.primary,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    icon: Icons.currency_rupee,
                    label: 'Total Revenue',
                    value: '₹${(_stats['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                    color: AppTheme.success,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _StatCard(
                    icon: Icons.description_rounded,
                    label: 'Pages Printed',
                    value: '${_stats['totalPages'] ?? 0}',
                    color: AppTheme.accent,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    icon: Icons.check_circle_rounded,
                    label: 'Completed',
                    value: '${_stats['completedJobs'] ?? 0}',
                    color: AppTheme.success,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _StatCard(
                    icon: Icons.error_rounded,
                    label: 'Failed',
                    value: '${_stats['failedJobs'] ?? 0}',
                    color: AppTheme.error,
                  )),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ]),

                // Printers status
                if ((_stats['printers'] as List?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 20),
                  _SectionTitle('Printer Status'),
                  const SizedBox(height: 10),
                  ...(_stats['printers'] as List).map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (p['isOnline'] ?? false) ? AppTheme.success : AppTheme.error,
                          boxShadow: [(p['isOnline'] ?? false) ? BoxShadow(
                            color: AppTheme.success.withValues(alpha: 0.4),
                            blurRadius: 6, spreadRadius: 1,
                          ) : const BoxShadow(color: Colors.transparent)],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(p['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                      const Spacer(),
                      Text(
                        (p['isOnline'] ?? false) ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: (p['isOnline'] ?? false) ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ]),
                  )),
                ],
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary));
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
