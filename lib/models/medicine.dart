class Medicine {
  final String id;
  final String profileId;
  final String name;
  final String form; // Pill, Capsule, Liquid, Injection, etc.
  final String frequency; // Daily, Weekly, Custom
  final String doseTime; // "HH:MM:SS" format
  final int? pillsLeft;
  final String foodInstruction; // 'before_food', 'after_food', 'with_food', 'none'
  final DateTime startDate;
  final DateTime? endDate;

  final String? color; // Hex color string
  final String? photoUrl; // Uploaded medicine photo URL

  Medicine({
    required this.id,
    required this.profileId,
    required this.name,
    required this.form,
    required this.frequency,
    required this.doseTime,
    this.pillsLeft,
    required this.foodInstruction,
    required this.startDate,
    this.endDate,
    this.color,
    this.photoUrl,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] ?? '',
      profileId: json['profile_id'] ?? '',
      name: json['name'] ?? '',
      form: json['form'] ?? 'Pill',
      frequency: json['frequency'] ?? 'Daily',
      doseTime: json['dose_time'] ?? '08:00:00',
      pillsLeft: json['pills_left'],
      foodInstruction: json['food_instruction'] ?? 'before_food',
      startDate: DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      color: json['color'],
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'profile_id': profileId,
      'name': name,
      'form': form,
      'frequency': frequency,
      'dose_time': doseTime,
      'pills_left': pillsLeft,
      'food_instruction': foodInstruction,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'color': color,
      'photo_url': photoUrl,
    };
    if (id.isNotEmpty && id.length == 36 && id.contains('-')) {
      map['id'] = id;
    }
    return map;
  }

  Medicine copyWith({
    String? name,
    String? form,
    String? frequency,
    String? doseTime,
    int? pillsLeft,
    String? foodInstruction,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    String? photoUrl,
  }) {
    return Medicine(
      id: id,
      profileId: profileId,
      name: name ?? this.name,
      form: form ?? this.form,
      frequency: frequency ?? this.frequency,
      doseTime: doseTime ?? this.doseTime,
      pillsLeft: pillsLeft ?? this.pillsLeft,
      foodInstruction: foodInstruction ?? this.foodInstruction,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      color: color ?? this.color,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
