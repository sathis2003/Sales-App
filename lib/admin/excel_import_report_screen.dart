import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sales/model/import_report.dart';

class ExcelImportReportScreen extends StatefulWidget {
  final ImportReport report;

  const ExcelImportReportScreen({Key? key, required this.report}) : super(key: key);

  @override
  State<ExcelImportReportScreen> createState() => _ExcelImportReportScreenState();
}

class _ExcelImportReportScreenState extends State<ExcelImportReportScreen> {
  bool _showOnlyFailures = false;
  late List<ReportEntry> _filteredEntries;

  @override
  void initState() {
    super.initState();
    _filteredEntries = widget.report.entries;
  }

  void _toggleFilter(bool value) {
    setState(() {
      _showOnlyFailures = value;
      if (_showOnlyFailures) {
        _filteredEntries = widget.report.entries.where((e) => e.status == ReportStatus.failure).toList();
      } else {
        _filteredEntries = widget.report.entries;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Excel Import Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary Header
          _buildSummaryHeader(),

          // Filter Toggle
          Container(
            color: Colors.white,
            child: SwitchListTile(
              title: const Text('Show Only Failures', style: TextStyle(fontWeight: FontWeight.w600)),
              value: _showOnlyFailures,
              onChanged: _toggleFilter,
              activeColor: Colors.red,
              secondary: Icon(Icons.filter_list, color: Colors.grey.shade700),
            ),
          ),

          // Report List
          Expanded(
            child: _filteredEntries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredEntries.length,
              itemBuilder: (context, index) {
                final entry = _filteredEntries[index];
                final isSuccess = entry.status == ReportStatus.success;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSuccess ? Colors.green.shade200 : Colors.red.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      child: Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red),
                    ),
                    title: Text(
                      'Row ${entry.rowNumber}: ${entry.businessName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      entry.reason,
                      style: TextStyle(color: isSuccess ? Colors.grey.shade600 : Colors.red.shade700),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Generated: ${DateFormat.yMMMd().add_jm().format(widget.report.reportDate)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Total Rows', widget.report.totalRows.toString(), Icons.format_list_numbered, Colors.blue),
              _buildStatCard('Successful', widget.report.successfulImports.toString(), Icons.check, Colors.green),
              _buildStatCard('Failed', widget.report.failedImports.toString(), Icons.close, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showOnlyFailures ? Icons.thumb_up_alt : Icons.list_alt,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _showOnlyFailures ? 'No Failures!' : 'No Report Data',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _showOnlyFailures ? 'All filtered rows were imported successfully.' : 'There are no entries to display.',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}