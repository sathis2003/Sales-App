import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

import 'DetailedScreen.dart';

class CategoriesHomePage extends StatefulWidget {
  const CategoriesHomePage({Key? key}) : super(key: key);

  @override
  State<CategoriesHomePage> createState() => _CategoriesHomePageState();
}

class _CategoriesHomePageState extends State<CategoriesHomePage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _categoryController = TextEditingController();
  final Random _random = Random();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Add variables for user data
  List<String> _userAssignedCategories = [];
  bool _isLoadingUserData = true;
  String _currentUserEmail = '';

  // Predefined icons and colors for categories
  final List<IconData> _categoryIcons = [
    Icons.store,
    Icons.mediation,
    Icons.medical_services,
    Icons.school,
    Icons.fitness_center,
    Icons.car_repair,
    Icons.home,
    Icons.computer,
    Icons.shopping_bag,
    Icons.local_grocery_store,
    Icons.build,
    Icons.palette,
    Icons.camera_alt,
    Icons.music_note,
    Icons.spa,
    Icons.account_box,
    Icons.flight,
    Icons.hotel,
    Icons.local_pharmacy,
    Icons.sports_soccer,
  ];

  final List<Color> _categoryColors = [
    Colors.blueAccent,
    Colors.teal,
    Colors.amber,
    Colors.purpleAccent,
    Colors.green,
    Colors.orange,
    Colors.pinkAccent,
    Colors.cyan,
    Colors.deepOrange,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    // Load user's assigned categories
    _loadUserAssignedCategories();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // Helper method to get icon from code point using predefined constants
  IconData _getIconFromCodePoint(int codePoint) {
    // Map common codepoints to predefined icons to ensure they're constants
    final iconMap = <int, IconData>{
      Icons.store.codePoint: Icons.store,
      Icons.mediation.codePoint: Icons.mediation,
      Icons.medical_services.codePoint: Icons.medical_services,
      Icons.school.codePoint: Icons.school,
      Icons.fitness_center.codePoint: Icons.fitness_center,
      Icons.car_repair.codePoint: Icons.car_repair,
      Icons.home.codePoint: Icons.home,
      Icons.computer.codePoint: Icons.computer,
      Icons.shopping_bag.codePoint: Icons.shopping_bag,
      Icons.local_grocery_store.codePoint: Icons.local_grocery_store,
      Icons.build.codePoint: Icons.build,
      Icons.palette.codePoint: Icons.palette,
      Icons.camera_alt.codePoint: Icons.camera_alt,
      Icons.music_note.codePoint: Icons.music_note,
      Icons.spa.codePoint: Icons.spa,
      Icons.account_box.codePoint: Icons.account_box,
      Icons.flight.codePoint: Icons.flight,
      Icons.hotel.codePoint: Icons.hotel,
      Icons.local_pharmacy.codePoint: Icons.local_pharmacy,
      Icons.sports_soccer.codePoint: Icons.sports_soccer,
    };

    // Return the predefined icon if it exists, otherwise return a default
    return iconMap[codePoint] ?? Icons.category;
  }

  // Load user's assigned categories from Firestore
  Future<void> _loadUserAssignedCategories() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoadingUserData = false;
        });
        return;
      }

      _currentUserEmail = currentUser.email ?? '';

      // Query the users collection to get the current user's data
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: _currentUserEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data() as Map<String, dynamic>;
        final String assignedString = userData['assigned'] ?? '';

        if (assignedString.isNotEmpty) {
          // Split the comma-separated string and trim whitespace
          _userAssignedCategories = assignedString
              .split(',')
              .map((category) => category.trim())
              .where((category) => category.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      print('Error loading user assigned categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  Map<String, dynamic> _getRandomIconAndColor() {
    return {
      'iconCodePoint': _categoryIcons[_random.nextInt(_categoryIcons.length)].codePoint,
      'colorValue': _categoryColors[_random.nextInt(_categoryColors.length)].value,
    };
  }

  Future<void> _addCategory(String categoryName) async {
    if (categoryName.trim().isEmpty) return;

    try {
      final iconAndColor = _getRandomIconAndColor();
      await _firestore.collection('categories').add({
        'name': categoryName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'iconCodePoint': iconAndColor['iconCodePoint'],
        'colorValue': iconAndColor['colorValue'],
      });

      _categoryController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$categoryName" created successfully!'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating category: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter category name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onSubmitted: (value) {
                  Navigator.pop(context);
                  _addCategory(value);
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _addCategory(_categoryController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(String docId, String categoryName, Color categoryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "$categoryName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(docId, categoryName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String docId, String categoryName) async {
    try {
      final batch = _firestore.batch();
      final businessDataQuery = await _firestore
          .collection('business_data')
          .where('categoryId', isEqualTo: docId)
          .get();

      for (var doc in businessDataQuery.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('categories').doc(docId));
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$categoryName" deleted successfully!'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting category: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _navigateToCategoryDetail(String categoryId, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailPage(
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to sign out?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Sign Out',
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
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseAuth.instance.signOut();
        // Navigation is handled by AuthWrapper
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // Filter categories based on user's assigned categories
  List<QueryDocumentSnapshot> _filterCategoriesByAssignment(List<QueryDocumentSnapshot> allCategories) {
    if (_userAssignedCategories.isEmpty) {
      return []; // Return empty if user has no assigned categories
    }

    return allCategories.where((category) {
      final categoryData = category.data() as Map<String, dynamic>;
      final categoryName = categoryData['name'] ?? '';
      return _userAssignedCategories.contains(categoryName);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoadingUserData
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
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

          final allCategories = snapshot.data?.docs ?? [];
          final filteredCategories = _filterCategoriesByAssignment(allCategories);

          if (filteredCategories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No assigned categories',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userAssignedCategories.isEmpty
                        ? 'You have no assigned categories yet.'
                        : 'Your assigned categories are not available.',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_userAssignedCategories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Assigned: ${_userAssignedCategories.join(', ')}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final category = filteredCategories[index];
              final categoryData = category.data() as Map<String, dynamic>;
              final categoryName = categoryData['name'] ?? 'Unnamed';
              final docId = category.id;
              final iconCodePoint = categoryData['iconCodePoint'] ?? Icons.category.codePoint;
              final colorValue = categoryData['colorValue'] ?? Colors.teal.value;
              final categoryIcon = _getIconFromCodePoint(iconCodePoint); // Fixed line
              final categoryColor = Color(colorValue);

              return ScaleTransition(
                scale: _fadeAnimation,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => _navigateToCategoryDetail(docId, categoryName),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: categoryColor.withOpacity(0.1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(categoryIcon, size: 48, color: categoryColor),
                          const SizedBox(height: 12),
                          Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _showDeleteDialog(docId, categoryName, categoryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}