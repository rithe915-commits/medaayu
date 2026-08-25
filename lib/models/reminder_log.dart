class ReminderLog {
  final String id;
  final String medicineId;
  final String channel; // 'local_alarm', 'whatsapp', 'tts_call'
  final DateTime sentAt;
  final String status; // 'success', 'failed'

  ReminderLog({
    required this.id,
    required this.medicineId,
    required this.channel,
    required this.sentAt,
    required this.status,
  });

  factory ReminderLog.fromJson(Map<String, dynamic> json) {
    return ReminderLog(
      id: json['id'] ?? '',
      medicineId: json['medicine_id'] ?? '',
      channel: json['channel'] ?? 'local_alarm',
      sentAt: DateTime.tryParse(json['sent_at'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'success',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'channel': channel,
      'sent_at': sentAt.toIso8601String(),
      'status': status,
    };
  }
}
