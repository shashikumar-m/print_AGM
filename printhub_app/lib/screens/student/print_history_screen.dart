import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/print_job_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class PrintHistoryScreen extends StatefulWidget {
  final String token;
  const PrintHistoryScreen({super.key, required this.token});

  @override
  State<PrintHistoryScreen> createState() => _PrintHistoryScreenState();
}

class _PrintHistoryScreenState extends State<PrintHistoryScreen> {
  List<PrintJobModel> _jobs = [];
  bool _loading = true;
  Timer? _pollTimer;

  // Track which jobs are pending/printing so we can auto-refresh
  bool get _hasActiveJobs =>
      _jobs.any((j) => j.isPending || j.isPrinting);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final jobs = await ApiService.getMyJobs(widget.token);
    if (!mounted) return;
    setState(() { _jobs = jobs; _loading = false; });
    _startPollingIfNeeded();
  }

  void _startPollingIfNeeded() {
    _pollTimer?.cancel();
    if (_hasActiveJobs) {
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        final jobs = await ApiService.getMyJobs(widget.token);
        if (!mounted) return;
        setState(() => _jobs = jobs);
        if (!_hasActiveJobs) _pollTimer?.cancel();
      });
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      backgroundColor: AppTheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _jobs.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _jobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _JobCard(
                      job: _jobs[i],
                      formatDate: _formatDate,
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.print_disabled_rounded, size: 40, color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 16),
      const Text('No print jobs yet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      const SizedBox(height: 6),
      const Text('Your submitted jobs will appear here',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    ]),
  );
}

class _JobCard extends StatelessWidget {
  final PrintJobModel job;
  final String Function(DateTime) formatDate;
  const _JobCard({required this.job, required this.formatDate});

  Color get _statusColor {
    switch (job.status) {
      case 'completed': return AppTheme.success;
      case 'printing':  return AppTheme.primary;
      case 'failed':    return AppTheme.error;
      default:          return AppTheme.warning;
    }
  }

  IconData get _statusIcon {
    switch (job.status) {
      case 'completed': return Icons.check_circle_rounded;
      case 'printing':  return Icons.print_rounded;
      case 'failed':    return Icons.cancel_rounded;
      default:          return Icons.hourglass_top_rounded;
    }
  }

  String get _statusLabel {
    switch (job.status) {
      case 'completed': return 'Completed';
      case 'printing':  return 'Printing…';
      case 'failed':    return 'Failed';
      default:          return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final opts = [
      job.colorMode == 'color' ? 'Color' : 'B&W',
      if (job.duplex) 'Duplex',
      if (job.pagesPerSheet > 1) '${job.pagesPerSheet}-up',
      if (job.pageRangeFrom > 0) 'p${job.pageRangeFrom}-${job.pageRangeTo}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (job.isPrinting || job.isPending)
              ? _statusColor.withValues(alpha: 0.4)
              : AppTheme.divider,
          width: (job.isPrinting || job.isPending) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.fileName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(formatDate(job.createdAt),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      if (job.printerLocationName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.print_rounded, size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text(job.printerLocationName,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon, size: 12, color: _statusColor),
                    const SizedBox(width: 4),
                    Text(_statusLabel,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
                  ]),
                ),
              ],
            ),
          ),
          // Bottom strip — stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              _stat(Icons.description_outlined, '${job.pages} pages'),
              const SizedBox(width: 16),
              _stat(Icons.currency_rupee, '${job.cost.toStringAsFixed(0)}'),
              const SizedBox(width: 16),
              Expanded(child: Text(opts,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),
          // Live printing bar
          if (job.isPrinting)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(AppTheme.primary.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppTheme.textSecondary),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
    ],
  );
}
