import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import 'add_profile_sheet.dart';

class ProfileSelectorSheet extends StatefulWidget {
  final Profile currentProfile;
  const ProfileSelectorSheet({super.key, required this.currentProfile});

  @override
  State<ProfileSelectorSheet> createState() => _ProfileSelectorSheetState();
}

class _ProfileSelectorSheetState extends State<ProfileSelectorSheet> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    final auth = Provider.of<AuthService>(context);

    // Ensure main self profile and all linked profiles are shown
    final List<Profile> allProfiles = [
      if (auth.currentProfile != null && db.linkedParents.every((p) => p.id != auth.currentProfile!.id))
        auth.currentProfile!,
      ...db.linkedParents,
    ];

    // Remove duplicates by id
    final Map<String, Profile> uniqueMap = {};
    for (final p in allProfiles) {
      uniqueMap[p.id] = p;
    }
    final profilesList = uniqueMap.values.toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Switch & Manage Profiles",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Select a profile to switch medicines, schedules, and health records instantly.",
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: profilesList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final p = profilesList[idx];
                final isSelected = p.id == widget.currentProfile.id;

                final roleLabel = p.role == UserRole.self 
                    ? "Self Profile" 
                    : (p.relationship != null && p.relationship!.isNotEmpty ? "${p.relationship}'s Profile" : "Parent Profile");

                final planBadgeColor = p.planTier == PlanTier.premium 
                    ? const Color(0xFF6C5CE7) 
                    : p.planTier == PlanTier.standard 
                        ? const Color(0xFF00B894) 
                        : const Color(0xFF3A86F0);

                final planBadgeText = p.planTier == PlanTier.premium 
                    ? "Premium" 
                    : p.planTier == PlanTier.standard 
                        ? "Standard" 
                        : "Basic";

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF3A86F0).withOpacity(0.08) : Colors.white,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3A86F0) : Colors.black12,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Avatar Photo or Initial
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF3A86F0).withOpacity(0.12),
                        backgroundImage: p.photoUrl != null && File(p.photoUrl!).existsSync()
                            ? FileImage(File(p.photoUrl!)) as ImageProvider
                            : null,
                        child: p.photoUrl == null
                            ? Text(
                                p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'P',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF3A86F0)),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),

                      // Profile Info
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            await auth.switchProfile(p.id);
                            Navigator.pop(context);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      p.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: planBadgeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      planBadgeText,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: planBadgeColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSelected ? "$roleLabel • Active" : roleLabel,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF3A86F0) : Colors.black54,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Action Buttons: Edit & Delete & Select
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.black54),
                            onPressed: () => _openEditProfileSheet(context, p),
                            tooltip: "Edit Profile",
                          ),
                          if (p.role != UserRole.self)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteProfile(context, p),
                              tooltip: "Delete Profile",
                            ),
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.check_circle_rounded, color: Color(0xFF3A86F0), size: 22),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Add Member Button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (dialogCtx) => Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    child: AddProfileSheet(
                      profile: widget.currentProfile,
                      onComplete: () {
                        Navigator.pop(dialogCtx);
                      },
                    ),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: const Color(0xFF3A86F0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text("+ Add Family Member / Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Edit Profile Bottom Sheet
  void _openEditProfileSheet(BuildContext context, Profile p) {
    final nameCtrl = TextEditingController(text: p.fullName);
    final emailCtrl = TextEditingController(text: p.email ?? '');
    final phoneCtrl = TextEditingController(text: p.phone);
    final relCtrl = TextEditingController(text: p.relationship ?? (p.role == UserRole.self ? 'Self' : 'Parent'));

    String selectedGender = p.gender ?? 'Male';
    String selectedBlood = p.bloodGroup ?? 'O+';
    String? currentPhotoPath = p.photoUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (editCtx) {
        return StatefulBuilder(
          builder: (context, setEditState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Edit Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(editCtx)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Photo Picker Avatar
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFF3A86F0).withOpacity(0.1),
                            backgroundImage: currentPhotoPath != null && File(currentPhotoPath!).existsSync()
                                ? FileImage(File(currentPhotoPath!)) as ImageProvider
                                : null,
                            child: currentPhotoPath == null
                                ? Text(p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3A86F0)))
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                if (picked != null) {
                                  setEditState(() {
                                    currentPhotoPath = picked.path;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Color(0xFF3A86F0), shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Prefix Dropdown
                    DropdownButtonFormField<String>(
                      value: ['Mr', 'Mrs', 'Ms', 'Dr', 'Prof'].contains(p.prefix) ? p.prefix : 'Mr',
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15),
                      decoration: _inputDeco("Prefix (Mr/Mrs/Ms/Dr)"),
                      items: ['Mr', 'Mrs', 'Ms', 'Dr', 'Prof']
                          .map((px) => DropdownMenuItem(
                                value: px,
                                child: Text(px, style: const TextStyle(color: Color(0xFF1F2937))),
                              ))
                          .toList(),
                      onChanged: (v) { if (v != null) setEditState(() {}); },
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameCtrl, style: const TextStyle(color: Color(0xFF1F2937)), decoration: _inputDeco("Full Name")),
                    const SizedBox(height: 12),
                    TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Color(0xFF1F2937)), decoration: _inputDeco("Email Address")),
                    const SizedBox(height: 12),
                    TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Color(0xFF1F2937)), decoration: _inputDeco("Mobile Number")),
                    const SizedBox(height: 12),
                    TextField(controller: relCtrl, style: const TextStyle(color: Color(0xFF1F2937)), decoration: _inputDeco("Relationship (Self / Mother / Father / Spouse / Child)")),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: ['Male', 'Female', 'Other'].contains(selectedGender) ? selectedGender : 'Male',
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15),
                            decoration: _inputDeco("Gender"),
                            items: ['Male', 'Female', 'Other']
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g, style: const TextStyle(color: Color(0xFF1F2937))),
                                    ))
                                .toList(),
                            onChanged: (v) { if (v != null) setEditState(() => selectedGender = v); },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(selectedBlood) ? selectedBlood : 'O+',
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15),
                            decoration: _inputDeco("Blood Group"),
                            items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                                .map((b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(b, style: const TextStyle(color: Color(0xFF1F2937))),
                                    ))
                                .toList(),
                            onChanged: (v) { if (v != null) setEditState(() => selectedBlood = v); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () async {
                        final updated = p.copyWith(
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          relationship: relCtrl.text.trim(),
                          gender: selectedGender,
                          bloodGroup: selectedBlood,
                          photoUrl: currentPhotoPath,
                        );

                        final db = Provider.of<DbService>(context, listen: false);
                        await db.updateProfileDetails(updated);

                        final auth = Provider.of<AuthService>(context, listen: false);
                        
                        // Persist photo locally if a new photo was picked
                        if (currentPhotoPath != null && currentPhotoPath != p.photoUrl) {
                          await auth.saveProfilePhotoLocally(p.id, currentPhotoPath!);
                        }
                        
                        if (auth.currentProfile?.id == p.id) {
                          await auth.loadProfile();
                        }

                        Navigator.pop(editCtx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Profile updated successfully!")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3A86F0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  // Delete Profile Confirmation
  void _confirmDeleteProfile(BuildContext context, Profile p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Profile"),
        content: Text("Are you sure you want to remove ${p.fullName}'s profile and medicine schedules?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final db = Provider.of<DbService>(context, listen: false);
              final auth = Provider.of<AuthService>(context, listen: false);

              await db.deleteProfile(p.id);

              if (widget.currentProfile.id == p.id) {
                final selfProf = db.linkedParents.firstWhere(
                  (element) => element.role == UserRole.self,
                  orElse: () => auth.currentProfile!,
                );
                await auth.switchProfile(selfProf.id);
              }

              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile deleted successfully.")),
              );
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
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
