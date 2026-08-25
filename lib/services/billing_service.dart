import 'package:flutter/material.dart';
import '../models/profile.dart';
import 'auth_service.dart';

class BillingService extends ChangeNotifier {
  final AuthService _authService;
  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  BillingService(this._authService);

  // Gated features lookup
  static String getReminderChannelName(PlanTier tier) {
    return "Automated Voice Calls & Local Alarms";
  }

  // Gated channel behavior details
  static String getReminderBehaviorDescription(PlanTier tier) {
    return "Calls your mobile number and reads out dose instructions in your selected language.";
  }

  // Set the plan tier (currently a stub/direct database update)
  // This can be easily replaced with Google Play Billing later.
  Future<bool> purchasePlan(PlanTier tier) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final currentProfile = _authService.currentProfile;
      if (currentProfile == null) {
        _isProcessing = false;
        notifyListeners();
        return false;
      }

      // Update database profile record to reflect the new tier
      final success = await _authService.setupProfile(
        fullName: currentProfile.fullName,
        role: currentProfile.role,
        age: currentProfile.age,
        gender: currentProfile.gender,
        bloodGroup: currentProfile.bloodGroup,
        sosContactPhone: currentProfile.sosContactPhone,
        email: currentProfile.email,
        planTier: tier, // New Tier
        language: currentProfile.language,
        sosAction: currentProfile.sosAction,
        ownerId: currentProfile.ownerId,
        planExpiresAt: tier == PlanTier.premium ? DateTime.now().add(const Duration(days: 365)) : null,
      );

      if (success && currentProfile.email != null && currentProfile.email!.contains('@')) {
        final planTypeKey = tier == PlanTier.premium 
            ? 'plan_premium' 
            : tier == PlanTier.standard 
                ? 'plan_standard' 
                : 'plan_basic';
        _authService.sendEmailNotification(
          to: currentProfile.email!,
          type: planTypeKey,
          name: currentProfile.fullName,
        );
      }

      _isProcessing = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint("Billing Purchase Error: $e");
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // Purchase Add-on (e.g. Extra Medication Call Reminder ₹49/month)
  Future<bool> purchaseAddon(String addonName) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final currentProfile = _authService.currentProfile;
      if (currentProfile != null && currentProfile.email != null && currentProfile.email!.contains('@')) {
        await _authService.sendEmailNotification(
          to: currentProfile.email!,
          type: 'addon',
          name: currentProfile.fullName,
          addonName: addonName,
        );
      }
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Addon Purchase Error: $e");
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // SERVER-SIDE PURCHASING VERIFICATION (Placeholder for Google Play Billing)
  // To integrate, purchase using in_app_purchase package, retrieve purchaseToken,
  // and invoke this verify method.
  Future<bool> verifyPurchaseServer(String purchaseToken, String skuId) async {
    _isProcessing = true;
    notifyListeners();

    try {
      // In a live Play Billing setup, we call our Supabase verify-purchase edge function
      // and send the purchaseToken + skuId for server validation.
      
      /*
      final response = await Supabase.instance.client.functions.invoke(
        'verify-purchase',
        body: {
          'purchaseToken': purchaseToken,
          'skuId': skuId,
        },
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _authService.loadProfile();
        _isProcessing = false;
        notifyListeners();
        return true;
      }
      */

      // Simulated latency
      await Future.delayed(const Duration(seconds: 1));
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Server validation failed: $e");
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }
}
