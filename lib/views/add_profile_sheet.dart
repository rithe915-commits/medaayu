import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';

class AddProfileSheet extends StatefulWidget {
  final Profile profile;
  final VoidCallback onComplete;

  const AddProfileSheet({super.key, required this.profile, required this.onComplete});

  @override
  State<AddProfileSheet> createState() => _AddProfileSheetState();
}

class _AddProfileSheetState extends State<AddProfileSheet> {
  int _currentStep = 0; // 0: Role Select, 1: Plan Select, 2: Form Details

  // Selection state
  String _selectedRoleType = 'parent'; // 'self' or 'parent'
  PlanTier _selectedPlanTier = PlanTier.premium;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _sosPhoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  DateTime? _selectedDob;
  String _selectedGender = 'Male';
  String _selectedBlood = 'O+';
  String _selectedLanguage = 'english';

  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.profile.email ?? '';
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    int month1 = today.month;
    int month2 = birthDate.month;
    if (month2 > month1) {
      age--;
    } else if (month1 == month2) {
      int day1 = today.day;
      int day2 = birthDate.day;
      if (day2 > day1) {
        age--;
      }
    }
    return age;
  }

  Future<void> _handleSave() async {
    setState(() {
      _errorMessage = '';
    });

    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter name.");
      return;
    }

    final isParent = _selectedRoleType == 'parent';
    if (isParent) {
      final phoneVal = _parentPhoneController.text.trim();
      if (phoneVal.isEmpty) {
        setState(() => _errorMessage = "Please enter the phone number in which call will come.");
        return;
      }
      if (phoneVal.length != 10 || int.tryParse(phoneVal) == null) {
        setState(() => _errorMessage = "Please enter a valid 10-digit mobile number.");
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final db = Provider.of<DbService>(context, listen: false);
      final calculatedAge = _selectedDob != null ? _calculateAge(_selectedDob!) : 45;
      final emailVal = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();

      widget.onComplete();

      Future.microtask(() async {
        if (_selectedRoleType == 'self') {
          await auth.setupProfile(
            fullName: _nameController.text.trim(),
            role: UserRole.self,
            age: calculatedAge,
            gender: _selectedGender,
            bloodGroup: _selectedBlood,
            email: emailVal,
            planTier: PlanTier.premium,
            language: _selectedLanguage,
            sosAction: 'notify',
          );
        } else {
          final parentPhone = _parentPhoneController.text.trim();
          final parentProfile = await db.createParentProfile(
            fullName: _nameController.text.trim(),
            age: calculatedAge,
            gender: _selectedGender,
            bloodGroup: _selectedBlood,
            phone: parentPhone,
            sosContactPhone: _sosPhoneController.text.trim(),
            email: emailVal,
            planTier: PlanTier.premium,
            language: _selectedLanguage,
            sosAction: 'notify',
            role: UserRole.parent,
          );

          if (parentProfile != null) {
            await auth.switchProfile(parentProfile.id);
          }
        }
      });
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      setState(() => _errorMessage = cleanErr);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Add Profile / Member", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          _buildCurrentStepView(),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildRoleStep();
      case 1:
        return _buildPlanStep();
      case 2:
        return _buildDetailsStep();
      default:
        return Container();
    }
  }

  Widget _buildRoleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Who will be using this profile?",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 16),
        _buildRoleSelectionCard(
          title: "Myself (Self Profile)",
          description: "Reminders go directly to this registered device.",
          icon: Icons.person_outline_rounded,
          role: 'self',
        ),
        const SizedBox(height: 12),
        _buildRoleSelectionCard(
          title: "Parent / Family Member",
          description: "Reminders go to parent/family member phone.",
          icon: Icons.elderly_rounded,
          role: 'parent',
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentStep = 1;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3A86F0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRoleSelectionCard({
    required String title,
    required String description,
    required IconData icon,
    required String role,
  }) {
    final isSelected = _selectedRoleType == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRoleType = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A86F0) : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3A86F0).withOpacity(0.1) : Colors.black.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: isSelected ? const Color(0xFF3A86F0) : Colors.black45),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Reminder Delivery Feature", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 14),
        _buildPlanTierCard(
          tier: PlanTier.premium,
          title: "📞 Medaayu Voice Calling",
          price: "Standard Feature",
          color: const Color(0xFF6C5CE7),
          features: ["Automated Voice Call Reminders for every dose", "Local phone alarms & notifications included"],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _currentStep = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86F0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanTierCard({
    required PlanTier tier,
    required String title,
    required String price,
    required Color color,
    required List<String> features,
  }) {
    final isSelected = _selectedPlanTier == tier;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanTier = tier),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : Colors.black12, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, color: isSelected ? color : Colors.black26, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
                Text(price, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ...features.map((f) => Text("• $f", style: const TextStyle(fontSize: 12, color: Colors.black54))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    final isParent = _selectedRoleType == 'parent';
    final formattedDob = _selectedDob == null
        ? "Select Date of Birth"
        : "${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}";

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isParent ? "Parent / Member Information" : "Personal Information",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 14),

          // Name
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration("Full Name *"),
            validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
          ),
          const SizedBox(height: 12),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration("Email Address *"),
          ),
          const SizedBox(height: 12),

          // DOB Date Picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 40)),
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 110)),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDob = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formattedDob, style: TextStyle(color: _selectedDob == null ? Colors.black38 : const Color(0xFF1F2937))),
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF3A86F0)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15),
                  decoration: _inputDecoration("Gender"),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g, style: const TextStyle(color: Color(0xFF1F2937))),
                          ))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedGender = v); },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBlood,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15),
                  decoration: _inputDecoration("Blood Group"),
                  items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                      .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(b, style: const TextStyle(color: Color(0xFF1F2937))),
                          ))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedBlood = v); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isParent) ...[
            TextFormField(
              controller: _parentPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: _inputDecoration("Phone number in which call will come *").copyWith(prefixText: "+91 ", counterText: ""),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sosPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: _inputDecoration("Emergency/Caregiver SOS Number").copyWith(prefixText: "+91 ", counterText: ""),
            ),
            const SizedBox(height: 12),
          ],

          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),

          Row(
            children: [
              Expanded(
                child: TextButton(onPressed: () => setState(() => _currentStep = 1), child: const Text("Back")),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A86F0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Create Profile", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3A86F0), width: 2)),
    );
  }
}
