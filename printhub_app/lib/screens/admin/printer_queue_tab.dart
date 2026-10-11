import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class PrinterQueueTab extends StatefulWidget {
  final String token;
  const PrinterQueueTab({super.key, required this.token});

  @override
  State<PrinterQueueTab> createState() => _PrinterQueueTabState();
}

class _PrinterQueueTabState extends State<PrinterQueueTab> {
  List<dynamic> _queue = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = await ApiService.getPrinterQueue(widget.token);
    if (mounted) setState(() { _queue = q; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _queue.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.print_disabled_outlined, size: 64, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text('No printers configured', style: TextStyle(color: AppTheme.textSecondary)),
                  ]),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _queue.map<Widget>((printer) {
                    final jobs = printer['jobs'] as List? ?? [];
                    final isOnline = printer['isOnline'] ?? false;
                    final pending = printer['pending'] ?? 0;
                    final printing = printer['printing'] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOnline
                              ? AppTheme.success.withValues(alpha: 0.4)
                              : AppTheme.divider,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Printer header
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? AppTheme.success.withValues(alpha: 0.06)
                                  : AppTheme.surface,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline ? AppTheme.success : AppTheme.error,
                                  boxShadow: [isOnline ? BoxShadow(
                                    color: AppTheme.success.withValues(alpha: 0.5),
                                    blurRadius: 6, spreadRadius: 1,
                                  ) : const BoxShadow(color: Colors.transparent)],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(
                                printer['printerName'] ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                              )),
                              if (printing > 0)
                                _badge('Printing $printing', AppTheme.primary),
                              const SizedBox(width: 6),
                              if (pending > 0)
                                _badge('$pending waiting', AppTheme.warning),
                              if (printing == 0 && pending == 0)
                                _badge('Empty', AppTheme.textSecondary),
                            ]),
                          ),
                          // Jobs list
                          if (jobs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text('No active jobs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            )
                          else
                            ...jobs.asMap().entries.map((entry) {
                              final i = entry.key;
                              final j = entry.value;
                              final status = j['status'] ?? 'pending';
                              final statusColor = status == 'printing' ? AppTheme.primary : AppTheme.warning;
                              return Container(
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppTheme.divider, width: 1),
                                  ),
                                ),
                                child: Row(children: [
                                  // Position number
                                  Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: status == 'printing'
                                          ? Icon(Icons.print_rounded, size: 14, color: statusColor)
                                          : Text('${i + 1}', style: TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(j['fileName'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(
                                        '${j['userName'] ?? ''}${(j['userSection'] ?? '').isNotEmpty ? ' · ${j['userSection']}' : ''}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  )),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('${j['pages'] ?? 0} pages',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status == 'printing' ? 'Printing' : 'Waiting',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                                      ),
                                    ),
                                  ]),
                                ]),
                              );
                            }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}
