// lib/admin/adminrouter.dart

import 'package:flutter/material.dart';
import 'package:sales/admin/AdminCategoriesScreen.dart';
import 'package:sales/admin/AdminLeadsScreen.dart';
import 'package:sales/admin/admin_dashboard.dart';
import 'package:sales/admin/categoryassignment_screen.dart';
import 'package:sales/admin/excel_upload_screen.dart';
import 'package:sales/admin/usermanagement_screen.dart';
import 'package:sales/admin/lead_distribution_screen.dart';

class AdminRouter extends StatelessWidget {
  const AdminRouter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      // The initial screen that loads
      home: const AdminDashboard(),

      // Defines all the possible named routes
      routes: {
        '/admin/dashboard': (context) => const AdminDashboard(),
        '/admin/users': (context) => const UserManagementScreen(),
        '/admin/assignments': (context) => const CategoryAssignmentScreen(),
        '/admin/upload': (context) => const ExcelUploadScreen(),
        '/admin/categories': (context) => const AdminCategoriesScreen(),
        '/admin/leads': (context) => const AdminLeadsScreen(),
        '/admin/distribution': (context) => const LeadDistributionScreen(),
      },

      // REMOVED onGenerateRoute. It is not needed because all
      // routes are defined in the `routes` map above. This was
      // the cause of the navigation error.

    );
  }
}