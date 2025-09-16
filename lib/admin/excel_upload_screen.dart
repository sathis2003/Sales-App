// lib/admin/excel_upload_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sales/admin/excel_import_report_screen.dart';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:sales/model/import_report.dart';


class ExcelUploadScreen extends StatefulWidget {
  const ExcelUploadScreen({Key? key}) : super(key: key);

  @override
  State<ExcelUploadScreen> createState() => _ExcelUploadScreenState();
}

class _ExcelUploadScreenState extends State<ExcelUploadScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PlatformFile? _selectedFile;
  List<Map<String, dynamic>> _previewData = [];
  bool _isLoading = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _totalRows = 0;

  // Expected column headers including new assignment columns
  final Map<String, String> _expectedHeaders = {
    'Business Name': 'businessName',
    'Business Type': 'businessType',
    'Contact Name': 'name',
    'Phone Number': 'phoneNumber',
    'Turnover': 'turnover',
    'Call Status': 'callStatus',
    'Category': 'categoryName',
    'Assigned To': 'assignedToEmail', // User's Email
  };

  /// Reads file bytes in a cross-platform way.
  Future<Uint8List?> _getFileBytes(PlatformFile file) async {
    if (kIsWeb) {
      return file.bytes;
    } else if (file.path != null) {
      return await io.File(file.path!).readAsBytes();
    }
    return null;
  }

  /// Opens file picker and triggers the Excel processing.
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _previewData.clear();
          _totalRows = 0;
        });
        await _processExcelFile();
      }
    } catch (e) {
      _showSnackbar('Error picking file: $e', isError: true);
    }
  }

  /// Processes the selected Excel file to validate headers and create a preview.
  Future<void> _processExcelFile() async {
    if (_selectedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await _getFileBytes(_selectedFile!);
      if (bytes == null) throw 'Could not read file bytes.';

      final excel = excel_lib.Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null || sheet.rows.isEmpty) {
        throw 'Excel sheet is empty or could not be read.';
      }

      final headerRow = sheet.rows.first;
      final headers = headerRow.map((cell) => cell?.value?.toString().trim() ?? '').toList();

      // Validate that all expected headers are present
      final missingHeaders = _expectedHeaders.keys.where((h) => !headers.contains(h)).toList();
      if (missingHeaders.isNotEmpty) {
        throw 'Missing required columns: ${missingHeaders.join(', ')}.';
      }

      final dataRows = sheet.rows.skip(1).toList();
      _previewData.clear();

      for (int i = 0; i < dataRows.length && i < 5; i++) { // Show max 5 rows for preview
        final row = dataRows[i];
        final rowData = <String, dynamic>{};
        for (int j = 0; j < headers.length; j++) {
          final header = headers[j];
          if (_expectedHeaders.containsKey(header)) {
            final fieldName = _expectedHeaders[header]!;
            rowData[fieldName] = row.length > j ? row[j]?.value?.toString().trim() : '';
          }
        }
        if (rowData['businessName']?.isNotEmpty == true) {
          _previewData.add(rowData);
        }
      }

      setState(() => _totalRows = dataRows.length);

      if (dataRows.isEmpty) {
        _showSnackbar('No data rows found in the Excel file.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Error processing Excel file: $e', isError: true);
      setState(() {
        _selectedFile = null;
        _previewData.clear();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Uploads and assigns leads based on the Excel file content.
  Future<void> _uploadData() async {
    if (_selectedFile == null || _totalRows == 0) {
      _showSnackbar('Please select a valid Excel file with data.', isError: true);
      return;
    }

    setState(() => _isUploading = true);

    List<ReportEntry> reportEntries = [];

    try {
      // 1. Pre-fetch users and categories for efficient lookup
      final usersSnapshot = await _firestore.collection('users').get();
      final usersByEmail = {
        for (var doc in usersSnapshot.docs) (doc.data()['email'] as String).toLowerCase(): doc
      };

      final categoriesSnapshot = await _firestore.collection('categories').get();
      final categoriesByName = {
        for (var doc in categoriesSnapshot.docs) doc.data()['name'] as String: doc
      };

      // 2. Read Excel data
      final bytes = await _getFileBytes(_selectedFile!);
      if (bytes == null) throw 'Could not read file for upload.';
      final excel = excel_lib.Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first]!;
      final headers = sheet.rows.first.map((c) => c!.value.toString().trim()).toList();
      final dataRows = sheet.rows.skip(1).toList();

      // 3. Process each row
      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final rowNumber = i + 2; // Excel rows are 1-based, plus header
        final rowData = <String, dynamic>{};
        for (int j = 0; j < headers.length; j++) {
          if (_expectedHeaders.containsKey(headers[j])) {
            final fieldName = _expectedHeaders[headers[j]]!;
            rowData[fieldName] = row.length > j ? row[j]?.value?.toString().trim() : '';
          }
        }

        final businessName = rowData['businessName'] ?? '';

        // 4. Validation logic
        if (businessName.isEmpty || (rowData['phoneNumber'] ?? '').isEmpty) {
          reportEntries.add(ReportEntry(rowNumber: rowNumber, businessName: businessName.isEmpty ? 'Row $rowNumber' : businessName, status: ReportStatus.failure, reason: 'Missing Business Name or Phone Number.'));
          continue;
        }

        final email = (rowData['assignedToEmail'] ?? '').toLowerCase();
        final categoryName = rowData['categoryName'] ?? '';

        if (email.isEmpty || categoryName.isEmpty) {
          reportEntries.add(ReportEntry(rowNumber: rowNumber, businessName: businessName, status: ReportStatus.failure, reason: 'Missing Category or "Assigned To" email.'));
          continue;
        }

        final userDoc = usersByEmail[email];
        if (userDoc == null) {
          reportEntries.add(ReportEntry(rowNumber: rowNumber, businessName: businessName, status: ReportStatus.failure, reason: 'User with email "$email" not found.'));
          continue;
        }
        if (userDoc.data()['isActive'] != true) {
          reportEntries.add(ReportEntry(rowNumber: rowNumber, businessName: businessName, status: ReportStatus.failure, reason: 'User "$email" is not active.'));
          continue;
        }

        final categoryDoc = categoriesByName[categoryName];
        if (categoryDoc == null) {
          reportEntries.add(ReportEntry(rowNumber: rowNumber, businessName: businessName, status: ReportStatus.failure, reason: 'Category "$categoryName" not found.'));
          continue;
        }

        // 5. If valid, prepare and upload lead data
        final leadData = {
          'businessName': businessName,
          'phoneNumber': rowData['phoneNumber'],
          'businessType': rowData['businessType'] ?? 'N/A',
          'name': rowData['name'] ?? 'N/A',
          'turnover': rowData['turnover'] ?? 'N/A',
          'callStatus': _normalizeCallStatus(rowData['callStatus'] ?? ''),
          'categoryName': categoryName,
          'categoryId': categoryDoc.id,
          'assignedToEmail': email,
          'assignedToId': userDoc.id,
          'assignedToName': userDoc.data()['name'],
          'createdAt': FieldValue.serverTimestamp(),
          'feedback': null,
          'isArchived': false,
        };
        await _firestore.collection('business_data').add(leadData);
        reportEntries.add(ReportEntry(rowNumber: rowNumber, businessName: businessName, status: ReportStatus.success, reason: 'Successfully imported.'));

        // Update progress
        setState(() => _uploadProgress = ((i + 1) / dataRows.length * 100).round());
      }

      // 6. Finalize report and navigate
      final report = ImportReport(
        totalRows: dataRows.length,
        successfulImports: reportEntries.where((e) => e.status == ReportStatus.success).length,
        failedImports: reportEntries.where((e) => e.status == ReportStatus.failure).length,
        entries: reportEntries,
      );

      if (mounted) {
        // Reset state before navigating
        setState(() {
          _selectedFile = null;
          _previewData.clear();
          _totalRows = 0;
        });
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ExcelImportReportScreen(report: report)),
        );
      }

    } catch (e) {
      _showSnackbar('A critical error occurred during upload: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
      });
    }
  }

  /// Normalizes call status strings to a standard set of values.
  String _normalizeCallStatus(String status) {
    final s = status.toLowerCase().trim();
    if (s.contains('interested')) return 'interested';
    if (s.contains('not interested') || s.contains('not_interested')) return 'not_interested';
    if (s.contains('not answered') || s.contains('not_answered')) return 'not_answered';
    if (s.contains('follow up') || s.contains('follow_up')) return 'follow_up';
    if (s.contains('advance')) return 'advance paid';
    if (s.contains('paid')) return 'paid';
    return 'pending'; // Default
  }

  /// Helper to show a snackbar message.
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Upload & Assign Leads', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            _buildInstructionsCard(),
            const SizedBox(height: 32),

            // File Selection
            const Text('1. Select Excel File', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildFilePickerCard(),

            if (_isLoading)
              const Center(child: CircularProgressIndicator()),

            // Data Preview
            if (_previewData.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildPreviewSection(),
            ],

            // Upload Section
            const SizedBox(height: 32),
            const Text('2. Upload to Firebase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            if (_isUploading) _buildProgressIndicator(),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: Text(
                  _isUploading ? 'Uploading...' : 'Upload & View Report',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: (_selectedFile != null && !_isLoading && !_isUploading) ? _uploadData : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, color: Colors.green),
            SizedBox(width: 12),
            Text('Excel Upload Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          const Text('Your Excel file MUST contain the following columns:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...(_expectedHeaders.keys.map((header) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text('• $header'),
          ))),
        ],
      ),
    );
  }

  Widget _buildFilePickerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _selectedFile != null ? Colors.green : Colors.grey.shade300, width: 2),
      ),
      child: Column(
        children: [
          if (_selectedFile == null) ...[
            Icon(Icons.cloud_upload_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Choose Excel File to Upload', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ] else ...[
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(_selectedFile!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total Records Found: $_totalRows', style: TextStyle(color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isLoading || _isUploading ? null : _pickFile,
            icon: Icon(_selectedFile == null ? Icons.upload_file : Icons.refresh),
            label: Text(_selectedFile == null ? 'Select File' : 'Change File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data Preview (First 5 Rows)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200)
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
              columns: _expectedHeaders.keys.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              rows: _previewData.map((data) => DataRow(
                cells: _expectedHeaders.values.map((field) => DataCell(Text(data[field]?.toString() ?? ''))).toList(),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('Uploading data... $_uploadProgress%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _uploadProgress / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 10,
          ),
        ],
      ),
    );
  }
}