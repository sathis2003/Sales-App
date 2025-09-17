// lib/DetailedScreen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'LeadDetailsScreen.dart';

class CategoryDetailPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryDetailPage({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  String _selectedFilter = 'all';
  bool _showArchived = false;

  final List<Map<String, dynamic>> _callStatusOptions = [
    {'value': 'all', 'label': 'All Status', 'color': Colors.grey, 'icon': Icons.list},
    {'value': 'pending', 'label': 'Pending', 'color': Colors.blue, 'icon': Icons.pending},
    {'value': 'paid', 'label': 'Paid', 'color': Colors.green, 'icon': Icons.attach_money},
    {'value': 'interested', 'label': 'Interested', 'color': Colors.teal, 'icon': Icons.thumb_up},
    {'value': 'not_interested', 'label': 'Not Interested', 'color': Colors.red, 'icon': Icons.cancel},
    {'value': 'follow_up', 'label': 'Follow Up', 'color': Colors.orange, 'icon': Icons.follow_the_signs},
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  void _showAddLeadDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _AddLeadDialog(
          currentUser: _currentUser,
          categoryName: widget.categoryName,
          callStatusOptions: _callStatusOptions,
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Leads'),
          content: DropdownButton<String>(
            value: _selectedFilter,
            isExpanded: true,
            items: _callStatusOptions
                .map<DropdownMenuItem<String>>(
                  (status) => DropdownMenuItem<String>(
                value: status['value'],
                child: Text(status['label']),
              ),
            )
                .toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedFilter = newValue;
                });
                Navigator.of(context).pop();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _updateArchiveStatus(String leadId, bool isArchived) async {
    await _firestore
        .collection('business_data')
        .doc(leadId)
        .update({'isArchived': isArchived});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArchived ? 'Lead archived' : 'Lead unarchived'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(_showArchived ? Icons.unarchive : Icons.archive),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
            },
          ),
        ],
      ),
      body: _currentUser == null
          ? const Center(child: Text("User not logged in."))
          : StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                _showArchived
                    ? 'No archived leads in this category.'
                    : 'No leads assigned to you in this category.',
              ),
            );
          }

          final leads = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: leads.length,
            itemBuilder: (context, index) {
              final lead = leads[index];
              final data = lead.data() as Map<String, dynamic>;
              final statusInfo = _callStatusOptions.firstWhere(
                    (s) => s['value'] == data['callStatus'],
                orElse: () => {'color': Colors.grey, 'label': 'Unknown'},
              );

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessDataDetailPage(
                          documentId: lead.id,
                          businessData: data,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['businessName'] ?? 'No Name',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (statusInfo['color'] as Color).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusInfo['label'],
                                style: TextStyle(
                                  color: statusInfo['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['businessType'] ?? 'No Type',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'Contact',
                          data['name'] ?? 'N/A',
                          Icons.person,
                          Colors.blueGrey,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                'Phone',
                                data['phoneNumber'] ?? 'N/A',
                                Icons.phone,
                                Colors.green,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              tooltip: 'Call',
                              onPressed: () async {
                                final number = data['phoneNumber'];
                                if (number != null && number.isNotEmpty) {
                                  await FlutterPhoneDirectCaller.callNumber(number);
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(_showArchived ? Icons.unarchive : Icons.archive, color: Colors.grey),
                              tooltip: _showArchived ? 'Unarchive' : 'Archive',
                              onPressed: () {
                                _updateArchiveStatus(lead.id, !_showArchived);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLeadDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Lead'),
      ),
    );
  }

  Query _buildQuery() {
    Query query = _firestore
        .collection('business_data')
        .where('categoryName', isEqualTo: widget.categoryName)
        .where('assignedToId', isEqualTo: _currentUser!.uid)
        .where('isArchived', isEqualTo: _showArchived);

    if (_selectedFilter != 'all') {
      query = query.where('callStatus', isEqualTo: _selectedFilter);
    }

    return query.orderBy('createdAt', descending: true);
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddLeadDialog extends StatefulWidget {
  final User? currentUser;
  final String categoryName;
  final List<Map<String, dynamic>> callStatusOptions;

  const _AddLeadDialog({
    Key? key,
    required this.currentUser,
    required this.categoryName,
    required this.callStatusOptions,
  }) : super(key: key);

  @override
  __AddLeadDialogState createState() => __AddLeadDialogState();
}

class __AddLeadDialogState extends State<_AddLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _nameController = TextEditingController();
  final _turnOverController = TextEditingController();
  final _phoneController = TextEditingController();
  String _callStatus = 'pending';

  Future<void> _addLead() async {
    if (_formKey.currentState!.validate()) {
      if (widget.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to add a lead.')),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('business_data').add({
        'businessName': _businessNameController.text,
        'businessType': _businessTypeController.text,
        'name': _nameController.text,
        'turnover': _turnOverController.text,
        'phoneNumber': _phoneController.text,
        'callStatus': _callStatus,
        'categoryName': widget.categoryName,
        'createdAt': FieldValue.serverTimestamp(),
        'assignedToId': widget.currentUser!.uid,
        'assignedToName': widget.currentUser!.displayName ?? 'N/A',
        'assignedToEmail': widget.currentUser!.email,
        'assignedAt': FieldValue.serverTimestamp(),
        'isArchived': false,
      });

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add New Lead'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(labelText: 'Business Name', prefixIcon: Icon(Icons.business)),
                validator: (value) => value!.isEmpty ? 'Please enter a business name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessTypeController,
                decoration: const InputDecoration(labelText: 'Business Type', prefixIcon: Icon(Icons.category)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Contact Name', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _turnOverController,
                decoration: const InputDecoration(labelText: 'Turnover', prefixIcon: Icon(Icons.monetization_on)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _callStatus,
                decoration: const InputDecoration(labelText: 'Call Status', prefixIcon: Icon(Icons.ring_volume)),
                items: widget.callStatusOptions
                    .where((e) => e['value'] != 'all')
                    .map<DropdownMenuItem<String>>((status) => DropdownMenuItem<String>(
                  value: status['value'],
                  child: Text(status['label']),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _callStatus = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _addLead,
          child: const Text('Add Lead'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _nameController.dispose();
    _turnOverController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}