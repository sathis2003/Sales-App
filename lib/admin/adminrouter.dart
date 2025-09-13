import 'package:flutter/material.dart';
import 'package:sales/admin/AdminCategoriesScreen.dart';
import 'package:sales/admin/AdminLeadsScreen.dart';
import 'package:sales/admin/admin_dashboard.dart';
import 'package:sales/admin/categoryassignment_screen.dart';
import 'package:sales/admin/excel_upload_screen.dart';
import 'package:sales/admin/usermanagement_screen.dart';


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
      home: const AdminDashboard(),
      routes: {
        '/admin/dashboard': (context) => const AdminDashboard(),
        '/admin/users': (context) => const UserManagementScreen(),
        '/admin/assignments': (context) => const CategoryAssignmentScreen(),
        '/admin/upload': (context) => const ExcelUploadScreen(),
        '/admin/categories': (context) => const AdminCategoriesScreen(),
        '/admin/leads': (context) => const AdminLeadsScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes if needed
        return MaterialPageRoute(
          builder: (context) => const AdminDashboard(),
        );
      },
    );
  }
}




