import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';
import '../models/profile.dart';

class AlarmService {
  // Initialize alarm manager
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
    debugPrint("AlarmService Initialized successfully.");
  }

  // Request exact alarm permissions for Android 13/14+
  static Future<void> requestPermissions() async {
    // Exact alarm permissions handled via AndroidManifest
  }

  // Helper to convert UUID to a unique 32-bit Integer ID
  static int _getUniqueId(String uuid) {
    return uuid.hashCode & 0x7FFFFFFF;
  }

  // Helper to parse time string safely (handles 24hr "15:30", "15:30:00", 12hr "03:30 PM", "3:30 pm")
  static TimeOfDay _parseTimeString(String rawTime) {
    int hour = 8;
    int minute = 0;
    final clean = rawTime.trim().toUpperCase();
    if (clean.contains('AM') || clean.contains('PM')) {
      final isPM = clean.contains('PM');
      final digits = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digits.split(':');
      hour = int.tryParse(parts[0]) ?? 8;
      minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      if (isPM && hour < 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
    } else {
      final parts = clean.split(':');
      hour = int.tryParse(parts[0]) ?? 8;
      minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  // Schedule an exact daily alarm
  static Future<bool> scheduleAlarm(Medicine medicine, Profile profile) async {
    final int alarmId = _getUniqueId(medicine.id);
    final timeOfDay = _parseTimeString(medicine.doseTime);
    final int hour = timeOfDay.hour;
    final int minute = timeOfDay.minute;

    // Save details to SharedPreferences so the background isolate callback can read it
    final prefs = await SharedPreferences.getInstance();
    String targetPhone = profile.phone;
    if (targetPhone.length < 10) {
      targetPhone = prefs.getString('user_phone') ??
          prefs.getString('caregiver_phone') ??
          prefs.getString('cached_phone') ??
          prefs.getString('registered_phone') ??
          "";
    }

    final resolvedLang = (profile.language.isNotEmpty
            ? profile.language
            : prefs.getString('user_language')) ??
        'english';

    final cacheData = {
      'medicineId': medicine.id,
      'userName': profile.fullName,
      'medicineName': medicine.name,
      'language': resolvedLang.toLowerCase(),
      'foodInstruction': medicine.foodInstruction,
      'planTier': 'premium',
      'phone': targetPhone,
      'profileId': profile.id,
      'doseTime': medicine.doseTime,
    };
    await prefs.setString('alarm_data_$alarmId', jsonEncode(cacheData));

    // Calculate next occurrence
    final DateTime now = DateTime.now();
    DateTime scheduledDate = DateTime(now.year, now.month, now.day, hour, minute, 0);

    // If scheduled for current minute or within 2 minutes past, trigger in 3 seconds!
    final diffInSeconds = now.difference(scheduledDate).inSeconds;
    if (diffInSeconds >= 0 && diffInSeconds < 120) {
      scheduledDate = now.add(const Duration(seconds: 3));
    } else if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint("Scheduling voice call reminder for ${medicine.name} to $targetPhone at $scheduledDate (ID: $alarmId)");

    // 1. If scheduled within 120 minutes, also register in-app timer fallback
    final Duration delayDuration = scheduledDate.difference(DateTime.now());
    if (!delayDuration.isNegative && delayDuration.inMinutes <= 120) {
      debugPrint("Registering In-App Timer fallback in ${delayDuration.inSeconds}s for $alarmId");
      Future.delayed(delayDuration, () async {
        debugPrint("In-App Timer fallback fired for alarm $alarmId!");
        await alarmCallback(alarmId);
      });
    }

    // 2. Schedule AndroidAlarmManager exact alarm with try-catch fallback
    bool success = false;
    try {
      success = await AndroidAlarmManager.oneShotAt(
        scheduledDate,
        alarmId,
        alarmCallback,
        exact: true,
        wakeup: true,
        alarmClock: false, // Pure background task, NO device alarm clock icon or alarm sound
        allowWhileIdle: true,
      );
    } catch (e) {
      debugPrint("Exact alarm failed ($e). Retrying inexact alarm...");
      try {
        success = await AndroidAlarmManager.oneShotAt(
          scheduledDate,
          alarmId,
          alarmCallback,
          exact: false,
          wakeup: true,
          allowWhileIdle: true,
        );
      } catch (e2) {
        debugPrint("Inexact alarm also failed: $e2");
      }
    }

    return success;
  }

  // Cancel an alarm
  static Future<bool> cancelAlarm(Medicine medicine) async {
    final int alarmId = _getUniqueId(medicine.id);
    debugPrint("Cancelling alarm ID: $alarmId");
    
    // Clear cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('alarm_data_$alarmId');

    // Cancel from systems
    return await AndroidAlarmManager.cancel(alarmId);
  }

  // Static top-level background isolate entry point
  @pragma('vm:entry-point')
  static Future<void> alarmCallback(int id) async {
    debugPrint("Alarm Callback fired! ID: $id");

    // Fetch cached details from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('alarm_data_$id');
    
    String userName = "Parent";
    String medicineName = "Medicine";
    String language = "english";
    String foodInstruction = "before_food";
    String planTier = "basic";
    String phone = "";
    String profileId = "";
    String doseTime = "08:00";

    String medicineId = "";

    if (jsonStr != null) {
      final cacheData = jsonDecode(jsonStr);
      medicineId = cacheData['medicineId'] ?? "";
      userName = cacheData['userName'] ?? "Parent";
      medicineName = cacheData['medicineName'] ?? "Medicine";
      language = cacheData['language'] ?? "english";
      foodInstruction = cacheData['foodInstruction'] ?? "before_food";
      planTier = cacheData['planTier'] ?? "basic";
      phone = cacheData['phone'] ?? "";
      profileId = cacheData['profileId'] ?? "";
      doseTime = cacheData['doseTime'] ?? "08:00";
    }

    // Fallback: If phone is missing or short, look up saved caregiver/user phone from SharedPreferences
    if (phone.isEmpty || phone.length < 10) {
      phone = prefs.getString('user_phone') ?? prefs.getString('caregiver_phone') ?? prefs.getString('cached_phone') ?? prefs.getString('registered_phone') ?? "";
    }
    if (language.isEmpty) {
      language = prefs.getString('user_language') ?? 'english';
    }

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    // Trigger Voice Call for all scheduled alarms if phone is provided
    if (phone.isNotEmpty && phone.length >= 10) {
      debugPrint(">>> TRIGGERING SCHEDULED VOICE CALL to $phone for $medicineName (Lang: $language, Time: $doseTime)");
      final success = await triggerVoiceCallDirect(
        phone: phone,
        userName: userName,
        medicineName: medicineName,
        language: language,
        profileId: profileId,
        doseTime: doseTime,
      );
      debugPrint(">>> Voice call result: $success");
    } else {
      debugPrint(">>> CANNOT MAKE CALL: Phone is invalid or missing: '$phone' for $medicineName");
    }

    // Re-schedule for next day at exact time
    final DateTime nextDate = DateTime.now().add(const Duration(days: 1));
    try {
      await AndroidAlarmManager.oneShotAt(
        nextDate,
        id,
        alarmCallback,
        exact: true,
        wakeup: true,
        alarmClock: false,
        allowWhileIdle: true,
      );
    } catch (_) {
      try {
        await AndroidAlarmManager.oneShotAt(
          nextDate,
          id,
          alarmCallback,
          exact: false,
          wakeup: true,
          allowWhileIdle: true,
        );
      } catch (_) {}
    }
  }

  // Trigger automated voice call directly via HttpClient (bypasses ES256 gateway conflicts)
  static Future<bool> triggerVoiceCallDirect({
    required String phone,
    required String userName,
    required String medicineName,
    required String language,
    String? profileId,
    String? doseTime,
    String? dosage,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Send clean 10-digit phone; edge function will format with country code
    final tenDigitPhone = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    if (tenDigitPhone.isEmpty || tenDigitPhone.length < 10) return false;

    final anonKey = 'sb_publishable_IBq3dRoeAggLMh7BWGqYSg_KAuL_BoD';

    try {
      final client = HttpClient();
      // Try Vercel fast backend first
      HttpClientRequest request;
      try {
        request = await client.postUrl(
          Uri.parse('https://medaayufinal.vercel.app/api/send-reminder'),
        );
      } catch (_) {
        request = await client.postUrl(
          Uri.parse('https://ysuwnlvmipgfgesdpqdn.supabase.co/functions/v1/send-reminder'),
        );
      }
      request.headers.set('content-type', 'application/json');
      request.headers.set('apikey', anonKey);
      request.headers.set('Authorization', 'Bearer $anonKey');

      final payload = jsonEncode({
        'action': 'trigger_voice_call',
        'profileId': profileId ?? '',
        'phone': tenDigitPhone,
        'userName': userName,
        'medicineName': medicineName,
        'dosage': dosage ?? '1 tablet',
        'language': language,
        'doseTime': doseTime ?? '08:00',
      });

      request.write(payload);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      debugPrint("Direct HTTP Voice Call response status: ${response.statusCode}, body: $responseBody");
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (httpErr) {
      debugPrint("Direct HTTP Voice Call error: $httpErr");
      return false;
    }
  }
}
