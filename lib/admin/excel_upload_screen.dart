import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:typed_data';

// ** NEW IMPORTS **
// Import for checking the platform (web vs. mobile)
import 'package:flutter/foundation.dart' show kIsWeb;
// Import for reading files on mobile
import 'dart:io' as io;


class ExcelUploadScreen extends StatefulWidget {
  const ExcelUploadScreen({Key? key}) : super(key: key);

  @override
  State<ExcelUploadScreen> createState() => _ExcelUploadScreenState();
}

class _ExcelUploadScreenState extends State<ExcelUploadScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  PlatformFile? _selectedFile;
  List<Map<String, dynamic>> _previewData = [];
  bool _isLoading = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _totalRows = 0;

  // Expected column headers
  final Map<String, String> _expectedHeaders = {
    'Business Name': 'businessName',
    'Business Type': 'businessType',
    'Contact Name': 'name',
    'Phone Number': 'phoneNumber',
    'Turnover': 'turnover',
    'Call Status': 'callStatus',
  };

  /// ** NEW HELPER FUNCTION **
  /// Reads file bytes in a cross-platform way.
  Future<Uint8List?> _getFileBytes(PlatformFile file) async {
    // For web, bytes are available directly in memory.
    if (kIsWeb) {
      return file.bytes;
    }
    // For mobile, read the file from the provided path.
    else if (file.path != null) {
      return await io.File(file.path!).readAsBytes();
    }
    return null;
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        // ** MODIFIED **
        // On mobile, this helps ensure bytes can be read, but our helper is more robust.
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _previewData.clear();
        });
        await _processExcelFile();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processExcelFile() async {
    if (_selectedFile == null) return;

    setState(() => _isLoading = true);

    try {
      // ** MODIFIED: Use the cross-platform helper to get file bytes **
      final bytes = await _getFileBytes(_selectedFile!);
      if (bytes == null) throw 'Could not read file bytes. The file might be corrupt or inaccessible.';

      final excel = excel_lib.Excel.decodeBytes(bytes);

      // Get the first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        throw 'Excel sheet is empty or could not be read';
      }

      // Get headers from first row
      final headerRow = sheet.rows.first;
      final headers = headerRow.map((cell) => cell?.value?.toString() ?? '').toList();

      // Validate headers
      final missingHeaders = <String>[];
      for (String expectedHeader in _expectedHeaders.keys) {
        if (!headers.contains(expectedHeader)) {
          missingHeaders.add(expectedHeader);
        }
      }

      if (missingHeaders.isNotEmpty) {
        throw 'Missing required columns: ${missingHeaders.join(', ')}\n\nExpected columns: ${_expectedHeaders.keys.join(', ')}';
      }

      // Process data rows (skip header)
      final dataRows = sheet.rows.skip(1).toList();
      _previewData.clear();

      for (int i = 0; i < dataRows.length && i < 10; i++) { // Show max 10 rows for preview
        final row = dataRows[i];
        final rowData = <String, dynamic>{};

        for (int j = 0; j < headers.length && j < row.length; j++) {
          final header = headers[j];
          final cellValue = row[j]?.value?.toString()?.trim() ?? '';

          if (_expectedHeaders.containsKey(header)) {
            final fieldName = _expectedHeaders[header]!;
            rowData[fieldName] = cellValue;
          }
        }

        // Validate required fields
        if (rowData['businessName']?.isNotEmpty == true &&
            rowData['phoneNumber']?.isNotEmpty == true) {
          _previewData.add(rowData);
        }
      }

      setState(() {
        _totalRows = dataRows.length;
      });

      if (_previewData.isEmpty) {
        throw 'No valid data rows found. Please check that Business Name and Phone Number columns have data.';
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing Excel file: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _selectedFile = null;
        _previewData.clear();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadData() async {
    if (_selectedFile == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both category and Excel file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      // ** MODIFIED: Use the cross-platform helper to get file bytes **
      final bytes = await _getFileBytes(_selectedFile!);
      if (bytes == null) throw 'Could not read file bytes before uploading.';

      final excel = excel_lib.Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      final headerRow = sheet.rows.first;
      final headers = headerRow.map((cell) => cell?.value?.toString() ?? '').toList();
      final dataRows = sheet.rows.skip(1).toList();

      // Process all rows
      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final rowData = <String, dynamic>{
          'categoryId': _selectedCategoryId,
          'categoryName': _selectedCategoryName,
          'createdAt': FieldValue.serverTimestamp(),
          'feedback': null,
          'feedbackUpdatedAt': null,
          'isArchived': false,
        };

        // Map Excel data to Firestore fields
        for (int j = 0; j < headers.length && j < row.length; j++) {
          final header = headers[j];
          final cellValue = row[j]?.value?.toString()?.trim() ?? '';

          if (_expectedHeaders.containsKey(header)) {
            final fieldName = _expectedHeaders[header]!;

            if (fieldName == 'callStatus') {
              // Validate and normalize call status
              final normalizedStatus = _normalizeCallStatus(cellValue);
              rowData[fieldName] = normalizedStatus;
            } else {
              rowData[fieldName] = cellValue;
            }
          }
        }

        // Skip rows without required data
        if (rowData['businessName']?.isEmpty == true ||
            rowData['phoneNumber']?.isEmpty == true) {
          continue;
        }

        // Set defaults for missing fields
        rowData['businessType'] = rowData['businessType']?.isEmpty == true
            ? 'Not specified'
            : rowData['businessType'];
        rowData['name'] = rowData['name']?.isEmpty == true
            ? 'Not specified'
            : rowData['name'];
        rowData['turnover'] = rowData['turnover']?.isEmpty == true
            ? 'Not specified'
            : rowData['turnover'];

        // Add to Firestore
        await _firestore.collection('business_data').add(rowData);

        // Update progress
        setState(() {
          _uploadProgress = ((i + 1) / dataRows.length * 100).round();
        });
      }

      // Clear form after successful upload
      setState(() {
        _selectedFile = null;
        _selectedCategoryId = null;
        _selectedCategoryName = null;
        _previewData.clear();
        _uploadProgress = 0;
        _totalRows = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Successfully uploaded ${dataRows.length} leads!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  String _normalizeCallStatus(String status) {
    final normalizedStatus = status.toLowerCase().trim();
    switch (normalizedStatus) {
      case 'pending':
      case 'waiting':
      case 'scheduled':
        return 'pending';
      case 'interested':
      case 'positive':
      case 'yes':
        return 'interested';
      case 'not interested':
      case 'not_interested':
      case 'negative':
      case 'no':
        return 'not_interested';
      case 'not answered':
      case 'not_answered':
      case 'no answer':
        return 'not_answered';
      case 'follow up':
      case 'follow_up':
      case 'callback':
        return 'follow_up';
      case 'paid':
      case 'payment received':
        return 'paid';
      case 'advance paid':
      case 'advance_paid':
      case 'advance':
        return 'advance paid';
      default:
        return 'pending'; // Default fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Upload Excel Data',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade100, Colors.green.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Excel Upload Instructions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Required Excel Columns:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_expectedHeaders.keys.map((header) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          header,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ))),
                  const SizedBox(height: 16),
                  Text(
                    'Call Status options: pending, interested, not_interested, not_answered, follow_up, paid, advance paid',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Category Selection
            const Text(
              'Select Target Category',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('categories').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                final categories = snapshot.data?.docs ?? [];

                if (categories.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No categories found. Create categories first.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: categories.map((category) {
                      final categoryData = category.data() as Map<String, dynamic>;
                      final categoryName = categoryData['name'] ?? 'Unnamed';
                      final isSelected = _selectedCategoryId == category.id;
                      final colorValue = categoryData['colorValue'] ?? Colors.blue.value;
                      final categoryColor = Color(colorValue);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategoryId = category.id;
                            _selectedCategoryName = categoryName;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? categoryColor.withOpacity(0.15)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? categoryColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.category,
                                  color: categoryColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  categoryName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? categoryColor
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: categoryColor,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // File Selection
            const Text(
              'Select Excel File',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedFile != null
                      ? Colors.green
                      : Colors.grey.shade300,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_selectedFile == null) ...[
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose Excel File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supported formats: .xlsx, .xls',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.insert_drive_file,
                      size: 48,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFile!.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Size: ${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isLoading || _isUploading ? null : _pickFile,
                    icon: Icon(_selectedFile == null ? Icons.upload_file : Icons.refresh),
                    label: Text(_selectedFile == null ? 'Select File' : 'Change File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading) ...[
              const SizedBox(height: 20),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 12),
                    Text(
                      'Processing Excel file...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],

            // Preview Data
            if (_previewData.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  const Text(
                    'Data Preview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$_totalRows total rows',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                    columns: _expectedHeaders.keys.map((header) => DataColumn(
                      label: Text(
                        header,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )).toList(),
                    rows: _previewData.map((data) => DataRow(
                      cells: _expectedHeaders.values.map((field) => DataCell(
                        Text(
                          data[field]?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                    )).toList(),
                  ),
                ),
              ),
            ],

            // Upload Progress
            if (_isUploading) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_upload, color: Colors.green),
                        const SizedBox(width: 12),
                        Text(
                          'Uploading data... $_uploadProgress%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _uploadProgress / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Upload Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_selectedCategoryId != null &&
                    _selectedFile != null &&
                    _previewData.isNotEmpty &&
                    !_isLoading &&
                    !_isUploading)
                    ? _uploadData
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      _isUploading
                          ? 'Uploading... $_uploadProgress%'
                          : 'Upload Data to Firebase',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}