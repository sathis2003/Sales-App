import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum CallStatus {
  pending,
  rescheduled,
  interested,
  notInterested,
  followUp,
  notContacted
}

class Lead {
  final String id;
  final String businessName;
  final String businessType;
  final String name;
  final String phoneNumber;
  final DateTime createdAt;
  final String? feedback;
  final DateTime? feedbackUpdatedAt;
  final CallStatus callStatus;
  final String leadType; // Changed from enum to String to support dynamic categories
  final Map<String, dynamic>? additionalData;

  Lead({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.name,
    required this.phoneNumber,
    required this.createdAt,
    this.feedback,
    this.feedbackUpdatedAt,
    required this.callStatus,
    required this.leadType,
    this.additionalData,
  });

  factory Lead.fromFirestore(DocumentSnapshot doc, String categoryName) {
    final data = doc.data() as Map<String, dynamic>;
    return Lead(
      id: doc.id,
      businessName: data['businessName'] ?? '',
      businessType: data['businessType'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      feedback: data['feedback'],
      feedbackUpdatedAt: (data['feedbackUpdatedAt'] as Timestamp?)?.toDate(),
      callStatus: _parseCallStatus(data['callStatus']),
      leadType: categoryName,
      additionalData: data['additionalData'] as Map<String, dynamic>?,
    );
  }

  static CallStatus _parseCallStatus(String? status) {
    switch (status) {
      case 'pending':
        return CallStatus.pending;
      case 'rescheduled':
        return CallStatus.rescheduled;
      case 'interested':
        return CallStatus.interested;
      case 'notInterested':
        return CallStatus.notInterested;
      case 'followUp':
        return CallStatus.followUp;
      case 'notContacted':
        return CallStatus.notContacted;
      default:
        return CallStatus.pending;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessName': businessName,
      'businessType': businessType,
      'name': name,
      'phoneNumber': phoneNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'feedback': feedback,
      'feedbackUpdatedAt': feedbackUpdatedAt != null
          ? Timestamp.fromDate(feedbackUpdatedAt!)
          : null,
      'callStatus': callStatus.toString().split('.').last,
      'leadType': leadType,
      'additionalData': additionalData,
    };
  }

  String getCollectionName() {
    return leadType.toLowerCase();
  }

  String getLeadTypeName() {
    return '${leadType.substring(0, 1).toUpperCase()}${leadType.substring(1)} Lead';
  }

  Color getLeadTypeColor() {
    switch (leadType.toLowerCase()) {
      case 'workshop':
        return const Color(0xFF74B9FF);
      case 'meeting':
        return const Color(0xFFE17055);
      case 'instagram':
        return const Color(0xFFE84393);
      case 'youtube':
        return const Color(0xFFFF6B6B);
      case 'month':
        return const Color(0xFF00CEC9);
      case 'community':
        return const Color(0xFF55A3FF);
      default:
        return const Color(0xFF6C5CE7); // Default purple color
    }
  }

  IconData getLeadTypeIcon() {
    switch (leadType.toLowerCase()) {
      case 'workshop':
        return Icons.school;
      case 'meeting':
        return Icons.people;
      case 'instagram':
        return Icons.camera_alt;
      case 'youtube':
        return Icons.video_library;
      case 'month':
        return Icons.calendar_month;
      case 'community':
        return Icons.groups;
      default:
        return Icons.business; // Default business icon
    }
  }
}