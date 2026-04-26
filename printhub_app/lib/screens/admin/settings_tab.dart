import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/settings_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_button.dart';

class SettingsTab extends StatefulWidget {
  final String token;
  final SettingsModel settings;
  final VoidCallback onUpdated;

  const SettingsTab({
    super.key,
    required this.token,
    required this.settings,
    required this.onUpdated,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late TextEditingController _priceCtrl;
  late TextEditingController _maxPagesCtrl;
  late bool _allowColor;
  late bool _allowDuplex;
  late bool _allowPageRange;
  late bool _allowPagesPerSheet;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _priceCtrl        = TextEditingController(text: s.pricePerPage.toString());
    _maxPagesCtrl     = TextEditingController(text: s.maxPagesPerJob == 0 ? '' : s.maxPagesPerJob.toString());
    _allowColor       = s.allowColor;
    _allowDuplex      = s.allowDuplex;
    _allowPageRange   = s.allowPageRange;
    _allowPagesPerSheet = s.allowPagesPerSheet;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _maxPagesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceCtrl.text);
    if (price == null || price <= 0) {
      _snack('Enter a valid price', error: true);
      return;
    }
    final maxPages = int.tryParse(_maxPagesCtrl.text) ?? 0;

    setState(() => _saving = true);
    try {
      final data = await ApiService.updateSettings(widget.token, {
        'pricePerPage':       price,
        'allowColor':         _allowColor,
        'allowDuplex':        _allowDuplex,
        'allowPageRange':     _allowPageRange,
        'allowPagesPerSheet': _allowPagesPerSheet,
        'maxPagesPerJob':     maxPages,
      });
      if (data['error'] != null) {
        _snack(data['error'], error: true);
      } else {
        _snack('Settings saved', error: false);
        widget.onUpdated();
      }
    } catch (_) {
      _snack('Failed to save settings', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Configure pricing and student print permissions',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // ── Pricing ──────────────────────────────────────────────────────
          _card(
            icon: Icons.payments_rounded,
            iconColor: AppTheme.warning,
            title: 'Pricing',
            child: Column(
              children: [
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Price per page (₹)', '1.0', Icons.currency_rupee),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maxPagesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDeco('Max pages per job (0 = unlimited)', '0', Icons.layers_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Print Permissions ─────────────────────────────────────────────
          _card(
            icon: Icons.tune_rounded,
            iconColor: AppTheme.primary,
            title: 'Student Print Permissions',
            child: Column(
              children: [
                _permSwitch(
                  icon: Icons.palette_outlined,
                  title: 'Allow Color Printing',
                  subtitle: 'Students can choose color mode',
                  value: _allowColor,
                  onChanged: (v) => setState(() => _allowColor = v),
                ),
                const Divider(height: 1),
                _permSwitch(
                  icon: Icons.flip_to_back_rounded,
                  title: 'Allow Duplex Printing',
                  subtitle: 'Students can print on both sides',
                  value: _allowDuplex,
                  onChanged: (v) => setState(() => _allowDuplex = v),
                ),
                const Divider(height: 1),
                _permSwitch(
                  icon: Icons.format_list_numbered_rounded,
                  title: 'Allow Custom Page Range',
                  subtitle: 'Students can print specific pages',
                  value: _allowPageRange,
                  onChanged: (v) => setState(() => _allowPageRange = v),
                ),
                const Divider(height: 1),
                _permSwitch(
                  icon: Icons.grid_view_rounded,
                  title: 'Allow Multiple Pages per Sheet',
                  subtitle: 'Students can print 2 or 4 pages on one sheet',
                  value: _allowPagesPerSheet,
                  onChanged: (v) => setState(() => _allowPagesPerSheet = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          LoadingButton(
            label: 'Save Settings',
            loading: _saving,
            onPressed: _save,
            icon: Icons.save_rounded,
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _permSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      secondary: Icon(icon, color: AppTheme.textSecondary, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      value: value,
      activeThumbColor: AppTheme.primary,
      activeTrackColor: AppTheme.primary.withValues(alpha: 0.35),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDeco(String label, String hint, IconData icon) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
    ),
  );
}
