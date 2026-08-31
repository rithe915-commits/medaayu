import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';
import '../models/profile.dart';
import '../models/sos_event.dart';
import '../models/reminder_log.dart';
import '../models/health_record.dart';
import 'alarm_service.dart';

class DbService extends ChangeNotifier {
  final _client = Supabase.instance.client;
  List<Medicine> _medicines = [];
  List<Profile> _linkedParents = [];
  List<ReminderLog> _logs = [];
  List<Map<String, dynamic>> _intakeLogs = [];
  List<HealthRecord> _records = [];
  bool _isLoading = false;

  List<Medicine> get medicines => _medicines;
  List<Profile> get linkedParents => _linkedParents;
  List<ReminderLog> get logs => _logs;
  List<Map<String, dynamic>> get intakeLogs => _intakeLogs;
  List<HealthRecord> get records => _records;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Private helper to invoke Edge Functions directly without Authorization header (bypasses ES256 gateway issues)
  Future<dynamic> _invokeEdgeFunction(String functionName, Map<String, dynamic> body) async {
    final apiKey = _client.rest.headers['apikey'] ?? 'sb_publishable_IBq3dRoeAggLMh7BWGqYSg_KAuL_BoD';
    try {
      final client = HttpClient();
      HttpClientRequest request;
      try {
        request = await client.postUrl(
          Uri.parse('https://medaayufinal.vercel.app/api/$functionName'),
        );
      } catch (_) {
        request = await client.postUrl(
          Uri.parse('https://ysuwnlvmipgfgesdpqdn.supabase.co/functions/v1/$functionName'),
        );
      }
      final sessionToken = _client.auth.currentSession?.accessToken ?? apiKey;
      request.headers.set('content-type', 'application/json');
      request.headers.set('apikey', apiKey);
      request.headers.set('Authorization', 'Bearer $sessionToken');
      
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      debugPrint("$functionName direct HTTP response status: ${response.statusCode}");
      final decoded = jsonDecode(responseBody);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      } else {
        throw FunctionException(
          status: response.statusCode,
          details: decoded,
        );
      }
    } catch (e) {
      debugPrint("Error calling $functionName: $e");
      rethrow;
    }
  }

  // Load medicines for a specific profile (local cache first, then Supabase sync)
  Future<void> loadMedicines(String profileId, [Profile? profile]) async {
    // 1. Load from local cache for instant display
    await _loadLocalMedicines(profileId);
    notifyListeners();

    // 2. Sync with Supabase
    _setLoading(true);
    try {
      final res = await _client
          .from('medicines')
          .select()
          .eq('profile_id', profileId)
          .order('dose_time', ascending: true);

      final fromDb = (res as List).map((m) => Medicine.fromJson(m)).toList();
      if (fromDb.isNotEmpty) {
        _medicines = fromDb;
        await _saveLocalMedicines(profileId);
      } else if (_medicines.isNotEmpty) {
        // Automatically sync local medicines to Supabase database!
        for (int i = 0; i < _medicines.length; i++) {
          final med = _medicines[i];
          try {
            final json = med.toJson();
            if (med.id.isNotEmpty && !med.id.startsWith('local_')) {
              json['id'] = med.id;
            } else {
              json.remove('id');
            }
            final insertRes = await _client.from('medicines').insert(json).select().single();
            _medicines[i] = Medicine.fromJson(insertRes);
            debugPrint("Synced local medicine ${med.name} to Supabase with real UUID: ${_medicines[i].id}");
          } catch (syncErr) {
            debugPrint("Could not sync medicine ${med.name} to Supabase: $syncErr");
          }
        }
        await _saveLocalMedicines(profileId);
      }
      _setLoading(false);
    } catch (e) {
      debugPrint("Error loading medicines from Supabase (using local cache): $e");
      _setLoading(false);
    }

    // 3. Reschedule active alarms if profile is provided
    if (profile != null) {
      for (final med in _medicines) {
        await AlarmService.scheduleAlarm(med, profile);
      }
    }
  }

  Future<void> _saveLocalMedicines(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _medicines.map((m) {
        final j = m.toJson();
        j['id'] = m.id;
        return j;
      }).toList();
      await prefs.setString('local_medicines_$profileId', jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving local medicines: $e");
    }
  }

  Future<void> _loadLocalMedicines(String profileId) async {
    _medicines = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString('local_medicines_$profileId');
      if (rawJson != null && rawJson.isNotEmpty) {
        final List list = jsonDecode(rawJson);
        _medicines = list.map((m) => Medicine.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Error reading local medicines: $e");
    }
  }

  // Load linked parent profiles for the caregiver
  Future<void> loadLinkedParents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('owner_id', userId);

      _linkedParents = (res as List).map((p) => Profile.fromJson(p)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading linked parents: $e");
    }
  }

  // Create a linked parent or self profile via server-side Edge Function
  // (avoids hijacking caregiver session, handles auth user creation properly)
  Future<Profile?> createParentProfile({
    required String fullName,
    int? age,
    String? gender,
    String? bloodGroup,
    required String phone,
    String? sosContactPhone,
    String? sosContactPhone2,
    String? email,
    required PlanTier planTier,
    required String language,
    required String sosAction,
    UserRole role = UserRole.parent,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    _setLoading(true);
    try {
      try {
        final data = await _invokeEdgeFunction(
          'manage-parent',
          {
            'action': 'create',
            'fullName': fullName,
            'phone': phone,
            'age': age,
            'gender': gender,
            'bloodGroup': bloodGroup,
            'planTier': planTier == PlanTier.premium
                ? 'premium'
                : planTier == PlanTier.standard
                    ? 'standard'
                    : 'basic',
            'language': language,
            'sosAction': sosAction,
            'sosContact': sosContactPhone,
            'sosContact2': sosContactPhone2,
            'email': email,
            'role': role == UserRole.parent ? 'parent' : 'self',
          },
        );

        if (data != null && data['success'] == true) {
          final profileId = data['profileId'] as String;
          await loadLinkedParents();
          _setLoading(false);

          final res = await _client.from('profiles').select().eq('id', profileId).maybeSingle();
          if (res != null) return Profile.fromJson(res);
        }
      } catch (fnErr) {
        debugPrint("manage-parent function notice: $fnErr. Using direct database profile creation.");
      }

      // Direct client database creation fallback
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final tenDigit = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
      final profileId = '00000000-0000-4000-a000-${tenDigit.padLeft(12, '0')}';

      final profileData = {
        'id': profileId,
        'owner_id': userId,
        'role': role == UserRole.parent ? 'parent' : 'self',
        'full_name': fullName,
        'phone': tenDigit,
        'age': age,
        'gender': gender,
        'blood_group': bloodGroup,
        'email': email,
        'sos_contact_phone': sosContactPhone,
        'sos_contact_phone_2': sosContactPhone2,
        'plan_tier': planTier == PlanTier.premium ? 'premium' : planTier == PlanTier.standard ? 'standard' : 'basic',
        'language': language,
        'sos_action': sosAction,
      };

      try {
        await _client.from('profiles').upsert(profileData);
      } catch (e) {
        debugPrint("Direct profiles insert notice: $e");
      }

      final newProfile = Profile.fromJson(profileData);
      _linkedParents.removeWhere((p) => p.id == newProfile.id);
      _linkedParents.insert(0, newProfile);

      // Cache locally so switchProfile can use fallback if DB record is not synced yet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_profile_${newProfile.id}', jsonEncode(profileData));

      notifyListeners();
      _setLoading(false);
      return newProfile;
    } catch (e) {
      debugPrint("Error creating parent profile: $e");
      _setLoading(false);
      rethrow;
    }
  }

  /// Update only the phone number of an existing parent profile
  Future<bool> updateParentPhone(String profileId, String newPhone) async {
    try {
      final response = await _client.functions.invoke(
        'manage-parent',
        body: {
          'action': 'update_phone',
          'profileId': profileId,
          'newPhone': newPhone,
        },
      );

      final data = response.data;
      if (data?['success'] == true) {
        await loadLinkedParents();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating parent phone: $e");
      return false;
    }
  }

  /// Generate a deterministic UUID v5-like string from phone number
  String _deterministicUuid(String phone) {
    final hash = phone.hashCode.abs();
    final h = hash.toRadixString(16).padLeft(8, '0');
    return '00000000-0000-4000-a000-${h.padLeft(12, '0')}';
  }


  // Add Medicine
  Future<bool> addMedicine(Medicine medicine, Profile profile) async {
    try {
      final json = medicine.toJson();
      Medicine addedMed;

      // Ensure profile exists in Supabase first so foreign key constraint is satisfied
      try {
        final profJson = profile.toJson();
        profJson['id'] = profile.id;
        await _client.from('profiles').upsert(profJson);
      } catch (profErr) {
        try {
          final baseJson = profile.toBaseJson();
          baseJson['id'] = profile.id;
          await _client.from('profiles').upsert(baseJson);
        } catch (_) {}
      }
      
      // Try to insert into Supabase first to get the real UUID
      try {
        final res = await _client.from('medicines').insert(json).select().single();
        final newMed = Medicine.fromJson(res);
        _medicines.add(newMed);
        addedMed = newMed;
      } catch (insertErr) {
        debugPrint("Supabase medicine insert notice: $insertErr. Saving locally.");
        // Fallback: create with deterministic local ID
        final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
        final localJson = Map<String, dynamic>.from(json)
          ..['id'] = localId;
        final newMed = Medicine.fromJson(localJson);
        _medicines.add(newMed);
        addedMed = newMed;
      }

      _medicines.sort((a, b) => a.doseTime.compareTo(b.doseTime));
      await _saveLocalMedicines(profile.id);
      notifyListeners();

      // Clear any prior intake cache for today so newly added/reset medicine triggers call
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await prefs.remove('intake_taken_${addedMed.id}_$todayStr');

      // Schedule Local Device Alarm / Notification for all plan tiers
      await AlarmService.scheduleAlarm(addedMed, profile);

      // Generate AI care tips asynchronously
      _triggerCareTipsRegen(profile.id);

      return true;
    } catch (e) {
      debugPrint("Error adding medicine: $e");
      return false;
    }
  }

  // Update Medicine
  Future<bool> updateMedicine(Medicine medicine, Profile profile) async {
    try {
      final json = medicine.toJson();
      // Only attempt DB update if the medicine has a real UUID (not a local_ fallback ID)
      if (!medicine.id.startsWith('local_')) {
        try {
          await _client.from('medicines').update(json).eq('id', medicine.id);
        } catch (e) {
          debugPrint("Supabase medicine update notice: $e");
        }
      } else {
        debugPrint("Skipping DB update for local medicine: ${medicine.id}");
      }

      final index = _medicines.indexWhere((m) => m.id == medicine.id);
      if (index != -1) {
        _medicines[index] = medicine;
        _medicines.sort((a, b) => a.doseTime.compareTo(b.doseTime));
      }
      await _saveLocalMedicines(profile.id);
      notifyListeners();

      // Clear any prior intake cache for today so updated medicine triggers call
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await prefs.remove('intake_taken_${medicine.id}_$todayStr');

      // Reschedule Local Device Alarm / Notification for all plan tiers
      await AlarmService.cancelAlarm(medicine);
      await AlarmService.scheduleAlarm(medicine, profile);

      // Generate AI care tips asynchronously
      _triggerCareTipsRegen(profile.id);

      return true;
    } catch (e) {
      debugPrint("Error updating medicine: $e");
      return false;
    }
  }

  // Delete Medicine
  Future<bool> deleteMedicine(Medicine medicine, Profile profile) async {
    try {
      // Only attempt DB delete if the medicine has a real UUID (not a local_ fallback ID)
      if (!medicine.id.startsWith('local_')) {
        try {
          await _client.from('medicines').delete().eq('id', medicine.id);
        } catch (e) {
          debugPrint("Supabase medicine delete notice: $e");
        }
      } else {
        debugPrint("Skipping DB delete for local medicine: ${medicine.id}");
      }
      _medicines.removeWhere((m) => m.id == medicine.id);
      await _saveLocalMedicines(profile.id);
      notifyListeners();

      // Handle Local Alarms cancellation
      await AlarmService.cancelAlarm(medicine);

      // Generate AI care tips asynchronously
      _triggerCareTipsRegen(profile.id);

      return true;
    } catch (e) {
      debugPrint("Error deleting medicine: $e");
      return false;
    }
  }

  // Trigger care tips regeneration Edge Function in background (direct HTTP to bypass ES256 JWT issue)
  void _triggerCareTipsRegen(String profileId) {
    if (profileId.startsWith('local_')) {
      debugPrint("Skipping care tips regen for local profile: $profileId");
      return;
    }
    triggerCareTipsRegen(profileId);
  }

  // Log SOS Event (triggers GPS, DB insert, notify-sos SMS, etc.)
  Future<bool> triggerSOSEvent({
    required String profileId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // 1. Insert into database
      final res = await _client.from('sos_events').insert({
        'profile_id': profileId,
        'latitude': latitude,
        'longitude': longitude,
        'resolved': false,
      }).select().single();

      final eventId = res['id'] as String;

      // 2. Trigger SMS backend Edge Function
      await _client.functions.invoke('notify-sos', body: {
        'profileId': profileId,
        'eventId': eventId,
        'latitude': latitude,
        'longitude': longitude,
      });

      return true;
    } catch (e) {
      debugPrint("Error logging SOS Event: $e");
      return false;
    }
  }

  // Load reminder logs
  Future<void> loadReminderLogs(String profileId) async {
    try {
      final res = await _client
          .from('reminder_logs')
          .select('''
            *,
            medicines!inner(*)
          ''')
          .eq('medicines.profile_id', profileId)
          .order('sent_at', ascending: false)
          .limit(50);

      _logs = (res as List).map((l) => ReminderLog.fromJson(l)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading reminder logs: $e");
    }
  }

  // Load intake logs for the last 365 days to show in Adherence / taken counts
  Future<void> loadIntakeLogs(String profileId) async {
    try {
      final res = await _client
          .from('intake_logs')
          .select('*, medicines!inner(*)')
          .eq('medicines.profile_id', profileId)
          .gte('taken_at', DateTime.now().subtract(const Duration(days: 365)).toIso8601String())
          .order('taken_at', ascending: false);
      _intakeLogs = List<Map<String, dynamic>>.from(res as List);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading intake logs: $e");
    }
  }

  // Mark medicine as taken (inserts intake log and decrements pills remaining count)
  Future<bool> markMedicineTaken(String medicineId, String profileId, {DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final now = DateTime.now();
      final takenAt = DateTime(targetDate.year, targetDate.month, targetDate.day, now.hour, now.minute, now.second);

      final isLocal = medicineId.startsWith('local_');

      if (!isLocal) {
        // 1. Insert into database (using explicit UTC ISO timestamp)
        try {
          await _client.from('intake_logs').insert({
            'medicine_id': medicineId,
            'taken_at': takenAt.toUtc().toIso8601String(),
          });
        } catch (dbErr) {
          debugPrint("Database intake log insert notice: $dbErr");
        }
      }

      // Add to local intake logs cache
      _intakeLogs.add({
        'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
        'medicine_id': medicineId,
        'taken_at': takenAt.toUtc().toIso8601String(),
      });
      
      // Reload logs from DB if not local
      if (!isLocal) {
        await loadIntakeLogs(profileId);
      }
      
      // Decrement pills count
      final index = _medicines.indexWhere((m) => m.id == medicineId);
      if (index != -1) {
        final med = _medicines[index];
        if (med.pillsLeft != null && med.pillsLeft! > 0) {
          final updatedMed = med.copyWith(pillsLeft: med.pillsLeft! - 1);
          if (!isLocal) {
            try {
              await _client
                  .from('medicines')
                  .update({'pills_left': updatedMed.pillsLeft})
                  .eq('id', medicineId);
            } catch (_) {}
          }
          _medicines[index] = updatedMed;
        }
      }
      
      // Persist intake flag in SharedPreferences so background alarm isolate can read it immediately
      final dateStr = targetDate.toIso8601String().split('T')[0];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('intake_taken_${medicineId}_$dateStr', true);

      await _saveLocalMedicines(profileId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error marking medicine taken: $e");
      return false;
    }
  }

  // Toggle medicine taken status for any selected date
  Future<bool> toggleMedicineIntake(String medicineId, String profileId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final isLocal = medicineId.startsWith('local_');

      final dateStr = date.toIso8601String().split('T')[0];
      final prefs = await SharedPreferences.getInstance();

      if (isLocal) {
        // Handle local medicine intake toggle using memory array
        final existingIndex = _intakeLogs.indexWhere((log) {
          if (log['medicine_id'] != medicineId) return false;
          final takenAt = DateTime.tryParse(log['taken_at'] ?? '');
          if (takenAt == null) return false;
          return takenAt.isAfter(startOfDay) && takenAt.isBefore(endOfDay);
        });

        if (existingIndex != -1) {
          // Untake
          _intakeLogs.removeAt(existingIndex);
          await prefs.remove('intake_taken_${medicineId}_$dateStr');
          final index = _medicines.indexWhere((m) => m.id == medicineId);
          if (index != -1) {
            final med = _medicines[index];
            if (med.pillsLeft != null) {
              _medicines[index] = med.copyWith(pillsLeft: med.pillsLeft! + 1);
            }
          }
        } else {
          // Take
          final now = DateTime.now();
          final takenAt = DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second);
          _intakeLogs.add({
            'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
            'medicine_id': medicineId,
            'taken_at': takenAt.toUtc().toIso8601String(),
          });
          await prefs.setBool('intake_taken_${medicineId}_$dateStr', true);
          final index = _medicines.indexWhere((m) => m.id == medicineId);
          if (index != -1) {
            final med = _medicines[index];
            if (med.pillsLeft != null && med.pillsLeft! > 0) {
              _medicines[index] = med.copyWith(pillsLeft: med.pillsLeft! - 1);
            }
          }
        }
        await _saveLocalMedicines(profileId);
        notifyListeners();
        return true;
      }

      // DB-backed medicine toggle (using explicit UTC bounds)
      final startIso = startOfDay.toUtc().toIso8601String();
      final endIso = endOfDay.toUtc().toIso8601String();

      final existingList = await _client
          .from('intake_logs')
          .select('id')
          .eq('medicine_id', medicineId)
          .gte('taken_at', startIso)
          .lte('taken_at', endIso);

      if (existingList != null && (existingList as List).isNotEmpty) {
        // Delete all intake logs for this medicine on this day
        for (final item in existingList) {
          await _client.from('intake_logs').delete().eq('id', item['id']);
        }
        await prefs.remove('intake_taken_${medicineId}_$dateStr');
        
        // Increment pills count (since we unmarked it)
        final index = _medicines.indexWhere((m) => m.id == medicineId);
        if (index != -1) {
          final med = _medicines[index];
          if (med.pillsLeft != null) {
            final updatedMed = med.copyWith(pillsLeft: med.pillsLeft! + 1);
            try {
              await _client
                  .from('medicines')
                  .update({'pills_left': updatedMed.pillsLeft})
                  .eq('id', medicineId);
            } catch (_) {}
            _medicines[index] = updatedMed;
          }
        }
      } else {
        // Insert intake log (in UTC)
        final now = DateTime.now();
        final takenAt = DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second);
        await _client.from('intake_logs').insert({
          'medicine_id': medicineId,
          'taken_at': takenAt.toUtc().toIso8601String(),
        });
        await prefs.setBool('intake_taken_${medicineId}_$dateStr', true);

        // Decrement pills count
        final index = _medicines.indexWhere((m) => m.id == medicineId);
        if (index != -1) {
          final med = _medicines[index];
          if (med.pillsLeft != null && med.pillsLeft! > 0) {
            final updatedMed = med.copyWith(pillsLeft: med.pillsLeft! - 1);
            try {
              await _client
                  .from('medicines')
                  .update({'pills_left': updatedMed.pillsLeft})
                  .eq('id', medicineId);
            } catch (_) {}
            _medicines[index] = updatedMed;
          }
        }
      }

      await loadIntakeLogs(profileId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error toggling medicine intake: $e");
      return false;
    }
  }

  // Trigger manual Care Tips generation via Edge Function
  Future<void> triggerCareTipsRegen(String profileId) async {
    _setLoading(true);
    try {
      await _invokeEdgeFunction('generate-care-tips', {'profileId': profileId});
    } catch (e) {
      debugPrint("Error triggering care tips: $e");
    } finally {
      _setLoading(false);
    }
  }

  // Delete profile
  Future<bool> deleteProfile(String profileId) async {
    _setLoading(true);
    try {
      await _invokeEdgeFunction(
        'manage-parent',
        {
          'action': 'delete',
          'profileId': profileId,
        },
      );
      await loadLinkedParents();
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint("Error deleting profile: $e");
      _setLoading(false);
      return false;
    }
  }

  // --- Health Records Methods ---
  Future<void> _saveLocalRecords(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _records.map((r) => r.toJson()).toList();
      await prefs.setString('local_health_records_$profileId', jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving local health records: $e");
    }
  }

  Future<void> _loadLocalRecords(String profileId) async {
    _records = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString('local_health_records_$profileId');
      if (rawJson != null && rawJson.isNotEmpty) {
        final List list = jsonDecode(rawJson);
        _records = list.map((r) => HealthRecord.fromJson(r)).toList();
      }
    } catch (e) {
      debugPrint("Error reading local health records: $e");
    }
  }

  Future<void> loadRecords(String profileId) async {
    // 1. Load from local cache first for instant display
    await _loadLocalRecords(profileId);
    notifyListeners();

    // 2. Sync with Supabase cloud
    try {
      final res = await _client
          .from('health_records')
          .select()
          .eq('profile_id', profileId)
          .order('record_date', ascending: false);

      if (res != null) {
        _records = (res as List).map((r) => HealthRecord.fromJson(r)).toList();
        await _saveLocalRecords(profileId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Supabase health_records sync error (using local cache): $e");
    }
  }

  Future<bool> addRecord(HealthRecord record) async {
    HealthRecord savedRecord = record;

    // 1. Attempt cloud insert to get real UUID from Supabase
    try {
      final res = await _client
          .from('health_records')
          .insert(record.toDbJson())
          .select()
          .single();
      savedRecord = HealthRecord.fromJson(res);
      debugPrint("Health record successfully saved to Supabase with ID: ${savedRecord.id}");
    } catch (e) {
      debugPrint("Supabase insert health record error (fallback local): $e");
    }

    // 2. Add to in-memory list & save to local cache
    _records.removeWhere((r) => r.id == record.id || r.id == savedRecord.id);
    _records.insert(0, savedRecord);
    await _saveLocalRecords(savedRecord.profileId);
    notifyListeners();
    return true;
  }

  Future<bool> updateRecord(HealthRecord record) async {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _records[index] = record;
    } else {
      _records.insert(0, record);
    }
    await _saveLocalRecords(record.profileId);
    notifyListeners();

    try {
      await _client.from('health_records').update(record.toDbJson()).eq('id', record.id);
    } catch (e) {
      debugPrint("Cloud update health record error (updated locally): $e");
    }
    return true;
  }

  Future<bool> deleteRecord(String recordId, String profileId) async {
    _records.removeWhere((r) => r.id == recordId);
    await _saveLocalRecords(profileId);
    notifyListeners();

    try {
      await _client.from('health_records').delete().eq('id', recordId);
    } catch (e) {
      debugPrint("Cloud delete health record error (deleted locally): $e");
    }
    return true;
  }

  // --- Profile Detail Methods ---
  Future<bool> updateProfileDetails(Profile profile) async {
    try {
      final json = profile.toJson();
      json['language'] = profile.language.toLowerCase();
      await _client.from('profiles').upsert(json);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_language', profile.language.toLowerCase());
      await prefs.setString('cached_profile', jsonEncode(json));

      // Reschedule all alarms with the updated language
      for (final med in _medicines) {
        await AlarmService.scheduleAlarm(med, profile);
      }

      await loadLinkedParents();
      return true;
    } catch (e) {
      debugPrint("Error updating profile details: $e");
      return true;
    }
  }
}
