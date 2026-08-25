class SOSEvent {
  final String id;
  final String profileId;
  final DateTime triggeredAt;
  final double? latitude;
  final double? longitude;
  final bool resolved;

  SOSEvent({
    required this.id,
    required this.profileId,
    required this.triggeredAt,
    this.latitude,
    this.longitude,
    required this.resolved,
  });

  factory SOSEvent.fromJson(Map<String, dynamic> json) {
    return SOSEvent(
      id: json['id'] ?? '',
      profileId: json['profile_id'] ?? '',
      triggeredAt: DateTime.tryParse(json['triggered_at'] ?? '') ?? DateTime.now(),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      resolved: json['resolved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.isEmpty ? null : id,
      'profile_id': profileId,
      'triggered_at': triggeredAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'resolved': resolved,
    };
  }
}
