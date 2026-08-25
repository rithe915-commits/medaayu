import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();

  // Phone + OTP controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // Profile Info controllers
  final TextEditingController _caregiverNameController = TextEditingController();
  final TextEditingController _caregiverEmailController = TextEditingController();
  
  bool _isLoginMode = true;
  String _selectedLanguage = "english";
  String _errorMessage = "";

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleSendOtp(AuthService auth) async {
    setState(() => _errorMessage = "");
    if (!_isLoginMode) {
      if (_caregiverNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = "Please enter your Full Name.");
        return;
      }
      final email = _caregiverEmailController.text.trim();
      if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        setState(() => _errorMessage = "Please enter a valid email address.");
        return;
      }
    }
    if (_phoneController.text.trim().length < 10) {
      setState(() => _errorMessage = "Please enter a valid 10-digit phone number.");
      return;
    }

    final phone = _phoneController.text.trim();
    final email = !_isLoginMode ? _caregiverEmailController.text.trim() : null;

    if (_isLoginMode) {
      final exists = await auth.checkPhoneExists(phone);
      if (exists == false) {
        // Confirmed not in DB — tell user to register
        setState(() => _errorMessage = "This phone number is not registered. Please register first.");
        return;
      }
      // exists == null means check failed (network/server error) → proceed with OTP anyway
      // The OTP verify step will handle authentication correctly
    } else {
      final checkResult = await auth.checkPhoneAndEmailExists(phone, email);
      final phoneExists = checkResult['phoneExists'] ?? false;
      final emailExists = checkResult['emailExists'] ?? false;
      final phoneEmail = checkResult['phoneEmail'] as String?;
      final emailPhone = checkResult['emailPhone'] as String?;

      if (phoneExists) {
        if (phoneEmail != null && email != null && phoneEmail.toLowerCase() != email.toLowerCase()) {
          setState(() => _errorMessage = "This phone number is already registered with another email ($phoneEmail).");
        } else {
          setState(() => _errorMessage = "This phone number is already registered. Please log in instead.");
        }
        return;
      }

      if (emailExists) {
        if (emailPhone != null && emailPhone != phone) {
          setState(() => _errorMessage = "This email is already registered with another phone number ($emailPhone).");
        } else {
          setState(() => _errorMessage = "This email is already registered. Please log in instead.");
        }
        return;
      }
    }

    final success = await auth.sendOtp(phone);
    if (success) {
      _nextPage();
    } else {
      setState(() => _errorMessage = "Failed to send OTP. Please try again.");
    }
  }

  Future<void> _handleVerifyOtp(AuthService auth) async {
    setState(() => _errorMessage = "");
    if (_otpController.text.length < 6) {
      setState(() => _errorMessage = "Please enter the 6-digit verification code.");
      return;
    }
    final verifyError = await auth.verifyOtp(_otpController.text);
    if (verifyError == null) {
      // OTP verified successfully. Give loadProfile() a moment to complete.
      if (auth.currentProfile == null) {
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (auth.currentProfile == null) {
        if (_isLoginMode) {
          // Login mode: profile should already exist in DB.
          // If still null, it means the profile wasn't found — guide to register.
          setState(() => _errorMessage =
              "Your account was verified but profile was not found. Please register to create your profile.");
          return;
        } else {
          // Register mode: create a new profile
          final profileCreated = await auth.setupProfile(
            fullName: _caregiverNameController.text.trim(),
            role: UserRole.self,
            email: _caregiverEmailController.text.trim().isEmpty
                ? null
                : _caregiverEmailController.text.trim(),
            phone: _phoneController.text.trim(),
            planTier: PlanTier.premium,
            language: _selectedLanguage,
            sosAction: 'notify',
          );
          if (!profileCreated) {
            setState(() =>
                _errorMessage = "Failed to finalize registration. Please try again.");
            return;
          }
        }
      }
      // Profile loaded (or created) — the AuthGate widget will auto-navigate to Dashboard
    } else {
      setState(() => _errorMessage = verifyError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEBF3FF), Color(0xFFF4F6FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcomeStep(auth),
                    _buildOtpStep(auth),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(AuthService auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // MedAayu Logo
          Image.asset(
            'assets/logo.png',
            height: 190,
            width: 190,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          Text(
            "Medicine reminders & safety care for elders",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF1F2937).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 48),
          // Clean white Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isLoginMode ? "Log In" : "Register",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 16),
                if (!_isLoginMode) ...[
                  TextField(
                    controller: _caregiverNameController,
                    style: const TextStyle(color: Color(0xFF1F2937)),
                    decoration: _buildInputDecoration("Full Name *").copyWith(
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF3A86F0)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _caregiverEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Color(0xFF1F2937)),
                    decoration: _buildInputDecoration("Email Address *").copyWith(
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF3A86F0)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: _buildInputDecoration("Preferred Reminder Language *").copyWith(
                      prefixIcon: const Icon(Icons.language_rounded, color: Color(0xFF3A86F0)),
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15),
                    items: const [
                      DropdownMenuItem(value: "english", child: Text("🇬🇧 English")),
                      DropdownMenuItem(value: "hindi", child: Text("🇮🇳 हिंदी (Hindi)")),
                      DropdownMenuItem(value: "marathi", child: Text("🇮🇳 मराठी (Marathi)")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedLanguage = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18),
                  decoration: _buildInputDecoration("Mobile Number").copyWith(
                    prefixText: "+91 ",
                    prefixStyle: const TextStyle(color: Color(0xFF1F2937), fontSize: 18),
                    prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF3A86F0)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Note: Please enter your correct mobile number so that call/reminders can reach this device successfully.",
                  style: TextStyle(color: Colors.black38, fontSize: 11, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
                  ),
                auth.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF3A86F0)))
                    : ElevatedButton(
                        onPressed: () => _handleSendOtp(auth),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A86F0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isLoginMode ? "Send Login OTP" : "Send Registration OTP",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                  child: Text(
                    _isLoginMode ? "New here? Register a new account" : "Already have an account? Log In",
                    style: const TextStyle(color: Color(0xFF3A86F0), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STEP 1: OTP Entry
  Widget _buildOtpStep(AuthService auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          const SizedBox(height: 48),
          const Text(
            "Verify OTP",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter the 6-digit code sent to +91 ${_phoneController.text}",
            textAlign: TextAlign.center,
            style: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.6)),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(color: Color(0xFF1F2937), fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "000000",
                    hintStyle: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.2)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.black12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF3A86F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
                  ),
                auth.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF3A86F0)))
                    : ElevatedButton(
                        onPressed: () => _handleVerifyOtp(auth),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A86F0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text("Verify & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () async {
                        setState(() => _errorMessage = "");
                        final success = await auth.sendOtp(_phoneController.text.trim());
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("A new OTP has been sent!")),
                          );
                        } else {
                          setState(() => _errorMessage = "Failed to resend OTP. Please try again.");
                        }
                      },
                      child: const Text("Resend OTP", style: TextStyle(color: Color(0xFF3A86F0), fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: _prevPage,
                      child: Text("Change Phone", style: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.5))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.5), fontSize: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF3A86F0)),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
