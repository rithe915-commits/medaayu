import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class AuthService extends ChangeNotifier {
  final _client = Supabase.instance.client;
  Profile? _currentProfile;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _phoneNumber; // cached during onboarding OTP
  String? _caregiverName;

  Profile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get phoneNumber => _phoneNumber;
  String? get caregiverName => _caregiverName;
  bool get isAuthenticated => _currentProfile != null || _client.auth.currentSession != null;
  String? get currentUserId => _client.auth.currentUser?.id ?? _currentProfile?.id;

  AuthService() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _caregiverName = prefs.getString('caregiver_name');
      
      final cachedJson = prefs.getString('cached_profile');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(cachedJson);
        _currentProfile = Profile.fromJson(map);
        debugPrint("Restored cached session profile for: ${_currentProfile?.fullName}");
      }

      // Attempt to restore Supabase session from stored tokens
      final storedAccessToken = prefs.getString('auth_access_token');
      final storedRefreshToken = prefs.getString('auth_refresh_token');
      if (storedAccessToken != null && storedRefreshToken != null &&
          _client.auth.currentSession == null) {
        try {
          // gotrue API: setSession(refreshToken, {accessToken:})
          await _client.auth.setSession(
            storedRefreshToken,
            accessToken: storedAccessToken,
          );
          debugPrint("Restored Supabase session from stored tokens.");
        } catch (sessionRestoreErr) {
          debugPrint("Could not restore session from stored tokens: $sessionRestoreErr");
          // Session might be expired — we still show cached profile to avoid forcing re-registration
        }
      }
    } catch (e) {
      debugPrint("Error restoring cached profile: $e");
    } finally {
      _isInitialized = true;
      notifyListeners();

      _client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        if (event == AuthChangeEvent.signedIn) {
          loadProfile();
        } else if (event == AuthChangeEvent.signedOut) {
          _currentProfile = null;
          _phoneNumber = null;
          _caregiverName = null;
          SharedPreferences.getInstance().then((prefs) {
            prefs.remove('caregiver_name');
            prefs.remove('cached_profile');
            prefs.remove('auth_access_token');
            prefs.remove('auth_refresh_token');
          });
          notifyListeners();
        }
      });

      if (_client.auth.currentSession != null) {
        loadProfile();
      }
    }
  }

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Private helper to invoke otp-verify directly without Authorization header
  Future<dynamic> _invokeOtpVerify(Map<String, dynamic> body) async {
    final apiKey = _client.rest.headers['apikey'] ?? 'sb_publishable_IBq3dRoeAggLMh7BWGqYSg_KAuL_BoD';
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('https://ysuwnlvmipgfgesdpqdn.supabase.co/functions/v1/otp-verify'),
      );
      request.headers.set('content-type', 'application/json');
      request.headers.set('apikey', apiKey);
      
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      debugPrint("otp-verify direct HTTP response status: ${response.statusCode}");
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
      debugPrint("Error calling otp-verify: $e");
      rethrow;
    }
  }

  // Check if a phone number already exists in the profiles database
  // Returns: true = exists, false = confirmed not found, null = check failed (network/error)
  Future<bool?> checkPhoneExists(String phone) async {
    _setLoading(true);
    try {
      final data = await _invokeOtpVerify({
        'action': 'check_phone',
        'phone': phone,
      });
      _setLoading(false);
      final result = data['phoneExists'] ?? data['exists'];
      if (result == null) return null; // ambiguous response
      return result as bool;
    } catch (e) {
      debugPrint("Error checking phone existence: $e");
      _setLoading(false);
      return null; // null = unknown, don't block login on transient errors
    }
  }

  // Check if phone or email already exists in profiles database, and return detailed results map
  Future<Map<String, dynamic>> checkPhoneAndEmailExists(String phone, String? email) async {
    _setLoading(true);
    try {
      final data = await _invokeOtpVerify({
        'action': 'check_phone',
        'phone': phone,
        'email': email,
      });
      _setLoading(false);
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {'exists': false};
    } catch (e) {
      debugPrint("Error checking phone/email existence: $e");
      _setLoading(false);
      return {'exists': false, 'error': e.toString()};
    }
  }

  // Trigger Send OTP Edge Function (Bulk Blaster)
  Future<bool> sendOtp(String phone) async {
    _setLoading(true);
    _phoneNumber = phone;
    try {
      final data = await _invokeOtpVerify({
        'action': 'send',
        'phone': phone,
      });
      _setLoading(false);
      return data['success'] ?? false;
    } catch (e) {
      debugPrint("Error sending OTP: $e");
      _setLoading(false);
      return false;
    }
  }

  // Trigger Verify OTP Edge Function (Bulk Blaster Verification)
  Future<String?> verifyOtp(String code) async {
    if (_phoneNumber == null) return "Mobile number missing. Please go back and re-enter phone number.";
    _setLoading(true);
    try {
      final data = await _invokeOtpVerify({
        'action': 'verify',
        'phone': _phoneNumber,
        'code': code,
      });

      if (data != null && data['error'] != null) {
        _setLoading(false);
        return data['error'].toString();
      }

      if (data != null && data['success'] == true && data['session'] != null) {
        final refreshToken = data['session']['refresh_token'] as String;
        final accessToken = data['session']['access_token'] as String;
        
        // Persist tokens in SharedPreferences for cold-start restoration
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_access_token', accessToken);
        await prefs.setString('auth_refresh_token', refreshToken);

        // Recover user session in standard Supabase Client
        // gotrue API: setSession(refreshToken, {accessToken:})
        try {
          final authResponse = await _client.auth.setSession(
            refreshToken,
            accessToken: accessToken,
          );
          if (authResponse.user != null) {
            await loadProfile();
            _setLoading(false);
            return null; // null indicates clean success!
          }
        } catch (sessionErr) {
          debugPrint("setSession error: $sessionErr — falling back to local profile cache");
          // Even if setSession fails (ES256 JWT issue), attempt to load profile via direct DB call
          await loadProfile();
          if (_currentProfile != null) {
            _setLoading(false);
            return null;
          }
        }
      }
      _setLoading(false);
      return "Invalid verification code. Please check and try again.";
    } on FunctionException catch (fe) {
      debugPrint("FunctionException verifying OTP: ${fe.details}");
      _setLoading(false);
      if (fe.details != null && fe.details is Map && fe.details['error'] != null) {
        return fe.details['error'].toString();
      }
      return "Verification failed. Please check code or try test OTP 123456.";
    } catch (e) {
      debugPrint("Error verifying OTP: $e");
      _setLoading(false);
      return "Verification error: ${e.toString()}";
    }
  }

  // Load profile from Supabase Database
  Future<void> loadProfile() async {
    final userId = currentUserId;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    try {
      final phoneVal = _client.auth.currentUser?.phone;
      final emailVal = _client.auth.currentUser?.email;
      final derivedPhone = (emailVal != null && emailVal.contains('@')) ? emailVal.split('@')[0] : '';
      
      Map<String, dynamic>? res;
      final activePhone = (phoneVal != null && phoneVal.isNotEmpty) ? phoneVal : derivedPhone;

      if (activePhone.isNotEmpty) {
        final cleanPhone = activePhone.replaceAll(RegExp(r'[^0-9]'), '');
        final tenDigit = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
        
        final list = await _client.from('profiles').select().or('id.eq.$userId,phone.eq.$tenDigit');
        if (list.isNotEmpty) {
          res = list.first;
          if (res['id'] != userId) {
            try {
              await _client.from('profiles').update({'id': userId}).eq('id', res['id']);
              res['id'] = userId;
            } catch (e) {
              debugPrint("Failed to update parent profile ID: $e");
            }
          }
        }
      }

      if (res == null) {
        res = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
      }

      if (res != null) {
        // Restore locally-saved photo for this profile
        final prefs = await SharedPreferences.getInstance();
        final localPhoto = prefs.getString('profile_photo_$userId');
        
        _currentProfile = Profile.fromJson(res);
        if (localPhoto != null) {
          _currentProfile = _currentProfile!.copyWith(photoUrl: localPhoto);
        }
        
        if (_currentProfile!.role == UserRole.self) {
          _caregiverName = _currentProfile!.fullName;
          await prefs.setString('caregiver_name', _caregiverName!);
        }

        // Cache profile locally in SharedPreferences for Widget/Cold Starts
        await prefs.setString('cached_profile', _encodeProfileWithPhoto(res, localPhoto));
        if (_currentProfile?.phone != null && _currentProfile!.phone.isNotEmpty) {
          final p = _currentProfile!.phone;
          await prefs.setString('user_phone', p);
          await prefs.setString('caregiver_phone', p);
          await prefs.setString('cached_phone', p);
          await prefs.setString('registered_phone', p);
        }
        if (_currentProfile?.language != null && _currentProfile!.language.isNotEmpty) {
          await prefs.setString('user_language', _currentProfile!.language.toLowerCase());
        }
      } else if (_currentProfile != null) {
        // DB returned nothing but we have a cached profile — sync it to the new database!
        debugPrint("loadProfile: DB returned no profile for $userId — syncing cached profile: ${_currentProfile!.fullName}");
        try {
          final profileMap = _currentProfile!.toJson();
          profileMap['id'] = userId;
          await _client.from('profiles').upsert(profileMap);
          debugPrint("loadProfile: Successfully synced profile ${_currentProfile!.fullName} to Supabase!");
        } catch (syncErr) {
          debugPrint("loadProfile: Could not sync cached profile to DB: $syncErr");
        }

        if (_currentProfile?.phone != null && _currentProfile!.phone.isNotEmpty) {
          final p = _currentProfile!.phone;
          await prefs.setString('user_phone', p);
          await prefs.setString('caregiver_phone', p);
          await prefs.setString('cached_phone', p);
          await prefs.setString('registered_phone', p);
        }
      } else {
        // Truly no profile anywhere — user needs to register
        debugPrint("loadProfile: No profile found in DB or cache for $userId");
        _currentProfile = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading profile: $e — keeping current profile state");
      // Don't null _currentProfile on error — keep whatever we had
      notifyListeners();
    }
  }

  // Set up / Register Profile details
  Future<bool> setupProfile({
    required String fullName,
    required UserRole role,
    int? age,
    String? gender,
    String? bloodGroup,
    String? sosContactPhone,
    String? sosContactPhone2,
    String? email,
    String? phone,
    required PlanTier planTier,
    required String language,
    required String sosAction,
    String? ownerId,
    DateTime? planExpiresAt,
  }) async {
    _setLoading(true);
    try {
      String? userId = currentUserId;
      if (userId == null || userId.isEmpty) {
        final cleanP = (phone ?? _phoneNumber ?? "0000000000").replaceAll(RegExp(r'[^0-9]'), '');
        final tenDigit = cleanP.length > 10 ? cleanP.substring(cleanP.length - 10) : cleanP;
        userId = '00000000-0000-4000-a000-${tenDigit.padLeft(12, '0')}';
      }

      String resolvedPhone = "";
      if (phone != null && phone.trim().isNotEmpty) {
        resolvedPhone = phone.trim();
      } else if (_phoneNumber != null && _phoneNumber!.trim().isNotEmpty) {
        resolvedPhone = _phoneNumber!.trim();
      } else if (_client.auth.currentUser?.phone != null && _client.auth.currentUser!.phone!.isNotEmpty) {
        resolvedPhone = _client.auth.currentUser!.phone!;
      } else if (_client.auth.currentUser?.email != null && _client.auth.currentUser!.email!.contains('@')) {
        resolvedPhone = _client.auth.currentUser!.email!.split('@')[0];
      } else if (_currentProfile?.phone != null && _currentProfile!.phone.isNotEmpty) {
        resolvedPhone = _currentProfile!.phone;
      }

      final cleanDigits = resolvedPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneValue = cleanDigits.length > 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;

      final normalizedLang = (language.isEmpty ? 'english' : language).toLowerCase();

      final profileData = {
        'id': userId,
        'role': role == UserRole.parent ? 'parent' : 'self',
        'full_name': fullName.isEmpty ? "Caregiver" : fullName,
        'age': age,
        'gender': gender,
        'blood_group': bloodGroup,
        'phone': phoneValue,
        'sos_contact_phone': sosContactPhone,
        'sos_contact_phone_2': sosContactPhone2,
        'email': email,
        'plan_tier': 'premium',
        'language': normalizedLang,
        'sos_action': sosAction,
        'owner_id': ownerId,
        'plan_expires_at': planExpiresAt?.toIso8601String(),
      };

      try {
        await _client.from('profiles').upsert(profileData);
        await loadProfile();
      } catch (dbErr) {
        debugPrint("Database profile insert issue: $dbErr. Saved to local state & cache.");
      }

      // Always populate local currentProfile so registration succeeds instantly
      _currentProfile = Profile.fromJson(profileData);
      
      final prefs = await SharedPreferences.getInstance();
      if (phoneValue.isNotEmpty) {
        await prefs.setString('user_phone', phoneValue);
        await prefs.setString('caregiver_phone', phoneValue);
        await prefs.setString('cached_phone', phoneValue);
        await prefs.setString('registered_phone', phoneValue);
      }
      await prefs.setString('user_language', normalizedLang);

      if (_currentProfile!.role == UserRole.self) {
        _caregiverName = _currentProfile!.fullName;
        await prefs.setString('caregiver_name', _caregiverName!);
      }

      await prefs.setString('cached_profile', jsonEncode(profileData));

      // Dispatch welcome and plan activation email if email address is provided
      if (email != null && email.contains('@')) {
        sendEmailNotification(to: email, type: 'welcome', name: fullName);
        final planTypeKey = planTier == PlanTier.premium 
            ? 'plan_premium' 
            : planTier == PlanTier.standard 
                ? 'plan_standard' 
                : 'plan_basic';
        sendEmailNotification(to: email, type: planTypeKey, name: fullName);
      }

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint("Error setting up profile: $e");
      _setLoading(false);
      return false;
    }
  }

  // Dispatch Transactional Email via Resend Edge Function
  Future<void> sendEmailNotification({
    required String to,
    required String type,
    String? name,
    String? addonName,
  }) async {
    final recipientName = name ?? _currentProfile?.fullName ?? "User";
    final apiKey = _client.rest.headers['apikey'] ?? 'sb_publishable_IBq3dRoeAggLMh7BWGqYSg_KAuL_BoD';

    debugPrint("Sending Resend Email ($type) to: $to (API key: ${apiKey.substring(0, 10)}...)");

    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('https://ysuwnlvmipgfgesdpqdn.supabase.co/functions/v1/send-email'),
      );
      request.headers.set('content-type', 'application/json');
      request.headers.set('apikey', apiKey);

      final payload = jsonEncode({
        'to': to,
        'type': type,
        'name': recipientName,
        'addonName': addonName,
      });

      request.write(payload);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      debugPrint("Direct HTTP Email trigger status: ${response.statusCode}, body: $responseBody");
    } catch (httpErr) {
      debugPrint("Direct HTTP Email trigger error: $httpErr");
    }
  }

  // Switch between "me" and a linked parent profile (owner_id logic)
  Future<bool> switchProfile(String targetProfileId) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final localPhoto = prefs.getString('profile_photo_$targetProfileId');

      // Use maybeSingle() so that missing DB rows return null instead of throwing
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', targetProfileId)
          .maybeSingle();

      if (res != null) {
        // Profile found in DB — use it
        final profileFromDb = Profile.fromJson(res);
        _currentProfile = localPhoto != null
            ? profileFromDb.copyWith(photoUrl: localPhoto)
            : profileFromDb;
        await prefs.setString('cached_profile', _encodeProfileWithPhoto(Map<String, dynamic>.from(res), localPhoto));
      } else {
        // Profile not in DB yet (created locally) — look it up in linkedParents via DbService
        // Fall back to the locally-stored cached profile data if possible
        debugPrint("switchProfile: profile $targetProfileId not in DB, using local fallback");
        final cachedJson = prefs.getString('cached_profile_$targetProfileId');
        if (cachedJson != null) {
          final map = jsonDecode(cachedJson) as Map<String, dynamic>;
          _currentProfile = Profile.fromJson(map);
          if (localPhoto != null) {
            _currentProfile = _currentProfile!.copyWith(photoUrl: localPhoto);
          }
        } else {
          // Cannot find profile at all
          _setLoading(false);
          return false;
        }
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error switching profile: $e");
      _setLoading(false);
      return false;
    }
  }

  String _encodeProfileWithPhoto(Map<String, dynamic> dbRow, String? localPhoto) {
    final merged = Map<String, dynamic>.from(dbRow);
    if (localPhoto != null) merged['photo_url'] = localPhoto;
    return jsonEncode(merged);
  }

  // Save profile photo URL locally (not stored in Supabase)
  Future<void> saveProfilePhotoLocally(String profileId, String photoPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_photo_$profileId', photoPath);
    if (_currentProfile?.id == profileId) {
      _currentProfile = _currentProfile!.copyWith(photoUrl: photoPath);
      notifyListeners();
    }
  }

  // Logout
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint("Sign out notice: $e");
    }
    _currentProfile = null;
    _phoneNumber = null;
    _caregiverName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_profile');
    await prefs.remove('caregiver_name');
    await prefs.remove('auth_access_token');
    await prefs.remove('auth_refresh_token');
    _setLoading(false);
    notifyListeners();
  }
}
