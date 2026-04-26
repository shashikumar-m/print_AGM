import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/print_job_model.dart';
import '../../theme/app_theme.dart';

class PrintJobsTab extends StatelessWidget {
  final List<PrintJobModel> jobs;
  final VoidCallback onRefresh;

  const PrintJobsTab({
    super.key,
    required this.jobs,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: jobs.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_disabled_outlined,
                      size: 64, color: AppTheme.textSecondary),
                  SizedBox(height: 12),
                  Text('No print jobs yet',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _PrintJobCard(job: jobs[i]),
            ),
    );
  }
}

class _PrintJobCard extends StatelessWidget {
  final PrintJobModel job;
  const _PrintJobCard({required this.job});

  Color get _statusColor {
    switch (job.status) {
      case 'completed':
        return AppTheme.success;
      case 'printing':
        return AppTheme.warning;
      case 'failed':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData get _statusIcon {
    switch (job.status) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'printing':
        return Icons.print_rounded;
      case 'failed':
        return Icons.error_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, y • h:mm a').format(job.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      job.studentName,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, size: 12, color: _statusColor),
                    const SizedBox(width: 4),
                    Text(
                      job.status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(Icons.description_outlined, '${job.pages} pages'),
              const SizedBox(width: 8),
              _chip(Icons.currency_rupee, '₹${job.cost.toStringAsFixed(0)}'),
              const SizedBox(width: 8),
              _chip(
                job.duplex
                    ? Icons.flip_to_back_rounded
                    : Icons.flip_to_front_rounded,
                job.duplex ? 'Duplex' : 'Simplex',
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
