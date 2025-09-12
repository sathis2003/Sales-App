import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sales/HomeScreen.dart';
import 'package:sales/admin/adminauth_wraper_screen.dart';
import 'package:sales/admin/adminrouter.dart';
import 'package:sales/LoginScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',

        // Enhanced theme configuration
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),

        // App Bar Theme
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Card Theme
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),

        // Button Themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),

        // Floating Action Button Theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 6,
        ),
      ),

      // Use the AdminAuthWrapper as the main authentication handler
      home: AdminAuthWrapper(
        // Admin gets AdminRouter (all admin features)
        adminChild: const AdminRouter(),

        // Regular users get UserDashboard (or your existing user app)
        userChild: const CategoriesHomePage(), // Replace with your actual user dashboard

        // Not authenticated users get the common login screen
        loginChild: const CommonLoginScreen(),
      ),

      // Define routes for navigation
      routes: {
        '/login': (context) => const CommonLoginScreen(),
        '/admin': (context) => const AdminRouter(),
        '/user': (context) => const CategoriesHomePage(),
      },

      // Handle unknown routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const CommonLoginScreen(),
        );
      },
    );
  }
}