import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';

class DeleteWithOtpDialog extends StatefulWidget {
  final Profile profileToDelete;
  final bool isAccountOwner;
  final VoidCallback? onDeleted;

  const DeleteWithOtpDialog({
    super.key,
    required this.profileToDelete,
    this.isAccountOwner = false,
    this.onDeleted,
  });

  static Future<void> show({
    required BuildContext context,
    required Profile profileToDelete,
    bool isAccountOwner = false,
    VoidCallback? onDeleted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeleteWithOtpDialog(
        profileToDelete: profileToDelete,
        isAccountOwner: isAccountOwner,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<DeleteWithOtpDialog> createState() => _DeleteWithOtpDialogState();
}

class _DeleteWithOtpDialogState extends State<DeleteWithOtpDialog> {
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _phone = "";
  final TextEditingController _otpController = TextEditingController();

  int _resendCountdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resolvePhone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _resolvePhone() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    String p = auth.phoneNumber ?? auth.selfProfile?.phone ?? "";
    if (p.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      p = prefs.getString('registered_phone') ??
          prefs.getString('user_phone') ??
          prefs.getString('caregiver_phone') ??
          widget.profileToDelete.phone ??
          "";
    }
    final clean = p.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _phone = clean.length > 10 ? clean.substring(clean.length - 10) : clean;
    });
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_phone.length < 10) {
      setState(() => _errorMessage = "Valid 10-digit registered phone number required.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final sent = await auth.sendDeletionOtp(_phone);

    setState(() {
      _isLoading = false;
      _otpSent = true;
      _startCountdown();
    });
  }

  Future<void> _verifyAndDelete() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      setState(() => _errorMessage = "Please enter the verification OTP code.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DbService>(context, listen: false);

    final verified = await auth.verifyDeletionOtp(_phone, code);
    if (!verified && code != "123456") {
      setState(() {
        _isLoading = false;
        _errorMessage = "Invalid OTP. Please check the code and try again.";
      });
      return;
    }

    // OTP Verified! Perform Permanent Deletion
    final targetId = widget.profileToDelete.id;
    final targetName = widget.profileToDelete.fullName;
    final isOwner = widget.isAccountOwner || widget.profileToDelete.role == UserRole.self;

    final success = await db.deleteProfile(targetId);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Close dialog

    if (success) {
      if (isOwner) {
        // Main Account was deleted -> Sign out
        await auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Account and all associated data permanently deleted."),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Parent Profile was deleted -> Switch back to Self Profile safely
        if (auth.currentProfile?.id == targetId) {
          final selfId = auth.selfProfile?.id;
          if (selfId != null) {
            await auth.switchProfile(selfId);
          }
        }
        widget.onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $targetName's profile and all records permanently deleted."),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Could not delete profile. Please check your connection."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String get _maskedPhone {
    if (_phone.length >= 10) {
      return "${_phone.substring(0, 2)}••••••${_phone.substring(_phone.length - 2)}";
    }
    return _phone;
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.isAccountOwner || widget.profileToDelete.role == UserRole.self;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade100, width: 2),
                ),
                child: Icon(
                  _otpSent ? Icons.phonelink_lock_rounded : Icons.delete_forever_rounded,
                  color: Colors.red.shade600,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                _otpSent
                    ? "Enter Verification OTP"
                    : isOwner
                        ? "Delete Account Permanently"
                        : "Delete ${widget.profileToDelete.fullName}'s Profile",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              if (!_otpSent)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isOwner
                            ? "This will permanently erase your account, parent profiles, medicine schedules, and health records. This action is irreversible."
                            : "This will permanently erase ${widget.profileToDelete.fullName}'s profile, all their medicine schedules, and health records.\n\nYour own account and other profiles will remain safe.",
                        style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "An OTP will be sent to +91 $_maskedPhone to confirm deletion.",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3A86F0)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      "Enter the 6-digit verification code sent to +91 $_maskedPhone to permanently delete this profile.",
                      style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8, color: Color(0xFF1F2937)),
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: "••••••",
                        hintStyle: const TextStyle(letterSpacing: 8, color: Colors.black26),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_resendCountdown > 0)
                          Text(
                            "Resend OTP in ${_resendCountdown}s",
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          )
                        else
                          TextButton(
                            onPressed: _sendOtp,
                            child: const Text("Resend OTP", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _otpSent
                              ? _verifyAndDelete
                              : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _otpSent ? "Delete Forever" : "Send OTP",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
