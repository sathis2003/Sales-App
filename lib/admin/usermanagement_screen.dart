import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  // The _assignedCategoriesController is no longer needed for the dialog.

  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createUser(Set<String> assignedCategories) async {
    if (!_formKey.currentState!.validate()) return;
    if (assignedCategories.isEmpty) return; // Guard clause

    setState(() => _isLoading = true);

    try {
      // Create user with Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Add user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'assigned': assignedCategories.join(', '), // Join the set into a string
        'role': 'user',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.email,
      });

      // Clear form
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('User ${_nameController.text} created successfully!'),
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
                Expanded(child: Text('Error creating user: $e')),
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
      // This state update needs to be done within the dialog's state
      // so it's handled by the StatefulBuilder.
    }
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': !currentStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': FirebaseAuth.instance.currentUser?.email,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus
                ? 'User activated successfully!'
                : 'User deactivated successfully!'),
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
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
            content: Text('Error updating user status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Delete User'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete user "$userName"? This action cannot be undone.',
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
        await _firestore.collection('users').doc(userId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "$userName" deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showCreateUserDialog() {
    // Using StatefulBuilder to manage the state within the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final Set<String> _selectedCategories = {};
        bool _showCategoryError = false;

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
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
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
                          Icon(Icons.person_add, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Create New User',
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
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.person,
                                validator: (value) => value?.trim().isEmpty == true
                                    ? 'Name is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _emailController,
                                label: 'Email Address',
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value?.trim().isEmpty == true) {
                                    return 'Email is required';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value!)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildFormField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock,
                                obscureText: true,
                                validator: (value) {
                                  if (value?.trim().isEmpty == true) {
                                    return 'Password is required';
                                  }
                                  if (value!.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // ** NEW CATEGORY SELECTION WIDGET **
                              const Text(
                                'Assign Categories',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 150, // Constrained height
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _showCategoryError ? Colors.red : Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: _firestore.collection('categories').orderBy('name').snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No categories found.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      );
                                    }
                                    final categories = snapshot.data!.docs;
                                    return ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: categories.length,
                                      itemBuilder: (context, index) {
                                        final category = categories[index];
                                        final categoryName = (category.data() as Map<String, dynamic>)['name'] ?? 'Unnamed';
                                        return CheckboxListTile(
                                          title: Text(categoryName),
                                          value: _selectedCategories.contains(categoryName),
                                          onChanged: (bool? value) {
                                            setDialogState(() {
                                              if (value == true) {
                                                _selectedCategories.add(categoryName);
                                              } else {
                                                _selectedCategories.remove(categoryName);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              if (_showCategoryError)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, left: 12),
                                  child: Text(
                                    'Please select at least one category',
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
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
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                        final isFormValid = _formKey.currentState!.validate();
                                        final isCategoryValid = _selectedCategories.isNotEmpty;

                                        setDialogState(() {
                                          _showCategoryError = !isCategoryValid;
                                        });

                                        if (isFormValid && isCategoryValid) {
                                          setDialogState(() => _isLoading = true);
                                          await _createUser(_selectedCategories);
                                          setDialogState(() => _isLoading = false);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
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
                                          : const Text(
                                        'Create User',
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


  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
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
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(icon, color: Colors.blue),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
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
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
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
                hintText: 'Search users by name or email...',
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

          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('role', isEqualTo: 'user')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final users = snapshot.data?.docs ?? [];
                final filteredUsers = users.where((user) {
                  final userData = user.data() as Map<String, dynamic>;
                  final name = userData['name']?.toLowerCase() ?? '';
                  final email = userData['email']?.toLowerCase() ?? '';
                  return name.contains(_searchQuery.toLowerCase()) ||
                      email.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Create your first user to get started'
                              : 'No users match your search criteria',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), // Padding for FAB
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final userData = user.data() as Map<String, dynamic>;
                    final isActive = userData['isActive'] ?? true;
                    final createdAt = userData['createdAt'] as Timestamp?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isActive
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  child: Icon(
                                    Icons.person,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              userData['name'] ?? 'No Name',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
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
                                              borderRadius:
                                              BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isActive
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                            child: Text(
                                              isActive ? 'Active' : 'Inactive',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isActive
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        userData['email'] ?? 'No Email',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'toggle':
                                        _toggleUserStatus(user.id, isActive);
                                        break;
                                      case 'delete':
                                        _deleteUser(
                                          user.id,
                                          userData['name'] ?? 'User',
                                        );
                                        break;
                                      case 'copy_credentials':
                                        Clipboard.setData(ClipboardData(
                                          text: 'Email: ${userData['email']}',
                                        ));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Email copied to clipboard'),
                                          ),
                                        );
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isActive
                                                ? Icons.block
                                                : Icons.check_circle,
                                            color: isActive
                                                ? Colors.orange
                                                : Colors.green,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(isActive
                                              ? 'Deactivate'
                                              : 'Activate'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'copy_credentials',
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Copy Email'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.category,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Assigned Categories:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    userData['assigned']?.isEmpty == true ||
                                        userData['assigned'] == null
                                        ? 'No categories assigned'
                                        : userData['assigned'],
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (createdAt != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Created: ${_formatDate(createdAt.toDate())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.person_add),
        label: const Text(
          'Add User',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}