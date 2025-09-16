import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';

class BusinessDataDetailPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> businessData;

  const BusinessDataDetailPage({
    Key? key,
    required this.documentId,
    required this.businessData,
  }) : super(key: key);

  @override
  State<BusinessDataDetailPage> createState() => _BusinessDataDetailPageState();
}

class _BusinessDataDetailPageState extends State<BusinessDataDetailPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _feedbackController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late String _currentCallStatus;
  final List<Map<String, dynamic>> _callStatusOptions = [
    {
      'value': 'pending',
      'label': 'Pending',
      'color': Colors.blue,
      'icon': Icons.pending_actions,
      'description': 'Call is scheduled or waiting'
    },
    {
      'value': 'interested',
      'label': 'Interested',
      'color': Colors.green,
      'icon': Icons.check_circle,
      'description': 'Client expressed interest'
    },
    {
      'value': 'advance paid',
      'label': 'Advance Paid',
      'color': Colors.green,
      'icon': Icons.check_circle,
      'description': 'Advance payment received'
    },
    {
      'value': 'paid',
      'label': 'Paid',
      'color': Colors.green,
      'icon': Icons.check_circle,
      'description': 'Full payment received'
    },
    {
      'value': 'not_answered',
      'label': 'Not Answered',
      'color': Colors.blueGrey,
      'icon': Icons.call_missed,
      'description': 'No response received'
    },
    {
      'value': 'not_interested',
      'label': 'Not Interested',
      'color': Colors.red,
      'icon': Icons.cancel,
      'description': 'Client not interested'
    },
    {
      'value': 'follow_up',
      'label': 'Follow Up',
      'color': Colors.orange,
      'icon': Icons.follow_the_signs,
      'description': 'Requires follow-up action'
    },
  ];

  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentCallStatus = widget.businessData['callStatus'] ?? 'pending';
    _feedbackController.text = widget.businessData['feedback'] ?? '';

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _updateCallStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('business_data').doc(widget.documentId).update({
        'callStatus': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _currentCallStatus = newStatus;
        _isLoading = false;
      });

      final statusOption = _callStatusOptions.firstWhere(
            (option) => option['value'] == newStatus,
        orElse: () => _callStatusOptions[0],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(statusOption['icon'], color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Status updated to ${statusOption['label']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: statusOption['color'],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            elevation: 8,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating status: $e')),
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

  Future<void> _updateFeedback() async {
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('business_data').doc(widget.documentId).update({
        'feedback': _feedbackController.text.trim().isEmpty ? null : _feedbackController.text.trim(),
        'feedbackUpdatedAt': _feedbackController.text.trim().isEmpty ? null : FieldValue.serverTimestamp(),
      });

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Feedback saved successfully!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating feedback: $e')),
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

  Future<void> _archiveBusinessData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
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
                    colors: [Colors.blue.shade500, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.archive_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Archive Lead',
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
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Are you sure you want to archive '),
                          TextSpan(
                            text: '"${widget.businessData['businessName']}"',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const TextSpan(text: '?\n\n'),
                          TextSpan(
                            text: 'You can unarchive this lead later if needed.',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Archive',
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
      setState(() => _isLoading = true);

      try {
        await _firestore.collection('business_data').doc(widget.documentId).update({
          'isArchived': true,
          'archivedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.archive, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Lead archived successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error archiving lead: $e')),
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openWhatsApp(String? phoneNumber) async {
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
      // Clean and format phone number properly
      String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // If number doesn't start with +, assume it's an Indian number and add +91
      if (!cleanedNumber.startsWith('+')) {
        // Remove leading 0 if present (common in Indian numbers)
        if (cleanedNumber.startsWith('0')) {
          cleanedNumber = cleanedNumber.substring(1);
        }
        // Add country code for India
        cleanedNumber = '+91$cleanedNumber';
      }

      // Create WhatsApp URL with pre-filled message
      final businessName = widget.businessData['businessName'] ?? 'your business';
      final contactName = widget.businessData['name'] ?? 'there';
      final message = 'Hello $contactName, I am reaching out regarding $businessName. I would like to discuss potential opportunities with you.';

      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/${cleanedNumber.replaceAll('+', '')}?text=$encodedMessage';

      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch WhatsApp. Please make sure WhatsApp is installed.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Could not open WhatsApp: $e')),
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
    final createdAt = widget.businessData['createdAt'] as Timestamp?;
    final feedbackUpdatedAt = widget.businessData['feedbackUpdatedAt'] as Timestamp?;
    final statusUpdatedAt = widget.businessData['statusUpdatedAt'] as Timestamp?;
    final archivedAt = widget.businessData['archivedAt'] as Timestamp?;

    final currentStatusOption = _callStatusOptions.firstWhere(
          (option) => option['value'] == _currentCallStatus,
      orElse: () => _callStatusOptions[0],
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: currentStatusOption['color'],
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  widget.businessData['businessName'] ?? 'Business Details',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      currentStatusOption['color'].withOpacity(0.8),
                      currentStatusOption['color'],
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            currentStatusOption['icon'],
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'archive':
                        _archiveBusinessData();
                        break;
                    }
                  },
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, color: Colors.blue),
                          SizedBox(width: 12),
                          Text(
                            'Archive Lead',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child:_buildEnhancedCard(
                      title: 'Business Information',
                      icon: Icons.business_rounded,
                      iconColor: Colors.blue,
                      children: [
                        _buildDetailRow('Business Name', widget.businessData['businessName'], Icons.store),
                        _buildDetailRow('Business Type', widget.businessData['businessType'], Icons.category),
                        _buildDetailRow('Turnover', widget.businessData['turnover'], Icons.monetization_on), // Added turnover field
                        _buildDetailRow('Category', widget.businessData['categoryName'], Icons.folder),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Replace the Contact Information card section (around line 515) with this improved version:

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildEnhancedCard(
                      title: 'Contact Information',
                      icon: Icons.contact_phone_rounded,
                      iconColor: Colors.green,
                      children: [
                        // Contact Name Row
                        _buildDetailRow('Contact Name', widget.businessData['name'], Icons.person),

                        // Phone Number Row
                        _buildDetailRow('Phone Number', widget.businessData['phoneNumber'], Icons.phone),

                        const SizedBox(height: 16),

                        // Action Buttons Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    size: 20,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Quick Actions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Buttons Row - Responsive Layout
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // If screen is narrow, stack buttons vertically
                                  if (constraints.maxWidth < 400) {
                                    return Column(
                                      children: [
                                        // Call Button
                                        SizedBox(
                                          width: double.infinity,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.green.shade400, Colors.green.shade600],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton.icon(
                                              onPressed: () => _makePhoneCall(widget.businessData['phoneNumber']),
                                              icon: const Icon(Icons.call, size: 20),
                                              label: const Text(
                                                'Call Now',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // WhatsApp Button
                                        SizedBox(
                                          width: double.infinity,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.teal.shade400, Colors.teal.shade600],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.teal.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton.icon(
                                              onPressed: () => _openWhatsApp(widget.businessData['phoneNumber']),
                                              icon: const Icon(Icons.message, size: 20),
                                              label: const Text(
                                                'WhatsApp',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.teal.shade400, Colors.teal.shade600],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.teal.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton.icon(
                                              onPressed: () =>_copyToClipboard(widget.businessData['phoneNumber']),
                                              icon: const Icon(Icons.copy, size: 20),
                                              label: const Text(
                                                'Copy to Clipboard',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    // For wider screens, show buttons side by side
                                    return Row(
                                      children: [
                                        // Call Button
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.green.shade400, Colors.green.shade600],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton.icon(
                                              onPressed: () => _makePhoneCall(widget.businessData['phoneNumber']),
                                              icon: const Icon(Icons.call, size: 20),
                                              label: const Text(
                                                'Call Now',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // WhatsApp Button
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.teal.shade400, Colors.teal.shade600],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.teal.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton.icon(
                                              onPressed: () => _openWhatsApp(widget.businessData['phoneNumber']),
                                              icon: const Icon(Icons.message, size: 20),
                                              label: const Text(
                                                'WhatsApp',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildEnhancedCard(
                      title: 'Call Status',
                      icon: Icons.phone_callback_rounded,
                      iconColor: currentStatusOption['color'],
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                currentStatusOption['color'].withOpacity(0.1),
                                currentStatusOption['color'].withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: currentStatusOption['color'].withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: currentStatusOption['color'],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  currentStatusOption['icon'],
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentStatusOption['label'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      currentStatusOption['description'],
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _callStatusOptions.map((status) {
                            final isSelected = status['value'] == _currentCallStatus;
                            return InkWell(
                              onTap: _isLoading || isSelected ? null : () => _updateCallStatus(status['value']),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: isSelected ? LinearGradient(
                                    colors: [status['color'], status['color'].withOpacity(0.8)],
                                  ) : null,
                                  color: isSelected ? null : status['color'].withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: status['color'].withOpacity(isSelected ? 0.8 : 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: status['color'].withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ] : [],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      status['icon'],
                                      size: 18,
                                      color: isSelected ? Colors.white : status['color'],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      status['label'],
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : status['color'],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildEnhancedCard(
                      title: 'Notes & Feedback',
                      icon: Icons.note_alt_rounded,
                      iconColor: Colors.purple,
                      actions: [
                        if (!_isEditing)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.purple.shade400, Colors.purple.shade600],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: _isLoading ? null : () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.white),
                              tooltip: 'Edit Feedback',
                            ),
                          ),
                      ],
                      children: [
                        if (_isEditing)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: TextField(
                                  controller: _feedbackController,
                                  decoration: InputDecoration(
                                    hintText: 'Add your notes and feedback here...',
                                    hintStyle: TextStyle(color: Colors.grey.shade500),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                  maxLines: 4,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: _isLoading ? null : () {
                                        setState(() {
                                          _isEditing = false;
                                          _feedbackController.text = widget.businessData['feedback'] ?? '';
                                        });
                                      },
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
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.purple.shade400, Colors.purple.shade600],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _updateFeedback,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
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
                                          'Save Notes',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.businessData['feedback']?.isEmpty != false) ...[
                                      Icon(
                                        Icons.note_add_rounded,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No notes added yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Click the edit button to add your thoughts, feedback, or important notes about this lead.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ] else ...[
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.format_quote,
                                              size: 20,
                                              color: Colors.purple.shade600,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Your Notes',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        widget.businessData['feedback'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (feedbackUpdatedAt != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.update,
                                      size: 16,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Last updated: ${_formatDateTime(feedbackUpdatedAt.toDate())}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildEnhancedCard(
                      title: 'Timeline',
                      icon: Icons.schedule_rounded,
                      iconColor: Colors.orange,
                      children: [
                        if (createdAt != null)
                          _buildTimelineItem(
                            'Lead Created',
                            _formatDateTime(createdAt.toDate()),
                            Icons.add_circle_outline,
                            Colors.blue,
                            isFirst: true,
                          ),
                        if (statusUpdatedAt != null)
                          _buildTimelineItem(
                            'Status Updated',
                            _formatDateTime(statusUpdatedAt.toDate()),
                            Icons.update,
                            currentStatusOption['color'],
                          ),
                        if (feedbackUpdatedAt != null)
                          _buildTimelineItem(
                            'Notes Updated',
                            _formatDateTime(feedbackUpdatedAt.toDate()),
                            Icons.edit_note,
                            Colors.purple,
                          ),
                        if (archivedAt != null)
                          _buildTimelineItem(
                            'Lead Archived',
                            _formatDateTime(archivedAt.toDate()),
                            Icons.archive,
                            Colors.blue,
                            isLast: true,
                          ),
                        if (statusUpdatedAt == null && feedbackUpdatedAt == null && archivedAt == null)
                          _buildTimelineItem(
                            'Lead Created',
                            createdAt != null ? _formatDateTime(createdAt.toDate()) : 'Unknown',
                            Icons.add_circle_outline,
                            Colors.blue,
                            isFirst: true,
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
    List<Widget>? actions,
  }) {
    return Card(
      elevation: 8,
      shadowColor: iconColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              iconColor.withOpacity(0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [iconColor.withOpacity(0.8), iconColor],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                if (actions != null) ...actions,
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value?.toString() ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
      String title,
      String subtitle,
      IconData icon,
      Color color, {
        bool isFirst = false,
        bool isLast = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: color.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}