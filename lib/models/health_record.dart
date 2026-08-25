import 'dart:convert';

class HealthRecord {
  final String id;
  final String profileId;
  final String category; // 'Prescriptions', 'Lab Reports', 'X-Rays & Scans', 'Immunizations', 'Vision', 'Allergies', 'Discharge Summaries'
  final String title;
  final String? doctorName;
  final DateTime recordDate;
  final String? notes;
  final String? fileUrl;
  final String? fileType; // 'pdf', 'image', 'doc'
  final DateTime createdAt;

  HealthRecord({
    required this.id,
    required this.profileId,
    required this.category,
    required this.title,
    this.doctorName,
    required this.recordDate,
    this.notes,
    this.fileUrl,
    this.fileType,
    required this.createdAt,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] ?? '',
      profileId: json['profile_id'] ?? '',
      category: json['category'] ?? 'Prescriptions',
      title: json['title'] ?? '',
      doctorName: json['doctor_name'],
      recordDate: json['record_date'] != null 
          ? DateTime.parse(json['record_date']) 
          : DateTime.now(),
      notes: json['notes'],
      fileUrl: json['file_url'],
      fileType: json['file_type'] ?? 'image',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'category': category,
      'title': title,
      'doctor_name': doctorName,
      'record_date': recordDate.toIso8601String(),
      'notes': notes,
      'file_url': fileUrl,
      'file_type': fileType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  HealthRecord copyWith({
    String? title,
    String? category,
    String? doctorName,
    DateTime? recordDate,
    String? notes,
    String? fileUrl,
    String? fileType,
  }) {
    return HealthRecord(
      id: id,
      profileId: profileId,
      category: category ?? this.category,
      title: title ?? this.title,
      doctorName: doctorName ?? this.doctorName,
      recordDate: recordDate ?? this.recordDate,
      notes: notes ?? this.notes,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      createdAt: createdAt,
    );
  }
}
