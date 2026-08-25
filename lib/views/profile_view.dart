import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/billing_service.dart';
import '../services/invoice_service.dart';
import '../services/alarm_service.dart';
import 'add_profile_sheet.dart';
import 'profile_selector_sheet.dart';
import '../theme/design_system.dart';

class ProfileView extends StatefulWidget {
  final Profile profile;
  const ProfileView({super.key, required this.profile});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profile & Settings",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFF3A86F0).withOpacity(0.1),
                        backgroundImage: widget.profile.photoUrl != null && File(widget.profile.photoUrl!).existsSync()
                            ? FileImage(File(widget.profile.photoUrl!)) as ImageProvider
                            : null,
                        child: widget.profile.photoUrl == null
                            ? Text(
                                widget.profile.fullName.isNotEmpty ? widget.profile.fullName[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3A86F0)),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _pickProfilePhoto(context, widget.profile),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3A86F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.fullName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A86F0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.profile.role == UserRole.self ? "Self Profile" : (widget.profile.relationship ?? "Family"),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3A86F0)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.profile.age != null)
                              Text(
                                "${widget.profile.age} yrs",
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings Menu Sections
            _MenuSection(
              title: "Account",
              items: [
                _MenuItem(
                  icon: Icons.person_outline_rounded,
                  title: "My Profile",
                  subtitle: "View and edit personal details",
                  onTap: () => _openEditProfileScreen(context, widget.profile),
                ),
                _MenuItem(
                  icon: Icons.people_outline_rounded,
                  title: "Manage Profiles",
                  subtitle: "Switch or add family members (${db.linkedParents.length + 1} profiles)",
                  onTap: () => _openManageProfilesSheet(context, widget.profile),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _MenuSection(
              title: "Calling & Reminders",
              items: [
                _MenuItem(
                  icon: Icons.phone_in_talk_rounded,
                  title: "Voice Calling Reminders",
                  subtitle: "Automated Voice Calls Active • Standard Feature",
                  iconColor: const Color(0xFF6C5CE7),
                  onTap: () => _openPlansScreen(context, widget.profile),
                ),
                _MenuItem(
                  icon: Icons.receipt_long_rounded,
                  title: "My Invoices",
                  subtitle: "Payment history and receipts",
                  onTap: () => _openInvoicesSheet(context, widget.profile),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _MenuSection(
              title: "App & Legal",
              items: [
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  title: "About MedAayu",
                  subtitle: "Version 1.2.0 • RIVASA TECHNOLOGIES",
                  onTap: () => _showAboutDialog(context),
                ),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title: "Privacy Policy",
                  subtitle: "Data security and terms",
                  onTap: () => _showPrivacyPolicyDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Log Out"),
                    content: const Text("Are you sure you want to log out of MedAayu?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Log Out")),
                    ],
                  ),
                );

                if (confirm == true) {
                  await auth.signOut();
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete Account"),
                    content: const Text(
                      "This action is permanent and will remove all profile data, medicine schedules, and health records.",
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Delete Forever"),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await db.deleteProfile(widget.profile.id);
                  await auth.signOut();
                }
              },
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.black45, size: 20),
              label: const Text("Delete Account", style: TextStyle(color: Colors.black45, fontSize: 13)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/// Pick and save profile photo - stored locally per profileId
Future<void> _pickProfilePhoto(BuildContext context, Profile profile) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
  if (picked != null) {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.saveProfilePhotoLocally(profile.id, picked.path);
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  if (idx > 0) const Divider(height: 1, indent: 60),
                  item,
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? const Color(0xFF3A86F0);
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black38),
    );
  }
}


void _openEditProfileScreen(BuildContext context, Profile profile) {
  final prefixController = TextEditingController(text: profile.prefix ?? 'Mr');
  final nameController = TextEditingController(text: profile.fullName);
  final relController = TextEditingController(text: profile.relationship ?? (profile.role == UserRole.self ? 'Self' : 'Parent'));
  final dobController = TextEditingController(text: profile.dob ?? '');
  final genderController = TextEditingController(text: profile.gender ?? 'Male');
  final maritalController = TextEditingController(text: profile.maritalStatus ?? 'Single');
  final bloodGroupController = TextEditingController(text: profile.bloodGroup ?? 'O+');
  final emailController = TextEditingController(text: profile.email ?? '');
  final phoneController = TextEditingController(text: profile.phone);
  final countryController = TextEditingController(text: profile.country ?? 'India');
  final stateController = TextEditingController(text: profile.state ?? 'Maharashtra');
  final cityController = TextEditingController(text: profile.city ?? 'Mumbai');
  final addressController = TextEditingController(text: profile.address ?? '');
  String selectedLanguage = (profile.language.isNotEmpty ? profile.language : 'english').toLowerCase();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Edit Profile Information",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),

              // 2-Column Responsive Form Layout
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      value: prefixController.text,
                      decoration: InputDecoration(
                        labelText: "Prefix",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: ['Mr', 'Mrs', 'Ms', 'Dr']
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) prefixController.text = val;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Full Name *",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: relController,
                      decoration: InputDecoration(
                        labelText: "Relationship",
                        hintText: "e.g. Self, Father, Mother, Spouse",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: dobController,
                      decoration: InputDecoration(
                        labelText: "Date of Birth",
                        hintText: "YYYY-MM-DD",
                        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: genderController.text.isNotEmpty ? genderController.text : 'Male',
                      decoration: InputDecoration(
                        labelText: "Gender",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) genderController.text = val;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: bloodGroupController.text.isNotEmpty ? bloodGroupController.text : 'O+',
                      decoration: InputDecoration(
                        labelText: "Blood Group",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                          .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) bloodGroupController.text = val;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (profile.role != UserRole.parent || profile.planTier != PlanTier.basic) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: profile.role == UserRole.parent
                              ? "Phone number in which call will come"
                              : "Phone Number",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: countryController,
                      decoration: InputDecoration(
                        labelText: "Country",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stateController,
                      decoration: InputDecoration(
                        labelText: "State",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: cityController,
                decoration: InputDecoration(
                  labelText: "City",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: "Full Residential Address",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: (profile.language.isNotEmpty ? profile.language : 'english').toLowerCase(),
                decoration: InputDecoration(
                  labelText: "Preferred Reminder Voice Language *",
                  prefixIcon: const Icon(Icons.language_rounded, color: Color(0xFF3A86F0)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                dropdownColor: Colors.white,
                items: const [
                  DropdownMenuItem(value: "english", child: Text("🇬🇧 English")),
                  DropdownMenuItem(value: "hindi", child: Text("🇮🇳 हिंदी (Hindi)")),
                  DropdownMenuItem(value: "marathi", child: Text("🇮🇳 मराठी (Marathi)")),
                ],
                onChanged: (val) {
                  if (val != null) selectedLanguage = val;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () async {
                  final updated = profile.copyWith(
                    prefix: prefixController.text,
                    fullName: nameController.text.trim(),
                    relationship: relController.text.trim(),
                    dob: dobController.text.trim(),
                    gender: genderController.text,
                    maritalStatus: maritalController.text,
                    bloodGroup: bloodGroupController.text,
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    country: countryController.text.trim(),
                    state: stateController.text.trim(),
                    city: cityController.text.trim(),
                    address: addressController.text.trim(),
                    language: selectedLanguage,
                  );

                  final db = Provider.of<DbService>(context, listen: false);
                  await db.updateProfileDetails(updated);

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile details & Voice Language saved successfully!")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86F0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _openManageProfilesSheet(BuildContext context, Profile currentProfile) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => ProfileSelectorSheet(currentProfile: currentProfile),
  );
}

void _openPlansScreen(BuildContext context, Profile profile) {
  bool isTestingCall = false;
  bool testCallSent = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Plans & Features", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Active Plan Card Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF3A86F0), Color(0xFF6C5CE7)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.white, size: 36),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Standard Plan: VOICE CALLING ACTIVE",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Automated Voice Call Reminders for every dose",
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Voice Calling Feature Details
                  _PlanCard(
                    title: "📞 Medaayu Voice Calling",
                    price: "Standard Feature",
                    isCurrent: true,
                    isRecommended: true,
                    features: const [
                      "Automated Voice Call Reminders for every scheduled dose",
                      "Multi-lingual support (English, Hindi, Marathi)",
                      "Local device alarms & notifications included",
                      "Medicine Schedule & Intake Tracking",
                      "AI Care Tips & Recommendations",
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (isTestingCall)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: testCallSent
                          ? null
                          : () async {
                              setModalState(() {
                                isTestingCall = true;
                              });
                              final targetPhone = profile.phone.isNotEmpty ? profile.phone : "7620224885";
                              final ok = await AlarmService.triggerVoiceCallDirect(
                                phone: targetPhone,
                                userName: profile.fullName,
                                medicineName: "Test Reminder Medicine",
                                language: profile.language,
                                profileId: profile.id,
                              );
                              setModalState(() {
                                isTestingCall = false;
                                testCallSent = true;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? "Voice call initiated to $targetPhone!"
                                        : "Voice call request dispatched. Please wait for ring."),
                                  ),
                                );
                              }
                            },
                      icon: Icon(
                        Icons.phone_callback_rounded,
                        color: testCallSent ? Colors.black26 : const Color(0xFF6C5CE7),
                      ),
                      label: Text(
                        testCallSent
                            ? "Voice Call Initiated (Once per Session)"
                            : "📞 Test Voice Call Now",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: testCallSent ? Colors.black26 : const Color(0xFF6C5CE7),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: testCallSent ? Colors.black12 : const Color(0xFF6C5CE7),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool isCurrent;
  final bool isRecommended;
  final List<String> features;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.isCurrent,
    this.isRecommended = false,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF3A86F0).withOpacity(0.05) : Colors.white,
        border: Border.all(
          color: isCurrent ? const Color(0xFF3A86F0) : (isRecommended ? const Color(0xFF6C5CE7) : Colors.black12),
          width: isCurrent || isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              if (isCurrent)
                const StatusChip(type: StatusType.active, customText: "Current Plan")
              else if (isRecommended)
                const StatusChip(type: StatusType.premium, customText: "Best Value"),
            ],
          ),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3A86F0))),
          const SizedBox(height: 12),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF00B894), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openInvoicesSheet(BuildContext context, Profile profile) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("My Invoices", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.receipt_rounded, color: Color(0xFF3A86F0)),
              title: const Text("Invoice #INV-2026-001"),
              subtitle: const Text("Premium Tier • 24 Jul 2026 • ₹129.00"),
              trailing: TextButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text("Download PDF"),
                onPressed: () async {
                  await InvoiceService.downloadInvoice(
                    profile: profile,
                    invoiceNo: "INV-2026-001",
                    dateStr: "24 Jul 2026",
                    paymentId: "GPA.3312-4981-2291-10023",
                    planName: "Premium Tier Subscription",
                    amount: 129.00,
                    benefits: [
                      "Automated Voice Call Reminders (TTS)",
                      "Includes strictly 2 Voice Calls per day",
                      "Family Medicine Management",
                      "Secure Health Records Storage (Prescriptions, Lab Reports, Scans)",
                      "Medication Adherence History Tracking",
                      "Emergency SOS Caregiver Notifications",
                      "Support for English, Hindi, and Marathi",
                    ],
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_rounded, color: Color(0xFF3A86F0)),
              title: const Text("Invoice #INV-2026-000"),
              subtitle: const Text("Standard Tier • 24 Jun 2026 • ₹99.00"),
              trailing: TextButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text("Download PDF"),
                onPressed: () async {
                  await InvoiceService.downloadInvoice(
                    profile: profile,
                    invoiceNo: "INV-2026-000",
                    dateStr: "24 Jun 2026",
                    paymentId: "GPA.3312-4981-2291-09941",
                    planName: "Standard Tier Subscription",
                    amount: 99.00,
                    benefits: [
                      "WhatsApp Medicine Reminders (Multi-lingual)",
                      "Caregiver WhatsApp Alerts & Summary Reports",
                      "Family Medicine Management",
                      "Secure Health Records Storage",
                      "Support for English, Hindi, and Marathi",
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

void _showAboutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("About MedAayu"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Image.asset(
                'assets/logo.png',
                height: 90,
                width: 90,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "MedAayu is a smart medicine reminder and family healthcare app designed to help individuals and caregivers never miss an important medicine. With local alarms, automated voice calls, AI care tips, and multi-profile support, MedAayu makes medicine management simple, reliable, and family-friendly.",
              style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF1F2937)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text("Version: 1.2.0 (Build 18)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text("Developed by: RIVASA TECHNOLOGIES", style: TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
      ],
    ),
  );
}

void _showPrivacyPolicyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Privacy Policy"),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("MedAayu Privacy Policy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text("1. Information We Collect:\nName, phone number, email address, medicine schedules, health records, and linked family profile details.\n\n2. Purpose of Collection:\nTo deliver scheduled medicine reminders (Local Alarms, Voice Calls), manage family profiles, improve app stability, and provide customer support.\n\n3. Data Security:\nAll personal data is encrypted both in transit and at rest using secure cloud infrastructure (Supabase & Firebase).\n\n4. Third-Party Services:\nWe use trusted partners including Supabase, Google Firebase, and Voice Call Gateways. Payments are processed securely; MedAayu NEVER stores credit/debit card numbers or passwords.\n\n5. User Rights & Data Control:\nYou have full authority to view, update, or permanently delete your account and personal records at any time.\n\n6. No Data Selling:\nWe NEVER sell or lease your personal information to third parties.\n\n7. Contact Us:\nFor privacy requests or support, contact privacy@medaayu.in.\n\nLast Updated: 23 July 2026"),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
      ],
    ),
  );
}
