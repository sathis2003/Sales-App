import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryAssignmentScreen extends StatefulWidget {
  const CategoryAssignmentScreen({Key? key}) : super(key: key);

  @override
  State<CategoryAssignmentScreen> createState() => _CategoryAssignmentScreenState();
}

class _CategoryAssignmentScreenState extends State<CategoryAssignmentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedUserId;
  Set<String> _selectedCategories = {};
  bool _isLoading = false;

  Future<void> _assignCategoriesToUser() async {
    if (_selectedUserId == null || _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both user and categories'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users').doc(_selectedUserId).update({
        'assigned': _selectedCategories.join(', '),
        'assignedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedUserId = null;
        _selectedCategories.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Categories assigned successfully!'),
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
            content: Text('Error assigning categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Category Assignment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade100, Colors.purple.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.purple.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Assignment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a user and assign categories they can access. Users will only see leads for their assigned categories.',
                          style: TextStyle(
                            color: Colors.purple.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // User Selection
            const Text(
              'Select User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('role', isEqualTo: 'user')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                final users = snapshot.data?.docs ?? [];

                if (users.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No users found. Create users first.',
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
                    children: users.map((user) {
                      final userData = user.data() as Map<String, dynamic>;
                      final isSelected = _selectedUserId == user.id;
                      final isActive = userData['isActive'] ?? true;

                      return InkWell(
                        onTap: isActive
                            ? () {
                          setState(() {
                            _selectedUserId = user.id;
                            // Load user's current categories
                            final currentAssigned = userData['assigned'] as String?;
                            if (currentAssigned != null && currentAssigned.isNotEmpty) {
                              _selectedCategories = currentAssigned
                                  .split(',')
                                  .map((cat) => cat.trim())
                                  .where((cat) => cat.isNotEmpty)
                                  .toSet();
                            } else {
                              _selectedCategories.clear();
                            }
                          });
                        }
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.purple.withOpacity(0.1)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purple
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
                                  color: isActive
                                      ? (isSelected
                                      ? Colors.purple.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.1))
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: isActive
                                      ? (isSelected ? Colors.purple : Colors.green)
                                      : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            userData['name'] ?? 'No Name',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isActive
                                                  ? Colors.black87
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        if (!isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.red),
                                            ),
                                            child: const Text(
                                              'Inactive',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
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
                                    if (userData['assigned'] != null &&
                                        (userData['assigned'] as String).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Currently assigned: ${userData['assigned']}',
                                          style: TextStyle(
                                            color: Colors.purple.shade600,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.purple,
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

            // Category Selection
            if (_selectedUserId != null) ...[
              const Text(
                'Select Categories to Assign',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('categories')
                      .orderBy('name')
                      .snapshots(),
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
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final categoryData = category.data() as Map<String, dynamic>;
                          final categoryName = categoryData['name'] ?? 'Unnamed';
                          final isSelected = _selectedCategories.contains(categoryName);
                          final colorValue = categoryData['colorValue'] ?? Colors.blue.value;
                          final categoryColor = Color(colorValue);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedCategories.remove(categoryName);
                                  } else {
                                    _selectedCategories.add(categoryName);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? categoryColor.withOpacity(0.15)
                                      : Colors.grey.shade50,
                                  border: Border.all(
                                    color: isSelected
                                        ? categoryColor
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: categoryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.category,
                                        color: categoryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        categoryName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
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
                                      )
                                    else
                                      Icon(
                                        Icons.circle_outlined,
                                        color: Colors.grey.shade400,
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Assign Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || _selectedCategories.isEmpty
                      ? null
                      : _assignCategoriesToUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_turned_in, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Assign ${_selectedCategories.length} Categories',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}