import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/settings_model.dart';
import '../../models/printer_location_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_button.dart';

class UploadScreen extends StatefulWidget {
  final String token;
  final double wallet;
  final SettingsModel settings;
  final bool isFaculty;

  const UploadScreen({
    super.key,
    required this.token,
    required this.wallet,
    required this.settings,
    this.isFaculty = false,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _file;
  String? _fileName;

  // Print options
  String _colorMode     = 'bw';
  bool   _duplex        = false;
  int    _pagesPerSheet = 1;
  bool   _usePageRange  = false;
  final  _pageFromCtrl  = TextEditingController();
  final  _pageToCtrl    = TextEditingController();

  // Printer location (faculty only)
  List<PrinterLocationModel> _locations = [];
  String? _selectedLocationId;

  bool   _uploading = false;
  double _progress  = 0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    if (widget.isFaculty) _loadLocations();
  }

  Future<void> _loadLocations() async {
    final locs = await ApiService.getPrinterLocations();
    if (mounted) setState(() => _locations = locs);
  }

  @override
  void dispose() {
    _pageFromCtrl.dispose();
    _pageToCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    if (await file.length() > 50 * 1024 * 1024) {
      _snack('File too large (max 50MB)', error: true);
      return;
    }
    setState(() {
      _file     = file;
      _fileName = result.files.single.name;
    });
  }

  Future<void> _submit() async {
    if (_file == null) { _snack('Please select a PDF', error: true); return; }

    if (_usePageRange) {
      final from = int.tryParse(_pageFromCtrl.text) ?? 0;
      final to   = int.tryParse(_pageToCtrl.text)   ?? 0;
      if (from <= 0 || to < from) {
        _snack('Enter a valid page range (e.g. 1 to 5)', error: true);
        return;
      }
    }

    setState(() { _uploading = true; _progress = 0; _statusText = 'Uploading...'; });
    _animateProgress();

    try {
      final opts = <String, String>{
        'duplex':            _duplex.toString(),
        'colorMode':         _colorMode,
        'pagesPerSheet':     _pagesPerSheet.toString(),
        'pageFrom':          _usePageRange ? (_pageFromCtrl.text) : '0',
        'pageTo':            _usePageRange ? (_pageToCtrl.text)   : '0',
        'printerLocationId': _selectedLocationId ?? '',
      };

      final data = await ApiService.uploadPDF(widget.token, _file!, opts);

      setState(() { _progress = 1.0; _statusText = 'Done!'; });
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      setState(() => _uploading = false);

      if (data['error'] != null) { _snack(data['error'], error: true); return; }

      _showSuccess(
        pages:     data['pages']           ?? 0,
        cost:      (data['cost']           ?? 0).toDouble(),
        remaining: (data['remainingWallet']?? 0).toDouble(),
      );
    } catch (e) {
      setState(() => _uploading = false);
      _snack('Upload failed: ${e.toString()}', error: true);
    }
  }

  void _animateProgress() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || !_uploading) return false;
      setState(() {
        if (_progress < 0.85) {
          _progress += 0.04;
          _statusText = 'Uploading... ${(_progress * 100).toInt()}%';
        }
      });
      return _uploading && _progress < 0.85;
    });
  }

  void _showSuccess({required int pages, required double cost, required double remaining}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Print Job Submitted!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            _row('Pages printed', '$pages'),
            const Divider(height: 16),
            _row('Cost', '₹${cost.toStringAsFixed(0)}'),
            const Divider(height: 16),
            _row('Remaining balance', '₹${remaining.toStringAsFixed(0)}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context, true); },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      Text(value,  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
    ],
  );

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload & Print'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Wallet banner ──────────────────────────────────────────
                _walletBanner(),
                const SizedBox(height: 20),

                // ── File picker ────────────────────────────────────────────
                _sectionLabel('1. Select PDF File'),
                const SizedBox(height: 8),
                _filePicker(),
                const SizedBox(height: 20),

                // ── Print options ──────────────────────────────────────────
                _sectionLabel('2. Print Options'),
                const SizedBox(height: 8),
                _optionsCard(s),
                const SizedBox(height: 16),

                // ── Printer location (faculty only) ────────────────────────
                if (widget.isFaculty) ...[
                  _sectionLabel('3. Select Printer'),
                  const SizedBox(height: 8),
                  _printerLocationPicker(),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 12),

                // ── Submit ─────────────────────────────────────────────────
                LoadingButton(
                  label: 'Submit for Printing',
                  loading: _uploading,
                  onPressed: _submit,
                  icon: Icons.print_rounded,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Progress overlay ───────────────────────────────────────────
          if (_uploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.print_rounded, size: 48, color: AppTheme.primary),
                      const SizedBox(height: 16),
                      const Text('Processing Print Job',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress, minHeight: 8,
                          backgroundColor: AppTheme.divider,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_statusText, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _walletBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accent),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Available Balance', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text('₹${widget.wallet.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('₹${widget.settings.pricePerPage}/page',
              style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));

  Widget _filePicker() => GestureDetector(
    onTap: _uploading ? null : _pickFile,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _file != null ? AppTheme.primary.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _file != null ? AppTheme.primary : AppTheme.divider,
          width: _file != null ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _file != null ? Icons.picture_as_pdf_rounded : Icons.cloud_upload_outlined,
            size: 44,
            color: _file != null ? AppTheme.primary : AppTheme.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            _file != null ? (_fileName ?? 'File selected') : 'Tap to select PDF',
            style: TextStyle(
              fontSize: 14,
              fontWeight: _file != null ? FontWeight.w600 : FontWeight.w400,
              color: _file != null ? AppTheme.primary : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (_file == null) ...[
            const SizedBox(height: 4),
            const Text('PDF only • Max 50MB',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    ),
  );

  Widget _optionsCard(SettingsModel s) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      children: [
        // Color mode
        if (s.allowColor) ...[
          _optionTile(
            icon: Icons.palette_outlined,
            title: 'Color Mode',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _modeChip('B&W', 'bw'),
                const SizedBox(width: 8),
                _modeChip('Color', 'color'),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],

        // Duplex
        if (s.allowDuplex) ...[
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            secondary: const Icon(Icons.flip_to_back_rounded, color: AppTheme.textSecondary),
            title: const Text('Duplex (Both Sides)',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textPrimary)),
            subtitle: const Text('Print on both sides of paper',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            value: _duplex,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.35),
            onChanged: (v) => setState(() => _duplex = v),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],

        // Pages per sheet
        if (s.allowPagesPerSheet) ...[
          _optionTile(
            icon: Icons.grid_view_rounded,
            title: 'Pages per Sheet',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [1, 2, 4].map((n) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _sheetChip(n),
              )).toList(),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],

        // Page range
        if (s.allowPageRange) ...[
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            secondary: const Icon(Icons.format_list_numbered_rounded, color: AppTheme.textSecondary),
            title: const Text('Custom Page Range',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textPrimary)),
            subtitle: const Text('Print specific pages only',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            value: _usePageRange,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.35),
            onChanged: (v) => setState(() => _usePageRange = v),
          ),
          if (_usePageRange)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pageFromCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'From page',
                        hintText: '1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('to', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _pageToCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'To page',
                        hintText: '10',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // Max pages info
        if (s.maxPagesPerJob > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppTheme.warning),
                const SizedBox(width: 6),
                Text('Max ${s.maxPagesPerJob} pages per job',
                    style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _optionTile({required IconData icon, required String title, required Widget child}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            const Spacer(),
            child,
          ],
        ),
      );

  Widget _modeChip(String label, String value) => GestureDetector(
    onTap: () => setState(() => _colorMode = value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _colorMode == value ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colorMode == value ? AppTheme.primary : AppTheme.divider),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _colorMode == value ? Colors.white : AppTheme.textSecondary,
          )),
    ),
  );

  Widget _sheetChip(int n) => GestureDetector(
    onTap: () => setState(() => _pagesPerSheet = n),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 40, height: 32,
      decoration: BoxDecoration(
        color: _pagesPerSheet == n ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _pagesPerSheet == n ? AppTheme.primary : AppTheme.divider),
      ),
      child: Center(
        child: Text('${n}up',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _pagesPerSheet == n ? Colors.white : AppTheme.textSecondary,
            )),
      ),
    ),
  );

  Widget _printerLocationPicker() {
    if (_locations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
          SizedBox(width: 8),
          Text('No printers configured. Contact admin.',
              style: TextStyle(color: AppTheme.warning, fontSize: 13)),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: _locations.map((loc) {
          final selected = _selectedLocationId == loc.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedLocationId = loc.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary.withValues(alpha: 0.06) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: selected ? Border.all(color: AppTheme.primary, width: 1.5) : null,
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: (loc.isOnline ? AppTheme.success : AppTheme.textSecondary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.print_rounded,
                      color: loc.isOnline ? AppTheme.success : AppTheme.textSecondary,
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected ? AppTheme.primary : AppTheme.textPrimary,
                        )),
                    if (loc.description.isNotEmpty)
                      Text(loc.description,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    Row(children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: loc.isOnline ? AppTheme.success : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(loc.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            color: loc.isOnline ? AppTheme.success : Colors.grey,
                          )),
                    ]),
                  ],
                )),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary, size: 20),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}
