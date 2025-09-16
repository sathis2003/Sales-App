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
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _nameController = TextEditingController();
  final _turnOverController = TextEditingController();
  final _phoneController = TextEditingController();

  String _callStatus = 'pending';
  final List<Map<String, dynamic>> _callStatusOptions = [
    {'value': 'all', 'label': 'All Status', 'color': Colors.grey, 'icon': Icons.list},
    {'value': 'pending', 'label': 'Pending', 'color': Colors.blue, 'icon': Icons.pending},
    {'value': 'paid', 'label': 'Paid', 'color': Colors.green, 'icon': Icons.check_circle},
    {'value': 'advance paid', 'label': 'Advance Paid', 'color': Colors.lightGreen, 'icon': Icons.payments},
    {'value': 'interested', 'label': 'Interested', 'color': Colors.orange, 'icon': Icons.favorite},
    {'value': 'not_answered', 'label': 'Not Answered', 'color': Colors.red, 'icon': Icons.call_missed},
    {'value': 'not_interested', 'label': 'Not Interested', 'color': Colors.redAccent, 'icon': Icons.cancel},
    {'value': 'follow_up', 'label': 'Follow Up', 'color': Colors.purple, 'icon': Icons.follow_the_signs},
  ];

  // Filter variables
  String _selectedFilter = 'all';
  String _defaultFilter = 'all';
  bool _isLoadingPreferences = true;
  String? _userPreferencesDocId;


  // Archive view toggle
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultFilter();
  }

  // Load default filter from Firebase
  Future<void> _loadDefaultFilter() async {
    try {
      final querySnapshot = await _firestore
          .collection('user_preferences')
          .where('categoryId', isEqualTo: widget.categoryId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        _userPreferencesDocId = doc.id;

        setState(() {
          _defaultFilter = data['defaultFilter'] ?? 'all';
          _selectedFilter = _defaultFilter;
          _isLoadingPreferences = false;
        });
      } else {
        setState(() {
          _isLoadingPreferences = false;
        });

        // Show dialog after frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSetInitialDefaultFilterDialog();
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
      setState(() {
        _isLoadingPreferences = false;
      });
    }
  }

  // Show initial default filter dialog
  void _showSetInitialDefaultFilterDialog() {
    String tempDefaultFilter = _defaultFilter;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.filter_list, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Set Default Filter',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Choose your default filter for "${widget.categoryName}". This will be applied every time you open this category.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ..._callStatusOptions.map((option) {
                  final isSelected = tempDefaultFilter == option['value'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setDialogState(() {
                          tempDefaultFilter = option['value'];
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? option['color'].withOpacity(0.15)
                              : Colors.grey.shade50,
                          border: Border.all(
                            color: isSelected
                                ? option['color']
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? option['color']
                                    : option['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                option['icon'],
                                color: isSelected
                                    ? Colors.white
                                    : option['color'],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option['label'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? option['color']
                                      : Colors.grey[800],
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: option['color'],
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveDefaultFilter(tempDefaultFilter);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Set Default Filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Save default filter to Firebase
  Future<void> _saveDefaultFilter(String filter) async {
    try {
      if (_userPreferencesDocId != null) {
        await _firestore
            .collection('user_preferences')
            .doc(_userPreferencesDocId)
            .update({
          'defaultFilter': filter,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final docRef = await _firestore.collection('user_preferences').add({
          'categoryId': widget.categoryId,
          'categoryName': widget.categoryName,
          'defaultFilter': filter,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _userPreferencesDocId = docRef.id;
      }

      setState(() {
        _defaultFilter = filter;
        _selectedFilter = filter;
      });

      if (mounted) {
        final selectedOption = _callStatusOptions.firstWhere((option) => option['value'] == filter);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Default filter set to: ${selectedOption['label']}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error saving preference: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Show set default filter dialog (for changing existing default)
  void _showSetDefaultFilterDialog() {
    String tempDefault = _defaultFilter;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.star, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Change Default Filter',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Choose new default filter for this category:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ..._callStatusOptions.map((option) {
                  final isSelected = tempDefault == option['value'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setDialogState(() {
                          tempDefault = option['value'];
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? option['color'].withOpacity(0.15)
                              : Colors.grey.shade50,
                          border: Border.all(
                            color: isSelected
                                ? option['color']
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? option['color']
                                    : option['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                option['icon'],
                                color: isSelected
                                    ? Colors.white
                                    : option['color'],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option['label'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? option['color']
                                      : Colors.grey[800],
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: option['color'],
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _saveDefaultFilter(tempDefault);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Get filtered stream based on selected filter and archive status
  Stream<QuerySnapshot> _getFilteredStream() {
    if (_currentUser == null) {
      // If there's no user logged in, return an empty stream.
      return const Stream.empty();
    }

    Query query = _firestore
        .collection('business_data')
        .where('categoryId', isEqualTo: widget.categoryId)
        .where('assignedToId', isEqualTo: _currentUser!.uid) // <<< This is the crucial new filter
        .where('isArchived', isEqualTo: _showArchived);

    if (_selectedFilter != 'all') {
      query = query.where('callStatus', isEqualTo: _selectedFilter);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }


  // Add business data to Firebase
  Future<void> _addBusinessData() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _firestore.collection('business_data').add({
        'categoryId': widget.categoryId,
        'categoryName': widget.categoryName,
        'businessName': _businessNameController.text.trim(),
        'businessType': _businessTypeController.text.trim(),
        'callStatus': _callStatus,
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'turnover': _turnOverController.text.trim(), // Fixed: using 'turnover' instead of 'turnOver'
        'createdAt': FieldValue.serverTimestamp(),
        'feedback': null,
        'feedbackUpdatedAt': null,
        'isArchived': false,
      });

      _businessNameController.clear();
      _businessTypeController.clear();
      _nameController.clear();
      _turnOverController.clear();
      _phoneController.clear();
      setState(() {
        _callStatus = 'pending';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Business data added successfully!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error adding data: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Unarchive business data
  Future<void> _unarchiveBusinessData(String documentId, String businessName) async {
    try {
      await _firestore.collection('business_data').doc(documentId).update({
        'isArchived': false,
        'unarchivedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.unarchive, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$businessName has been restored!',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error restoring lead: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Permanently delete business data
  Future<void> _permanentlyDeleteBusinessData(String documentId, String businessName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Permanent Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "$businessName"?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('business_data').doc(documentId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.delete_forever, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$businessName has been permanently deleted!',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error deleting lead: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  void _showAddDataDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_business, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Add Business Lead',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildFormField(
                          controller: _businessNameController,
                          label: 'Business Name',
                          icon: Icons.business,
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Business name is required' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildFormField(
                          controller: _businessTypeController,
                          label: 'Business Type',
                          icon: Icons.category,
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Business type is required' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildFormField(
                          controller: _nameController,
                          label: 'Contact Name',
                          icon: Icons.person,
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Contact name is required' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildFormField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone,
                          validator: (value) {
                            if (value?.trim().isEmpty == true) return 'Phone number is required';
                            if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(value!)) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildFormField(
                          controller: _turnOverController,
                          label: 'Annual Turnover',
                          icon: Icons.monetization_on,
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Turnover is required' : null,
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: _callStatus,
                          decoration: InputDecoration(
                            labelText: 'Call Status',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.green, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(Icons.call, color: Colors.green),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                          items: _callStatusOptions.where((option) => option['value'] != 'all').map((option) {
                            return DropdownMenuItem(
                              value: option['value'] as String,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: option['color'].withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      option['icon'],
                                      size: 16,
                                      color: option['color'],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(option['label']),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _callStatus = value ?? 'pending';
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    Navigator.pop(context);
                                    _addBusinessData();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'Add Lead',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(icon, color: Colors.green),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      validator: validator,
      style: const TextStyle(fontSize: 16),
    );
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('No phone number available'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    try {
      bool? res = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (res != true) {
        throw 'Could not initiate call';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Could not make call: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPreferences) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(widget.categoryName),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading preferences...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Archive toggle button
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: _showArchived
                  ? Colors.blue.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _showArchived ? Colors.blue : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _showArchived = !_showArchived;
                  // Reset filter to 'all' when switching between archived/active
                  _selectedFilter = 'all';
                });
              },
              icon: Icon(
                _showArchived ? Icons.archive : Icons.unarchive,
                color: _showArchived ? Colors.blue : Colors.grey.shade600,
                size: 20,
              ),
              tooltip: _showArchived ? 'Show Active Leads' : 'Show Archived Leads',
            ),
          ),
          if (!_showArchived) ...[
            IconButton(
              onPressed: _showSetDefaultFilterDialog,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star, color: Colors.orange, size: 20),
              ),
              tooltip: 'Change Default Filter',
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Filter Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _showArchived
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _showArchived ? Icons.archive : Icons.filter_list,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _showArchived ? 'Archived Leads' : 'Filter by Status',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (!_showArchived && _defaultFilter != 'all' && _selectedFilter == _defaultFilter)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade300, Colors.orange.shade500],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_showArchived)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.archive, size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Archive View',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _callStatusOptions.map((option) {
                      final isSelected = _selectedFilter == option['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFilter = option['value'];
                            });
                          },
                          borderRadius: BorderRadius.circular(25),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? option['color']
                                  : option['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: option['color'].withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ] : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  option['icon'],
                                  size: 18,
                                  color: isSelected ? Colors.white : option['color'],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  option['label'],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : option['color'],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading business data...'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final businessData = snapshot.data?.docs ?? [];

                if (businessData.isEmpty) {
                  final selectedOption = _callStatusOptions.firstWhere(
                          (option) => option['value'] == _selectedFilter
                  );

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _showArchived
                                      ? Colors.blue.withOpacity(0.1)
                                      : selectedOption['color'].withOpacity(0.1),
                                  _showArchived
                                      ? Colors.blue.withOpacity(0.05)
                                      : selectedOption['color'].withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              _showArchived
                                  ? Icons.archive_outlined
                                  : selectedOption['icon'],
                              size: 80,
                              color: _showArchived
                                  ? Colors.blue.withOpacity(0.6)
                                  : selectedOption['color'].withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _showArchived
                                ? (_selectedFilter == 'all'
                                ? 'No Archived Leads'
                                : 'No Archived ${selectedOption['label']} Records')
                                : (_selectedFilter == 'all'
                                ? 'No Business Data Yet'
                                : 'No ${selectedOption['label']} Records'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _showArchived
                                ? (_selectedFilter == 'all'
                                ? 'No leads have been archived yet.'
                                : 'No archived leads with ${selectedOption['label'].toLowerCase()} status.')
                                : (_selectedFilter == 'all'
                                ? 'Start by adding your first business lead for this category!'
                                : 'No business records found with ${selectedOption['label'].toLowerCase()} status.'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          if (!_showArchived)
                            ElevatedButton.icon(
                              onPressed: _showAddDataDialog,
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Add First Lead'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedOption['color'],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 4,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: businessData.length,
                  itemBuilder: (context, index) {
                    final document = businessData[index];
                    final data = document.data() as Map<String, dynamic>;
                    final createdAt = data['createdAt'] as Timestamp?;
                    final archivedAt = data['archivedAt'] as Timestamp?;
                    final statusOption = _callStatusOptions.firstWhere(
                          (option) => option['value'] == (data['callStatus'] ?? 'pending'),
                      orElse: () => _callStatusOptions[1], // default to pending
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 6,
                      shadowColor: statusOption['color'].withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _showArchived
                              ? Colors.blue.withOpacity(0.2)
                              : statusOption['color'].withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BusinessDataDetailPage(
                                documentId: document.id,
                                businessData: data,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                data['businessName'] ?? 'N/A',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (_showArchived)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.archive,
                                                      size: 12,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Archived',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.blue.shade700,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['businessType'] ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          statusOption['color'],
                                          statusOption['color'].withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusOption['color'].withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusOption['icon'],
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          statusOption['label'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Contact Information
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _buildInfoRow('Contact', data['name'], Icons.person, Colors.blue),
                                    const SizedBox(height: 8),
                                    _buildInfoRow('Turnover', data['turnover'], Icons.monetization_on, Colors.green),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildInfoRow('Phone', data['phoneNumber'], Icons.phone, Colors.green),
                                        ),
                                        if (!_showArchived) ...[
                                          Container(
                                            margin: const EdgeInsets.only(left: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: IconButton(
                                              onPressed: () => _makePhoneCall(data['phoneNumber']),
                                              icon: const Icon(Icons.call, color: Colors.white, size: 18),
                                              padding: const EdgeInsets.all(8),
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              tooltip: 'Call ${data['name']}',
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Archive actions or footer
                              Row(
                                children: [
                                  if (_showArchived && archivedAt != null) ...[
                                    Icon(Icons.archive, size: 14, color: Colors.blue.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Archived: ${_formatDate(archivedAt.toDate())}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ] else if (createdAt != null) ...[
                                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(createdAt.toDate()),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  const Spacer(),

                                  if (_showArchived)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Unarchive button
                                        Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.green.shade400, Colors.green.shade600],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            onPressed: () => _unarchiveBusinessData(
                                                document.id,
                                                data['businessName'] ?? 'Business'
                                            ),
                                            icon: const Icon(Icons.unarchive, color: Colors.white, size: 18),
                                            padding: const EdgeInsets.all(8),
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            tooltip: 'Restore Lead',
                                          ),
                                        ),
                                        // Permanent delete button
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.red.shade400, Colors.red.shade600],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            onPressed: () => _permanentlyDeleteBusinessData(
                                                document.id,
                                                data['businessName'] ?? 'Business'
                                            ),
                                            icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
                                            padding: const EdgeInsets.all(8),
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            tooltip: 'Delete Permanently',
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'View Details',
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 12,
                                            color: Colors.blue[700],
                                          ),
                                        ],
                                      ),
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
          ),
        ],
      ),
      floatingActionButton: _showArchived ? null : FloatingActionButton.extended(
        onPressed: _showAddDataDialog,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add, size: 24),
        label: const Text(
          'Add Lead',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, IconData icon, Color iconColor) {
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
                value?.toString() ?? 'N/A',
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}