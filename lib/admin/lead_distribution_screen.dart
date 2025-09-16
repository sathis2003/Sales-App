// lib/admin/lead_distribution_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class LeadDistributionScreen extends StatefulWidget {
  const LeadDistributionScreen({Key? key}) : super(key: key);

  @override
  State<LeadDistributionScreen> createState() => _LeadDistributionScreenState();
}

class _LeadDistributionScreenState extends State<LeadDistributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form state variables
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedStatus;
  String? _selectedUserId;
  final _quantityController = TextEditingController();

  // UI state variables
  int? _availableLeadsCount;
  bool _isFetchingCount = false;
  bool _isAssigning = false;

  // Data for dropdowns
  List<DocumentSnapshot> _categories = [];
  List<DocumentSnapshot> _users = [];
  final List<String> _leadStatuses = [
    'pending',
    'interested',
    'not_interested',
    'not_answered',
    'follow_up',
    'paid',
    'advance paid',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// Fetches initial data for category and user dropdowns.
  Future<void> _fetchDropdownData() async {
    final categoriesSnapshot = await _firestore.collection('categories').where('isActive', isEqualTo: true).get();
    final usersSnapshot = await _firestore.collection('users').where('isActive', isEqualTo: true).where('role', isEqualTo: 'user').get();
    setState(() {
      _categories = categoriesSnapshot.docs;
      _users = usersSnapshot.docs;
    });
  }

  /// Queries Firestore to count available, unassigned leads based on filters.
  Future<void> _fetchAvailableLeadsCount() async {
    if (_selectedCategoryId == null || _selectedStatus == null) {
      _showSnackbar('Please select both a category and a status first.', isError: true);
      return;
    }

    setState(() {
      _isFetchingCount = true;
      _availableLeadsCount = null;
    });

    try {
      final query = _firestore
          .collection('business_data')
          .where('categoryName', isEqualTo: _selectedCategoryName)
          .where('callStatus', isEqualTo: _selectedStatus)
          .where('assignedToId', isEqualTo: null); // IMPORTANT: Only fetch unassigned leads

      final snapshot = await query.count().get();
      setState(() {
        _availableLeadsCount = snapshot.count;
      });
    } catch (e) {
      _showSnackbar('Error fetching lead count: $e', isError: true);
    } finally {
      setState(() => _isFetchingCount = false);
    }
  }

  /// Assigns the specified quantity of leads to the selected user.
  Future<void> _assignLeads() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedUserId == null) {
      _showSnackbar('Please select a user to assign leads to.', isError: true);
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;

    setState(() => _isAssigning = true);

    try {
      // 1. Get the leads to be assigned
      final query = _firestore
          .collection('business_data')
          .where('categoryName', isEqualTo: _selectedCategoryName)
          .where('callStatus', isEqualTo: _selectedStatus)
          .where('assignedToId', isEqualTo: null)
          .limit(quantity);

      final leadsToAssignSnapshot = await query.get();

      if (leadsToAssignSnapshot.docs.isEmpty) {
        _showSnackbar('No leads were found to assign. The leads might have been assigned by someone else.', isError: true);
        setState(() => _isAssigning = false);
        _resetForm(resetFilters: false);
        return;
      }

      // 2. Get assignee's details
      final userDoc = _users.firstWhere((doc) => doc.id == _selectedUserId);
      final userData = userDoc.data() as Map<String, dynamic>;

      // 3. Use a batch write to update all documents atomically
      final batch = _firestore.batch();
      for (final doc in leadsToAssignSnapshot.docs) {
        batch.update(doc.reference, {
          'assignedToId': userDoc.id,
          'assignedToName': userData['name'],
          'assignedToEmail': userData['email'],
          'assignedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      _showSnackbar('${leadsToAssignSnapshot.docs.length} leads successfully assigned to ${userData['name']}.');
      _resetForm();

    } catch (e) {
      _showSnackbar('Error assigning leads: $e', isError: true);
    } finally {
      setState(() => _isAssigning = false);
    }
  }

  void _resetForm({bool resetFilters = true}) {
    _quantityController.clear();
    setState(() {
      if (resetFilters) {
        _selectedCategoryId = null;
        _selectedCategoryName = null;
        _selectedStatus = null;
      }
      _selectedUserId = null;
      _availableLeadsCount = null;
    });
    _formKey.currentState?.reset();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Bulk Lead Distribution', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Step 1: Filter Unassigned Leads',
                'Select a category and status to find available leads for assignment.',
              ),
              const SizedBox(height: 20),
              _buildCard(
                child: Column(
                  children: [
                    _buildCategoryDropdown(),
                    const SizedBox(height: 16),
                    _buildStatusDropdown(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: _isFetchingCount
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: const Text('Find Available Leads'),
                        onPressed: _isFetchingCount ? null : _fetchAvailableLeadsCount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_availableLeadsCount != null) ...[
                _buildSectionHeader(
                  'Step 2: Assign Leads',
                  'Specify the quantity of leads to assign and choose a user.',
                ),
                const SizedBox(height: 20),
                _buildCard(
                  child: Column(
                    children: [
                      _buildCountDisplay(),
                      const SizedBox(height: 20),
                      _buildQuantityInput(),
                      const SizedBox(height: 16),
                      _buildUserDropdown(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: _isAssigning
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.assignment_turned_in),
                          label: const Text('Assign Leads'),
                          onPressed: (_availableLeadsCount ?? 0) > 0 && !_isAssigning ? _assignLeads : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: child,
      ),
    );
  }

  Widget _buildCountDisplay() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _availableLeadsCount! > 0 ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _availableLeadsCount! > 0 ? Colors.green.shade200 : Colors.orange.shade200)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                _availableLeadsCount! > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: _availableLeadsCount! > 0 ? Colors.green.shade700 : Colors.orange.shade700
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_availableLeadsCount leads found',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _availableLeadsCount! > 0 ? Colors.green.shade800 : Colors.orange.shade800
                ),
              ),
            )
          ],
        )
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      decoration: const InputDecoration(labelText: 'Select Category', border: OutlineInputBorder()),
      items: _categories.map((doc) {
        return DropdownMenuItem(
          value: doc.id,
          child: Text((doc.data() as Map<String, dynamic>)['name']),
        );
      }).toList(),
      onChanged: (value) => setState(() {
        _selectedCategoryId = value;
        _selectedCategoryName = (_categories.firstWhere((doc) => doc.id == value).data() as Map<String, dynamic>)['name'];
        _availableLeadsCount = null; // Reset count on filter change
      }),
      validator: (value) => value == null ? 'Please select a category' : null,
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      decoration: const InputDecoration(labelText: 'Select Lead Status', border: OutlineInputBorder()),
      items: _leadStatuses.map((status) {
        return DropdownMenuItem(
          value: status,
          child: Text(status.replaceAll('_', ' ').toUpperCase()),
        );
      }).toList(),
      onChanged: (value) => setState(() {
        _selectedStatus = value;
        _availableLeadsCount = null; // Reset count on filter change
      }),
      validator: (value) => value == null ? 'Please select a status' : null,
    );
  }

  Widget _buildQuantityInput() {
    return TextFormField(
      controller: _quantityController,
      decoration: const InputDecoration(labelText: 'Quantity to Assign', border: OutlineInputBorder()),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter a quantity';
        final num = int.tryParse(value);
        if (num == null || num <= 0) return 'Quantity must be greater than 0';
        if (num > (_availableLeadsCount ?? 0)) return 'Cannot exceed available leads';
        return null;
      },
    );
  }

  Widget _buildUserDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUserId,
      decoration: const InputDecoration(labelText: 'Assign To User', border: OutlineInputBorder()),
      items: _users.map((doc) {
        return DropdownMenuItem(
          value: doc.id,
          child: Text((doc.data() as Map<String, dynamic>)['name']),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedUserId = value),
      validator: (value) => value == null ? 'Please select a user' : null,
    );
  }
}