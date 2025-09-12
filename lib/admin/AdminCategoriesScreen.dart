import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({Key? key}) : super(key: key);

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  Color _selectedColor = Colors.blue;
  bool _isLoading = false;
  String _searchQuery = '';

  // Predefined colors for categories
  final List<Color> _categoryColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.brown,
    Colors.cyan,
    Colors.deepOrange,
    Colors.deepPurple,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Check if category name already exists
      final existingCategory = await _firestore
          .collection('categories')
          .where('name', isEqualTo: _nameController.text.trim())
          .get();

      if (existingCategory.docs.isNotEmpty) {
        throw 'A category with this name already exists';
      }

      await _firestore.collection('categories').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'colorValue': _selectedColor.value,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.email,
        'isActive': true,
      });

      // Clear form
      _nameController.clear();
      _descriptionController.clear();
      _selectedColor = Colors.blue;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Category created successfully!'),
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
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error creating category: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editCategory(String categoryId, Map<String, dynamic> currentData) async {
    _nameController.text = currentData['name'] ?? '';
    _descriptionController.text = currentData['description'] ?? '';
    _selectedColor = Color(currentData['colorValue'] ?? Colors.blue.value);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCategoryDialog(
        title: 'Edit Category',
        onSave: () => _updateCategory(categoryId),
      ),
    );
  }

  Future<void> _updateCategory(String categoryId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('categories').doc(categoryId).update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'colorValue': _selectedColor.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.email,
      });

      // Clear form
      _nameController.clear();
      _descriptionController.clear();
      _selectedColor = Colors.blue;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Category updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCategoryStatus(String categoryId, bool currentStatus) async {
    try {
      await _firestore.collection('categories').doc(categoryId).update({
        'isActive': !currentStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': FirebaseAuth.instance.currentUser?.email,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus
                ? 'Category activated successfully!'
                : 'Category deactivated successfully!'),
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating category status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(String categoryId, String categoryName) async {
    // First check if category has any leads
    final leadsQuery = await _firestore
        .collection('business_data')
        .where('categoryName', isEqualTo: categoryName)
        .get();

    if (leadsQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete category "$categoryName" - it has ${leadsQuery.docs.length} leads assigned to it'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Delete Category'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete category "$categoryName"? This action cannot be undone.',
        ),
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
        await _firestore.collection('categories').doc(categoryId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category "$categoryName" deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting category: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showCreateCategoryDialog() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedColor = Colors.blue;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCategoryDialog(
        title: 'Create New Category',
        onSave: _createCategory,
      ),
    );
  }

  Widget _buildCategoryDialog({
    required String title,
    required VoidCallback onSave,
  }) {
    return StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
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
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
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
                      const Icon(Icons.category, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormField(
                          controller: _nameController,
                          label: 'Category Name',
                          icon: Icons.category,
                          validator: (value) {
                            if (value?.trim().isEmpty == true) {
                              return 'Category name is required';
                            }
                            if (value!.length > 50) {
                              return 'Category name too long (max 50 characters)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildFormField(
                          controller: _descriptionController,
                          label: 'Description (optional)',
                          icon: Icons.description,
                          maxLines: 3,
                          hintText: 'Brief description of this category...',
                        ),
                        const SizedBox(height: 24),

                        // Color Selection
                        const Text(
                          'Choose Category Color',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _categoryColors.map((color) => GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                _selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedColor == color
                                      ? Colors.black
                                      : Colors.grey.shade300,
                                  width: _selectedColor == color ? 3 : 1,
                                ),
                              ),
                              child: _selectedColor == color
                                  ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                                  : null,
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Preview
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _selectedColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.category,
                                  color: _selectedColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nameController.text.isEmpty
                                        ? 'Category Preview'
                                        : _nameController.text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedColor,
                                    ),
                                  ),
                                  const Text(
                                    'Preview of how this category will look',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                                onPressed: _isLoading ? null : onSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : Text(
                                  title.contains('Create') ? 'Create Category' : 'Update Category',
                                  style: const TextStyle(
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
    String? hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
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
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(icon, color: Colors.orange),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Manage Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search categories...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          // Categories List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('categories')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final categories = snapshot.data?.docs ?? [];
                final filteredCategories = categories.where((category) {
                  final categoryData = category.data() as Map<String, dynamic>;
                  final name = categoryData['name']?.toLowerCase() ?? '';
                  final description = categoryData['description']?.toLowerCase() ?? '';
                  return name.contains(_searchQuery.toLowerCase()) ||
                      description.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredCategories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No categories found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first category to get started',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredCategories.length,
                  itemBuilder: (context, index) {
                    final category = filteredCategories[index];
                    final categoryData = category.data() as Map<String, dynamic>;
                    final isActive = categoryData['isActive'] ?? true;
                    final categoryColor = Color(categoryData['colorValue'] ?? Colors.blue.value);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              categoryColor.withOpacity(0.05),
                              categoryColor.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              categoryData['name'] ?? 'Unnamed',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: categoryColor,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Colors.green.withOpacity(0.1)
                                                    : Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isActive ? Colors.green : Colors.red,
                                                ),
                                              ),
                                              child: Text(
                                                isActive ? 'Active' : 'Inactive',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isActive ? Colors.green : Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (categoryData['description']?.isNotEmpty == true)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              categoryData['description'],
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'edit':
                                          _editCategory(category.id, categoryData);
                                          break;
                                        case 'toggle':
                                          _toggleCategoryStatus(category.id, isActive);
                                          break;
                                        case 'delete':
                                          _deleteCategory(
                                            category.id,
                                            categoryData['name'] ?? 'Category',
                                          );
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isActive ? Icons.block : Icons.check_circle,
                                              color: isActive ? Colors.orange : Colors.green,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(isActive ? 'Deactivate' : 'Activate'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Category Stats
                              FutureBuilder<QuerySnapshot>(
                                future: _firestore
                                    .collection('business_data')
                                    .where('categoryName', isEqualTo: categoryData['name'])
                                    .get(),
                                builder: (context, leadsSnapshot) {
                                  final leadCount = leadsSnapshot.data?.docs.length ?? 0;

                                  return FutureBuilder<QuerySnapshot>(
                                    future: _firestore
                                        .collection('users')
                                        .where('assigned', arrayContains: categoryData['name'])
                                        .get(),
                                    builder: (context, usersSnapshot) {
                                      final assignedUsers = usersSnapshot.data?.docs.length ?? 0;

                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    leadCount.toString(),
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: categoryColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Total Leads',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 40,
                                              color: Colors.grey.shade300,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    assignedUsers.toString(),
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: categoryColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Assigned Users',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCategoryDialog,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}