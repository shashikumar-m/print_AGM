import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_button.dart';

class UploadScreen extends StatefulWidget {
  final String token;
  final double wallet;
  final double pricePerPage;

  const UploadScreen({
    super.key,
    required this.token,
    required this.wallet,
    required this.pricePerPage,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedFile;
  String? _fileName;
  bool _duplex = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  String _statusText = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final size = await file.length();
      if (size > 50 * 1024 * 1024) {
        _showSnack('File too large (max 50MB)', isError: true);
        return;
      }
      setState(() {
        _selectedFile = file;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedFile == null) {
      _showSnack('Please select a PDF file', isError: true);
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _statusText = 'Uploading PDF...';
    });

    // Simulate progress
    _simulateProgress();

    try {
      final data = await ApiService.uploadPDF(
        widget.token,
        _selectedFile!,
        _duplex,
      );

      setState(() {
        _uploadProgress = 1.0;
        _statusText = 'Print job submitted!';
      });

      await Future.delayed(const Duration(milliseconds: 600));

      if (data['error'] != null) {
        setState(() => _uploading = false);
        _showSnack(data['error'], isError: true);
        return;
      }

      if (!mounted) return;
      setState(() => _uploading = false);

      _showSuccessDialog(
        pages: data['pages'] ?? 0,
        cost: (data['cost'] ?? 0).toDouble(),
        remaining: (data['remainingWallet'] ?? 0).toDouble(),
      );
    } catch (e) {
      setState(() => _uploading = false);
      _showSnack('Upload failed. Check your connection.', isError: true);
    }
  }

  void _simulateProgress() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || !_uploading) return false;
      setState(() {
        if (_uploadProgress < 0.85) {
          _uploadProgress += 0.05;
          _statusText = 'Uploading... ${(_uploadProgress * 100).toInt()}%';
        }
      });
      return _uploading && _uploadProgress < 0.85;
    });
  }

  void _showSuccessDialog({
    required int pages,
    required double cost,
    required double remaining,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Print Job Submitted!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _resultRow('Pages', '$pages'),
            const Divider(height: 16),
            _resultRow('Cost', '₹${cost.toStringAsFixed(0)}'),
            const Divider(height: 16),
            _resultRow('Remaining Balance', '₹${remaining.toStringAsFixed(0)}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                // Wallet info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: AppTheme.accent),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Balance',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          Text(
                            '₹${widget.wallet.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₹${widget.pricePerPage}/page',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Select PDF File',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // File picker area
                GestureDetector(
                  onTap: _uploading ? null : _pickFile,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _selectedFile != null
                          ? AppTheme.primary.withOpacity(0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedFile != null
                            ? AppTheme.primary
                            : AppTheme.divider,
                        width: _selectedFile != null ? 2 : 1,
                        style: _selectedFile != null
                            ? BorderStyle.solid
                            : BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFile != null
                              ? Icons.picture_as_pdf_rounded
                              : Icons.cloud_upload_outlined,
                          size: 48,
                          color: _selectedFile != null
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFile != null
                              ? _fileName ?? 'File selected'
                              : 'Tap to select PDF',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: _selectedFile != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _selectedFile != null
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_selectedFile == null) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'PDF files only • Max 50MB',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Duplex option
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Duplex Printing',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Print on both sides of the paper',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    value: _duplex,
                    activeThumbColor: AppTheme.primary,
                    activeTrackColor: AppTheme.primary.withValues(alpha: 0.4),
                    onChanged: _uploading
                        ? null
                        : (v) => setState(() => _duplex = v),
                  ),
                ),
                const SizedBox(height: 32),

                LoadingButton(
                  label: 'Submit for Printing',
                  loading: _uploading,
                  onPressed: _submit,
                  icon: Icons.print_rounded,
                ),
              ],
            ),
          ),

          // Upload overlay
          if (_uploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.print_rounded,
                          size: 48, color: AppTheme.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'Processing Print Job',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          minHeight: 8,
                          backgroundColor: AppTheme.divider,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusText,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
