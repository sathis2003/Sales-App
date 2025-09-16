// lib/models/import_report.dart

/// Represents the status of an individual row import.
enum ReportStatus { success, failure }

/// Holds the result for a single row from the imported Excel file.
class ReportEntry {
  final int rowNumber;
  final String businessName;
  final ReportStatus status;
  final String reason; // "Success" or a specific error message

  ReportEntry({
    required this.rowNumber,
    required this.businessName,
    required this.status,
    required this.reason,
  });
}

/// A comprehensive report summarizing the entire Excel import process.
class ImportReport {
  final int totalRows;
  final int successfulImports;
  final int failedImports;
  final List<ReportEntry> entries;
  final DateTime reportDate;

  ImportReport({
    required this.totalRows,
    required this.successfulImports,
    required this.failedImports,
    required this.entries,
  }) : reportDate = DateTime.now();
}