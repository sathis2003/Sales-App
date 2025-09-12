import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AdminLeadsScreen extends StatefulWidget {
  const AdminLeadsScreen({Key? key}) : super(key: key);

  @override
  State<AdminLeadsScreen> createState() => _AdminLeadsScreenState();
}

class _AdminLeadsScreenState extends State<AdminLeadsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  // Call status options with associated colors
  final Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'interested': Colors.green,
    'not_interested': Colors.red,
    'not_answered': Colors.grey,
    'follow_up': Colors.blue,
    'paid': Colors.purple,
    'advance paid': Colors.indigo,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Updates the callStatus of a lead in Firestore.
  Future<void> _updateLeadStatus(String leadId, String newStatus) async {
    try {
      await _firestore.collection('business_data').doc(leadId).update({
        'callStatus': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status updated to: ${newStatus.replaceAll('_', ' ').toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _statusColors[newStatus] ?? Colors.green,
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
            content: Text('Error updating lead status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ** NEW FUNCTION **
  /// Updates the feedback for a lead in Firestore.
  Future<void> _updateFeedback(BuildContext dialogContext, String leadId, String newFeedback) async {
    try {
      await _firestore.collection('business_data').doc(leadId).update({
        'feedback': newFeedback.trim().isEmpty ? null : newFeedback.trim(),
        'feedbackUpdatedAt': newFeedback.trim().isEmpty ? null : FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Close the dialog after saving
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Feedback saved successfully!'),
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
            content: Text('Error saving feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  /// Deletes a lead from Firestore after confirmation.
  Future<void> _deleteLead(String leadId, String businessName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Delete Lead'),
          ],
        ),
        content: Text('Are you sure you want to delete "$businessName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('business_data').doc(leadId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lead "$businessName" deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting lead: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// ** MODIFIED FUNCTION **
  /// Shows a dialog with detailed information about the lead and allows feedback editing.
  void _showLeadDetails(Map<String, dynamic> leadData, String leadId) {
    final feedbackController = TextEditingController(text: leadData['feedback'] ?? '');
    bool isEditingFeedback = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade400, Colors.teal.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              leadData['businessName'] ?? 'Lead Details',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Business Name', leadData['businessName'] ?? 'N/A', Icons.business),
                            _buildDetailRow('Business Type', leadData['businessType'] ?? 'N/A', Icons.category),
                            _buildDetailRow('Contact Name', leadData['name'] ?? 'N/A', Icons.person),
                            _buildDetailRow('Phone Number', leadData['phoneNumber'] ?? 'N/A', Icons.phone),
                            _buildDetailRow('Turnover', leadData['turnover'] ?? 'N/A', Icons.attach_money),
                            _buildDetailRow('Category', leadData['categoryName'] ?? 'N/A', Icons.folder),
                            const Divider(height: 24),

                            // ** NEW: Feedback Section with Edit/Save Logic **
                            Row(
                              children: [
                                Icon(Icons.feedback_outlined, color: Colors.grey.shade600),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Feedback / Notes',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                if (!isEditingFeedback)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.teal),
                                    onPressed: () {
                                      setDialogState(() {
                                        isEditingFeedback = true;
                                      });
                                    },
                                    tooltip: 'Edit Feedback',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (isEditingFeedback)
                              Column(
                                children: [
                                  TextField(
                                    controller: feedbackController,
                                    maxLines: 4,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: 'Add feedback here...',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          setDialogState(() {
                                            isEditingFeedback = false;
                                            // Reset text if cancelled
                                            feedbackController.text = leadData['feedback'] ?? '';
                                          });
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          _updateFeedback(dialogContext, leadId, feedbackController.text);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  )
                                ],
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  feedbackController.text.isEmpty
                                      ? 'No feedback yet. Click the edit icon to add notes.'
                                      : feedbackController.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: feedbackController.text.isEmpty ? Colors.grey.shade600 : Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final DateTime date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  /// Constructs a Firestore query based on the selected filters.
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = _firestore.collection('business_data');
    if (_selectedCategory != 'All') {
      query = query.where('categoryName', isEqualTo: _selectedCategory);
    }
    if (_selectedStatus != 'All') {
      query = query.where('callStatus', isEqualTo: _selectedStatus);
    }
    return query.orderBy('createdAt', descending: true);
  }

  /// Filters leads based on the search query.
  List<DocumentSnapshot> _filterLeads(List<DocumentSnapshot> leads) {
    if (_searchQuery.isEmpty) return leads;
    return leads.where((lead) {
      final data = lead.data() as Map<String, dynamic>;
      final businessName = data['businessName']?.toLowerCase() ?? '';
      final contactName = data['name']?.toLowerCase() ?? '';
      final phoneNumber = data['phoneNumber']?.toLowerCase() ?? '';
      final businessType = data['businessType']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return businessName.contains(query) ||
          contactName.contains(query) ||
          phoneNumber.contains(query) ||
          businessType.contains(query);
    }).toList();
  }

  /// Main widget for building the list of leads.
  Widget _buildLeadsList() {
    return Column(
      children: [
        // Filters Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, type...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('categories').snapshots(),
                      builder: (context, snapshot) {
                        final categories = ['All'];
                        if (snapshot.hasData) {
                          categories.addAll(snapshot.data!.docs
                              .map((doc) =>
                          (doc.data() as Map<String, dynamic>)['name'] as String)
                              .toList());
                        }
                        return DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: categories
                              .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedCategory = value ?? 'All'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['All', ..._statusColors.keys]
                          .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status == 'All' ? status : status.replaceAll('_', ' ').toUpperCase()),
                      ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedStatus = value ?? 'All'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Leads List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final leads = snapshot.data?.docs ?? [];
              final filteredLeads = _filterLeads(leads);

              if (filteredLeads.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No leads found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Try adjusting your search or filters', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredLeads.length,
                itemBuilder: (context, index) {
                  final lead = filteredLeads[index];
                  final leadData = lead.data() as Map<String, dynamic>;
                  final statusColor = _statusColors[leadData['callStatus']] ?? Colors.grey;
                  final currentStatus = leadData['callStatus'] ?? 'pending';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () => _showLeadDetails(leadData, lead.id),
                                      child: Text(
                                        leadData['businessName'] ?? 'No Name',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      leadData['businessType'] ?? 'No Type',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                                onPressed: () => _deleteLead(lead.id, leadData['businessName'] ?? 'Lead'),
                                tooltip: 'Delete Lead',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.person, leadData['name'] ?? 'No Contact'),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.phone, leadData['phoneNumber'] ?? 'No Phone'),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.folder, leadData['categoryName'] ?? 'No Category'),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Text(
                                'Status:',
                                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withOpacity(0.5)),
                                  ),
                                  child: DropdownButton<String>(
                                    value: currentStatus,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    icon: Icon(Icons.arrow_drop_down, color: statusColor),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        _updateLeadStatus(lead.id, newValue);
                                      }
                                    },
                                    items:
                                    _statusColors.keys.map<DropdownMenuItem<String>>((String status) {
                                      return DropdownMenuItem<String>(
                                        value: status,
                                        child: Row(
                                          children: [
                                            Icon(Icons.circle, color: _statusColors[status], size: 12),
                                            const SizedBox(width: 8),
                                            Text(
                                              status.replaceAll('_', ' ').toUpperCase(),
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Helper widget to build a consistent info row in the lead card.
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('business_data').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final leads = snapshot.data?.docs ?? [];
        final Map<String, int> categoryStats = {};
        final Map<String, int> statusStats = {};
        for (var lead in leads) {
          final data = lead.data() as Map<String, dynamic>;
          final category = data['categoryName'] ?? 'Unknown';
          final status = data['callStatus'] ?? 'pending';
          categoryStats[category] = (categoryStats[category] ?? 0) + 1;
          statusStats[status] = (statusStats[status] ?? 0) + 1;
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Total Leads Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text('${leads.length}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal)),
                      const Text('Total Leads in System', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Leads by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...categoryStats.entries.map((entry) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder, color: Colors.teal),
                  title: Text(entry.key),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(entry.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                ),
              )),
              const SizedBox(height: 20),
              const Text('Leads by Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...statusStats.entries.map((entry) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                      width: 20, height: 20, decoration: BoxDecoration(color: _statusColors[entry.key] ?? Colors.grey, shape: BoxShape.circle)),
                  title: Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: (_statusColors[entry.key] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(entry.value.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: _statusColors[entry.key] ?? Colors.grey)),
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.download, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Export Functionality', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Export leads data to Excel or CSV format for external use.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Export functionality will be implemented soon!'), backgroundColor: Colors.orange),
                      );
                    },
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export to Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('View All Leads', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'All Leads'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
            Tab(icon: Icon(Icons.download), text: 'Export'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeadsList(),
          _buildStatsTab(),
          _buildExportTab(),
        ],
      ),
    );
  }
}