import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String role; // "student", "driver", "admin"
  final String collegeId;
  final String? name;
  final String? phone;
  final String? assignedBusId;
  final List<String> favoriteBusIds;
  final String? activeBusId;
  final String? activeBusNumber;
  final DateTime? lastBusUpdate;
  final String? photoUrl;

  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.collegeId,
    this.name,
    this.phone,
    this.assignedBusId,
    this.favoriteBusIds = const [],
    this.activeBusId,
    this.activeBusNumber,
    this.lastBusUpdate,
    this.photoUrl,
    this.homeAddress,
    this.parentName,
    this.parentContact,
    this.emergencyContactName1,
    this.emergencyContactPhone1,
    this.emergencyContactName2,
    this.emergencyContactPhone2,
  });

  final String? homeAddress;
  final String? parentName;
  final String? parentContact;
  final String? emergencyContactName1;
  final String? emergencyContactPhone1;
  final String? emergencyContactName2;
  final String? emergencyContactPhone2;

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      collegeId: data['collegeId'] ?? '',
      name: data['name'],
      phone: (data['phone'] ?? data['phoneNumber'])?.toString(),
      assignedBusId: (data['busId'] ?? data['assignedBusId'])?.toString(),
      favoriteBusIds: List<String>.from(data['favoriteBusIds'] ?? []),
      activeBusId: data['activeBusId']?.toString(),
      activeBusNumber: data['activeBusNumber']?.toString(),
      lastBusUpdate: data['lastBusUpdate'] is Timestamp 
        ? (data['lastBusUpdate'] as Timestamp).toDate() 
        : (data['lastBusUpdate'] != null ? DateTime.tryParse(data['lastBusUpdate'].toString()) : null),
      photoUrl: data['photoUrl']?.toString(),
      homeAddress: data['homeAddress']?.toString(),
      parentName: data['parentName']?.toString(),
      parentContact: (data['parentContact'] ?? data['parentPhone'])?.toString(),
      emergencyContactName1: data['emergencyContactName1']?.toString(),
      emergencyContactPhone1: data['emergencyContactPhone1']?.toString(),
      emergencyContactName2: data['emergencyContactName2']?.toString(),
      emergencyContactPhone2: data['emergencyContactPhone2']?.toString(),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      collegeId: json['collegeId'] ?? '',
      name: json['name'],
      phone: (json['phone'] ?? json['phoneNumber'])?.toString(),
      assignedBusId: (json['assignedBusId'] ?? json['busId'])?.toString(),
      favoriteBusIds: List<String>.from(json['favoriteBusIds'] ?? []),
      activeBusId: json['activeBusId']?.toString(),
      activeBusNumber: json['activeBusNumber']?.toString(),
      lastBusUpdate: json['lastBusUpdate'] != null ? DateTime.tryParse(json['lastBusUpdate'].toString()) : null,
      photoUrl: json['photoUrl']?.toString(),
      homeAddress: json['homeAddress']?.toString(),
      parentName: json['parentName']?.toString(),
      parentContact: (json['parentContact'] ?? json['parentPhone'])?.toString(),
      emergencyContactName1: json['emergencyContactName1']?.toString(),
      emergencyContactPhone1: json['emergencyContactPhone1']?.toString(),
      emergencyContactName2: json['emergencyContactName2']?.toString(),
      emergencyContactPhone2: json['emergencyContactPhone2']?.toString(),
    );
  }
}
