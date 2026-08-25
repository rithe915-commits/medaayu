enum UserRole { self, parent }
enum PlanTier { basic, standard, premium }

class Profile {
  final String id;
  final String? ownerId;
  final UserRole role;
  final String fullName;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final String phone;
  final String? sosContactPhone;
  final String? sosContactPhone2;
  final String? email;
  final PlanTier planTier;
  final String language;
  final String sosAction; // 'notify' or 'notify_and_ambulance'
  final String? careTips;
  final DateTime? careTipsUpdatedAt;
  final DateTime? planExpiresAt;
  final String? prefix;
  final String? relationship;
  final String? dob;
  final String? maritalStatus;
  final String? country;
  final String? state;
  final String? city;
  final String? address;
  final String? photoUrl;

  Profile({
    required this.id,
    this.ownerId,
    required this.role,
    required this.fullName,
    this.age,
    this.gender,
    this.bloodGroup,
    required this.phone,
    this.sosContactPhone,
    this.sosContactPhone2,
    this.email,
    required this.planTier,
    required this.language,
    required this.sosAction,
    this.careTips,
    this.careTipsUpdatedAt,
    this.planExpiresAt,
    this.prefix,
    this.relationship,
    this.dob,
    this.maritalStatus,
    this.country,
    this.state,
    this.city,
    this.address,
    this.photoUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      ownerId: json['owner_id'],
      role: json['role'] == 'parent' ? UserRole.parent : UserRole.self,
      fullName: json['full_name'] ?? '',
      age: json['age'],
      gender: json['gender'],
      bloodGroup: json['blood_group'],
      phone: json['phone'] ?? '',
      sosContactPhone: json['sos_contact_phone'],
      sosContactPhone2: json['sos_contact_phone_2'],
      email: json['email'],
      planTier: json['plan_tier'] == 'premium' 
          ? PlanTier.premium 
          : json['plan_tier'] == 'standard' 
              ? PlanTier.standard 
              : PlanTier.basic,
      language: json['language'] ?? 'english',
      sosAction: json['sos_action'] ?? 'notify',
      careTips: json['care_tips'],
      careTipsUpdatedAt: json['care_tips_updated_at'] != null 
          ? DateTime.tryParse(json['care_tips_updated_at']) 
          : null,
      planExpiresAt: json['plan_expires_at'] != null
          ? DateTime.tryParse(json['plan_expires_at'])
          : null,
      prefix: json['prefix'],
      relationship: json['relationship'],
      dob: json['dob'],
      maritalStatus: json['marital_status'],
      country: json['country'],
      state: json['state'],
      city: json['city'],
      address: json['address'],
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'role': role == UserRole.parent ? 'parent' : 'self',
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'blood_group': bloodGroup,
      'phone': phone,
      'sos_contact_phone': sosContactPhone,
      'sos_contact_phone_2': sosContactPhone2,
      'email': email,
      'plan_tier': planTier == PlanTier.premium 
          ? 'premium' 
          : planTier == PlanTier.standard 
              ? 'standard' 
              : 'basic',
      'language': language,
      'sos_action': sosAction,
      'care_tips': careTips,
      'care_tips_updated_at': careTipsUpdatedAt?.toIso8601String(),
      'plan_expires_at': planExpiresAt?.toIso8601String(),
      'prefix': prefix,
      'relationship': relationship,
      'dob': dob,
      'marital_status': maritalStatus,
      'country': country,
      'state': state,
      'city': city,
      'address': address,
      'photo_url': photoUrl,
    };
  }

  Map<String, dynamic> toBaseJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'role': role == UserRole.parent ? 'parent' : 'self',
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'blood_group': bloodGroup,
      'phone': phone,
      'sos_contact_phone': sosContactPhone,
      'sos_contact_phone_2': sosContactPhone2,
      'email': email,
      'plan_tier': planTier == PlanTier.premium 
          ? 'premium' 
          : planTier == PlanTier.standard 
              ? 'standard' 
              : 'basic',
      'language': language,
      'sos_action': sosAction,
      'plan_expires_at': planExpiresAt?.toIso8601String(),
      'photo_url': photoUrl,
    };
  }

  Profile copyWith({
    String? fullName,
    int? age,
    String? gender,
    String? bloodGroup,
    String? phone,
    String? sosContactPhone,
    String? sosContactPhone2,
    String? email,
    PlanTier? planTier,
    String? language,
    String? sosAction,
    String? careTips,
    DateTime? careTipsUpdatedAt,
    DateTime? planExpiresAt,
    String? prefix,
    String? relationship,
    String? dob,
    String? maritalStatus,
    String? country,
    String? state,
    String? city,
    String? address,
    String? photoUrl,
  }) {
    return Profile(
      id: id,
      ownerId: ownerId,
      role: role,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      phone: phone ?? this.phone,
      sosContactPhone: sosContactPhone ?? this.sosContactPhone,
      sosContactPhone2: sosContactPhone2 ?? this.sosContactPhone2,
      email: email ?? this.email,
      planTier: planTier ?? this.planTier,
      language: language ?? this.language,
      sosAction: sosAction ?? this.sosAction,
      careTips: careTips ?? this.careTips,
      careTipsUpdatedAt: careTipsUpdatedAt ?? this.careTipsUpdatedAt,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      prefix: prefix ?? this.prefix,
      relationship: relationship ?? this.relationship,
      dob: dob ?? this.dob,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
