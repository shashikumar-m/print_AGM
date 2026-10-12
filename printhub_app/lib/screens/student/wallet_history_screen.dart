import 'package:flutter/material.dart';
import '../../models/wallet_transaction_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class WalletHistoryScreen extends StatefulWidget {
  final String token;
  const WalletHistoryScreen({super.key, required this.token});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<WalletTransactionModel> _txs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final txs = await ApiService.getWalletHistory(widget.token);
    if (mounted) setState(() { _txs = txs; _loading = false; });
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

  // Summary totals
  int get _totalCredited => _txs
      .where((t) => t.isCredit)
      .fold(0, (sum, t) => sum + t.amount);
  int get _totalSpent => _txs
      .where((t) => !t.isCredit)
      .fold(0, (sum, t) => sum + t.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _load),
        ],
      ),
      backgroundColor: AppTheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _txs.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary card
                      _SummaryCard(credited: _totalCredited, spent: _totalSpent),
                      const SizedBox(height: 16),
                      const Text('Transaction History',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 10),
                      ..._txs.map((tx) => _TxCard(tx: tx, formatDate: _formatDate)),
                    ],
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
        child: const Icon(Icons.receipt_long_rounded, size: 40, color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 16),
      const Text('No transactions yet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      const SizedBox(height: 6),
      const Text('Wallet top-ups and print charges will appear here',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          textAlign: TextAlign.center),
    ]),
  );
}

class _SummaryCard extends StatelessWidget {
  final int credited;
  final int spent;
  const _SummaryCard({required this.credited, required this.spent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.3),
          blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Received', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text('₹$credited', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        ])),
        Container(width: 1, height: 50, color: Colors.white24),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text('₹$spent', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _TxCard extends StatelessWidget {
  final WalletTransactionModel tx;
  final String Function(DateTime) formatDate;
  const _TxCard({required this.tx, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final color = tx.isCredit ? AppTheme.success : AppTheme.error;
    final sign  = tx.isCredit ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03), blurRadius: 6,
        )],
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            tx.isCredit ? Icons.add_circle_rounded : Icons.print_rounded,
            color: color, size: 20,
          ),
        ),
        const SizedBox(width: 12),
        // Description + date
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tx.description.isEmpty ? (tx.isCredit ? 'Wallet Top-up' : 'Print Charge') : tx.description,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Text(formatDate(tx.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              if (tx.addedBy.isNotEmpty) ...[
                const Text(' · ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text(tx.addedBy,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ]),
          ],
        )),
        // Amount + balance
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$sign₹${tx.amount}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          if (tx.balanceAfter > 0)
            Text('Bal: ₹${tx.balanceAfter.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      ]),
    );
  }
}
