import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicine.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/billing_service.dart';
import '../services/ocr_service.dart';
import '../services/translation.dart';
import '../theme/design_system.dart';
import 'records_view.dart';
import 'profile_view.dart';
import 'add_profile_sheet.dart';
import 'profile_selector_sheet.dart';
import '../services/invoice_service.dart';

String _formatTimeString(String rawTime) {
  if (rawTime.isEmpty) return "08:00 AM";
  final parts = rawTime.split(":");
  int hour = int.tryParse(parts[0]) ?? 8;
  int min = int.tryParse(parts[1]) ?? 0;
  final ampm = hour >= 12 ? "PM" : "AM";
  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  return "${displayHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $ampm";
}

void _openBillingSheet(BuildContext context, BillingService billing) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("📞 Voice Calling Feature", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(height: 16),
            Text("Automated Voice Call Reminders are active as the standard feature for your account. Calls will ring on your registered mobile number for every scheduled medicine.", style: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.7))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86F0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Got It"),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _currentTab = 0;
  String? _lastLoadedProfileId;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final profile = auth.currentProfile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final db = Provider.of<DbService>(context);

    // Automatically reload medicines if active profile switches
    if (_lastLoadedProfileId != profile.id) {
      _lastLoadedProfileId = profile.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        db.loadMedicines(profile.id, profile);
        db.loadIntakeLogs(profile.id);
        db.loadReminderLogs(profile.id);
        db.loadRecords(profile.id);
        if (profile.role == UserRole.self) {
          db.loadLinkedParents();
        }
      });
    }

    final bool needsSetup = profile.role == UserRole.self && profile.age == null && db.linkedParents.isEmpty;

    if (needsSetup) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: _FirstTimeSetupWidget(
          profile: profile,
          onComplete: () {
            setState(() {});
          },
        ),
      );
    }

    final List<Widget> tabs = [
      _HomeTab(profile: profile),
      _MedicationsTab(profile: profile),
      RecordsView(profile: profile),
      ProfileView(profile: profile),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: tabs[_currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (tab) {
          setState(() {
            _currentTab = tab;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.medication_rounded), label: 'Medicines'),
          NavigationDestination(icon: Icon(Icons.folder_shared_rounded), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ================= HOME TAB =================
class _HomeTab extends StatefulWidget {
  final Profile profile;
  const _HomeTab({required this.profile});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  DateTime _selectedDate = DateTime.now();
  bool _showSuccessAnim = false;
  String? _lastTakenMedName;
  late ScrollController _scrollController;
  String _scheduleFilter = 'all'; // 'all', 'completed', 'remaining'

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: 30 * 60.0 - 120.0);
    
    // Background refresh for AI care tips once per day
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRefreshTips();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAndRefreshTips() async {
    if (!mounted) return;
    final db = Provider.of<DbService>(context, listen: false);
    final tipsUpdatedAt = widget.profile.careTipsUpdatedAt;
    final now = DateTime.now();
    
    if (tipsUpdatedAt == null || 
        tipsUpdatedAt.year != now.year || 
        tipsUpdatedAt.month != now.month || 
        tipsUpdatedAt.day != now.day) {
      try {
        await db.triggerCareTipsRegen(widget.profile.id);
        if (!mounted) return;
        final auth = Provider.of<AuthService>(context, listen: false);
        await auth.switchProfile(widget.profile.id);
      } catch (e) {
        debugPrint("Background AI tips refresh failed: $e");
      }
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return "Mon";
      case 2: return "Tue";
      case 3: return "Wed";
      case 4: return "Thu";
      case 5: return "Fri";
      case 6: return "Sat";
      case 7: return "Sun";
      default: return "";
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return "Jan";
      case 2: return "Feb";
      case 3: return "Mar";
      case 4: return "Apr";
      case 5: return "May";
      case 6: return "Jun";
      case 7: return "Jul";
      case 8: return "Aug";
      case 9: return "Sep";
      case 10: return "Oct";
      case 11: return "Nov";
      case 12: return "Dec";
      default: return "";
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getGreetingText(String name) {
    final hour = DateTime.now().hour;
    final lang = widget.profile.language;
    
    String greetingKey;
    if (hour >= 5 && hour < 12) {
      greetingKey = 'good_morning';
    } else if (hour >= 12 && hour < 17) {
      greetingKey = 'good_afternoon';
    } else if (hour >= 17 && hour < 21) {
      greetingKey = 'good_evening';
    } else {
      greetingKey = 'good_night';
    }
    
    final translatedGreeting = TranslationService.getTranslation(lang, greetingKey);
    return "$translatedGreeting, $name";
  }

  String _getContextGreetingTitle() {
    final hour = DateTime.now().hour;
    String prefix;
    if (hour >= 5 && hour < 12) {
      prefix = "🌅 Good Morning";
    } else if (hour >= 12 && hour < 17) {
      prefix = "☀️ Good Afternoon";
    } else if (hour >= 17 && hour < 21) {
      prefix = "🌆 Good Evening";
    } else {
      prefix = "🌙 Good Night";
    }
    return "$prefix";
  }

  String _formatTimeString(String rawTime) {
    if (rawTime.isEmpty) return "08:00 AM";
    final parts = rawTime.split(":");
    int hour = int.tryParse(parts[0]) ?? 8;
    int min = int.tryParse(parts[1]) ?? 0;
    final ampm = hour >= 12 ? "PM" : "AM";
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return "${displayHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $ampm";
  }

  void _triggerSuccessAnimation(String medName) {
    setState(() {
      _lastTakenMedName = medName;
      _showSuccessAnim = true;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _showSuccessAnim = false;
        });
      }
    });
  }

  void _showDayDetailsDialog(DateTime day, List<Map<String, dynamic>> intakes, List<Medicine> scheduled) {
    final takenIds = intakes.map((log) => log['medicine_id']).toSet();
    
    final completed = scheduled.where((med) => takenIds.contains(med.id)).toList();
    final missed = scheduled.where((med) => !takenIds.contains(med.id)).toList();
    
    final dayName = _getDayName(day.weekday);
    final dateStr = "${day.day} ${_getMonthName(day.month)}";
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "$dayName Details ($dateStr)",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (completed.isNotEmpty) ...[
                  const Text("Completed:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 14)),
                  const SizedBox(height: 8),
                  ...completed.map((med) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 16),
                        const SizedBox(width: 8),
                        Text(med.name, style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
                if (missed.isNotEmpty && !day.isAfter(DateTime.now())) ...[
                  const Text("Missed / Pending:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...missed.map((med) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(med.name, style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937))),
                      ],
                    ),
                  )),
                ],
                if (completed.isEmpty && (missed.isEmpty || day.isAfter(DateTime.now())))
                  const Text(
                    "No medicines scheduled or taken on this day.",
                    style: TextStyle(color: Colors.black45, fontSize: 13),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close", style: TextStyle(color: Color(0xFF3A86F0))),
            )
          ],
        );
      },
    );
  }

  String getCountdownStr(Medicine? nextMed) {
    if (nextMed == null) return "";
    final now = DateTime.now();
    final parts = nextMed.doseTime.split(":");
    final hour = int.tryParse(parts[0]) ?? 8;
    final min = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    var nextTime = DateTime(now.year, now.month, now.day, hour, min);
    
    if (nextTime.isBefore(now)) {
      nextTime = nextTime.add(const Duration(days: 1));
    }
    
    final diff = nextTime.difference(now);
    final hrs = diff.inHours;
    final mins = diff.inMinutes.remainder(60);
    
    if (hrs > 0) {
      return "⏰ In $hrs hr $mins min";
    } else if (mins > 0) {
      return "⏰ In $mins min";
    } else {
      return "⏰ Due now";
    }
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color valueColor,
    IconData icon,
    String filterVal, {
    bool isInfo = false,
  }) {
    final isSelected = _scheduleFilter == filterVal;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isInfo) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Color(0xFF6C5CE7)),
                    SizedBox(width: 8),
                    Text("Medicine Score"),
                  ],
                ),
                content: const Text("Percentage of scheduled medicines taken on time."),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Got it")),
                ],
              ),
            );
            return;
          }
          setState(() {
            _scheduleFilter = filterVal;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Filtered by $label medicines")),
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? valueColor.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: valueColor.withOpacity(0.3), width: 1.5) : null,
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: valueColor),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isInfo) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.info_outline_rounded, size: 10, color: Colors.black45),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 32, color: Colors.black.withOpacity(0.08));
  }

  Widget _buildDashboardSummaryCard(int total, int taken, int missed, double adherencePercent, Medicine? nextMed) {
    final remaining = total - taken;
    final countdownStr = getCountdownStr(nextMed);
    final scoreStr = "${adherencePercent.isNaN ? 0 : (adherencePercent * 100).round()}%";
    
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF3A86F0), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "TODAY'S SUMMARY".toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (_scheduleFilter != 'all')
                GestureDetector(
                  onTap: () => setState(() => _scheduleFilter = 'all'),
                  child: const Text("Show All", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3A86F0))),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem("Scheduled", "$total", Colors.black87, Icons.event_note_rounded, 'all'),
              _buildVerticalDivider(),
              _buildStatItem("Completed", "$taken", const Color(0xFF00B894), Icons.check_circle_rounded, 'completed'),
              _buildVerticalDivider(),
              _buildStatItem("Remaining", "$remaining", const Color(0xFF3A86F0), Icons.hourglass_bottom_rounded, 'remaining'),
              _buildVerticalDivider(),
              _buildStatItem("Missed", "$missed", const Color(0xFFFF7675), Icons.cancel_rounded, 'remaining'),
              _buildVerticalDivider(),
              _buildStatItem("Medicine Score", scoreStr, const Color(0xFF6C5CE7), Icons.insights_rounded, 'all', isInfo: true),
            ],
          ),
          if (nextMed != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Next Medicine: ${nextMed.name} scheduled for ${_formatTimeString(nextMed.doseTime)}")),
                );
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    const Icon(Icons.next_plan_rounded, size: 16, color: Color(0xFF3A86F0)),
                    const SizedBox(width: 8),
                    Text(
                      countdownStr,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3A86F0)),
                    ),
                    const SizedBox(width: 8),
                    const Text("•", style: TextStyle(color: Colors.black26)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${nextMed.name} (${_formatTimeString(nextMed.doseTime)})",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);
    final auth = Provider.of<AuthService>(context);

    // List of 30 days past and 365 days future (total 395 days)
    final days = List.generate(395, (i) => DateTime.now().subtract(const Duration(days: 30)).add(Duration(days: i)));

    // Calculate dynamic taken progress based on selected date
    final selectedDateIntakes = db.intakeLogs.where((log) {
      final takenAt = DateTime.tryParse(log['taken_at'] ?? '') ?? DateTime.now();
      return _isSameDay(takenAt, _selectedDate);
    }).toList();

    // Filter active medicines for the selected date
    final activeMedicinesForSelectedDate = db.medicines.where((med) {
      final bool started = med.startDate.isBefore(_selectedDate) || _isSameDay(med.startDate, _selectedDate);
      final bool notEnded = med.endDate == null || med.endDate!.isAfter(_selectedDate) || _isSameDay(med.endDate!, _selectedDate);
      return started && notEnded;
    }).toList();
    
    final int takenCount = selectedDateIntakes.map((log) => log['medicine_id']).toSet().length;
    final int totalCount = activeMedicinesForSelectedDate.length;
    final double progressPercent = totalCount > 0 ? (takenCount / totalCount).clamp(0.0, 1.0) : 0.0;

    // Find next medicine countdown for the selected date
    Medicine? nextMed;
    Duration? timeDiff;
    final now = DateTime.now();
    final isSelectedToday = _isSameDay(_selectedDate, now);
    final currentMinutes = now.hour * 60 + now.minute;

    if (isSelectedToday) {
      for (final med in activeMedicinesForSelectedDate) {
        final parts = med.doseTime.split(":");
        final medHour = int.tryParse(parts[0]) ?? 0;
        final medMin = int.tryParse(parts[1]) ?? 0;
        final medMinutes = medHour * 60 + medMin;

        final isAlreadyTaken = selectedDateIntakes.any((log) => log['medicine_id'] == med.id);

        if (medMinutes > currentMinutes && !isAlreadyTaken) {
          nextMed = med;
          timeDiff = Duration(minutes: medMinutes - currentMinutes);
          break;
        }
      }
      
      // Fallback to first untaken medicine of the day if all are in past
      if (nextMed == null && activeMedicinesForSelectedDate.isNotEmpty) {
        for (final med in activeMedicinesForSelectedDate) {
          final isAlreadyTaken = selectedDateIntakes.any((log) => log['medicine_id'] == med.id);
          if (!isAlreadyTaken) {
            nextMed = med;
            final parts = nextMed.doseTime.split(":");
            final medHour = int.tryParse(parts[0]) ?? 0;
            final medMin = int.tryParse(parts[1]) ?? 0;
            final medMinutes = medHour * 60 + medMin;
            timeDiff = Duration(minutes: (medMinutes > currentMinutes) ? (medMinutes - currentMinutes) : (1440 - currentMinutes + medMinutes));
            break;
          }
        }
      }
    } else {
      // For other days, nextMed is the first untaken medicine on that day
      for (final med in activeMedicinesForSelectedDate) {
        final isAlreadyTaken = selectedDateIntakes.any((log) => log['medicine_id'] == med.id);
        if (!isAlreadyTaken) {
          nextMed = med;
          break;
        }
      }
    }

    int missedCount = 0;
    if (isSelectedToday) {
      for (final med in activeMedicinesForSelectedDate) {
        final isTaken = selectedDateIntakes.any((log) => log['medicine_id'] == med.id);
        if (!isTaken) {
          final parts = med.doseTime.split(":");
          final hour = int.tryParse(parts[0]) ?? 8;
          final min = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final schedTime = DateTime(now.year, now.month, now.day, hour, min);
          if (schedTime.isBefore(now)) {
            missedCount++;
          }
        }
      }
    } else if (_selectedDate.isBefore(now)) {
      for (final med in activeMedicinesForSelectedDate) {
        final isTaken = selectedDateIntakes.any((log) => log['medicine_id'] == med.id);
        if (!isTaken) {
          missedCount++;
        }
      }
    }

    final filteredMedicines = activeMedicinesForSelectedDate.where((med) {
      final isTaken = selectedDateIntakes.any((log) => log['medicine_id'] == med.id);
      if (_scheduleFilter == 'completed') {
        return isTaken;
      } else if (_scheduleFilter == 'remaining') {
        return !isTaken;
      }
      return true; // 'all'
    }).toList();

    void _openProfileSelector(BuildContext context, Profile profile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => ProfileSelectorSheet(currentProfile: profile),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 6, bottom: 6),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        title: GestureDetector(
          onTap: () => _openProfileSelector(context, widget.profile),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getContextGreetingTitle(),
                      style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.profile.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          widget.profile.role == UserRole.self 
                              ? "Self Profile" 
                              : (widget.profile.relationship != null && widget.profile.relationship!.isNotEmpty ? "${widget.profile.relationship}'s Profile" : "Parent Profile"),
                          style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (widget.profile.planTier == PlanTier.premium ? const Color(0xFF6C5CE7) : widget.profile.planTier == PlanTier.standard ? const Color(0xFF00B894) : const Color(0xFF3A86F0)).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.profile.planTier == PlanTier.premium ? "Premium" : widget.profile.planTier == PlanTier.standard ? "Standard" : "Basic",
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: widget.profile.planTier == PlanTier.premium ? const Color(0xFF6C5CE7) : widget.profile.planTier == PlanTier.standard ? const Color(0xFF00B894) : const Color(0xFF3A86F0)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black.withOpacity(0.5), size: 14),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          GestureDetector(
            onTap: () => _openProfileSelector(context, widget.profile),
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.profile.planTier == PlanTier.premium 
                      ? const Color(0xFF6C5CE7) 
                      : widget.profile.planTier == PlanTier.standard 
                          ? const Color(0xFF00B894) 
                          : const Color(0xFF3A86F0),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEBF3FF),
                backgroundImage: widget.profile.photoUrl != null && File(widget.profile.photoUrl!).existsSync()
                    ? FileImage(File(widget.profile.photoUrl!)) as ImageProvider
                    : null,
                child: widget.profile.photoUrl == null
                    ? Text(
                        widget.profile.fullName.isNotEmpty
                            ? widget.profile.fullName.substring(0, 1).toUpperCase()
                            : "U",
                        style: const TextStyle(color: Color(0xFF3A86F0), fontWeight: FontWeight.bold, fontSize: 13),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: db.isLoading
          ? const SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  SkeletonCard(height: 80),
                  SizedBox(height: 16),
                  SkeletonCard(height: 140),
                  SizedBox(height: 16),
                  SkeletonCard(height: 100),
                  SizedBox(height: 16),
                  SkeletonCard(height: 180),
                ],
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    await db.loadMedicines(widget.profile.id, widget.profile);
                    await db.loadIntakeLogs(widget.profile.id);
                    await db.triggerCareTipsRegen(widget.profile.id);
                    await auth.switchProfile(widget.profile.id);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Calendar Strip
                      Container(
                        height: 80,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: ListView.builder(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          itemBuilder: (context, idx) {
                            final day = days[idx];
                            final dayName = _getDayName(day.weekday);
                            final isSelected = _isSameDay(day, _selectedDate);
                            final isToday = _isSameDay(day, DateTime.now());
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDate = day;
                                  _scheduleFilter = 'all'; // reset filter
                                });
                              },
                              child: Container(
                                width: 52,
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF3A86F0) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                  border: Border.all(
                                    color: isSelected 
                                        ? const Color(0xFF3A86F0) 
                                        : isToday 
                                            ? const Color(0xFF3A86F0).withOpacity(0.3) 
                                            : Colors.black.withOpacity(0.05),
                                    width: isToday ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      dayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.black38,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      day.day.toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Today's summary card
                      _buildDashboardSummaryCard(totalCount, takenCount, missedCount, progressPercent, nextMed),

                      // 1. Next Reminder centerpiece banner
                      _buildHeroNextMedicineCard(nextMed, timeDiff, db),
                      const SizedBox(height: 24),

                      // 2. Today's Medicines list
                      Text(
                        _isSameDay(_selectedDate, DateTime.now()) 
                            ? TranslationService.getTranslation(widget.profile.language, 'todays_schedule')
                            : "${TranslationService.getTranslation(widget.profile.language, 'schedule_for')}: ${_selectedDate.day} ${_getMonthName(_selectedDate.month)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 12),
                      if (filteredMedicines.isEmpty)
                        _buildEmptyMedicinesCard(context)
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredMedicines.length,
                          itemBuilder: (context, idx) {
                            final med = filteredMedicines[idx];
                            final isTaken = selectedDateIntakes.any((log) => log['medicine_id'] == med.id);
                            final medReminders = db.logs.where((log) =>
                                log.medicineId == med.id &&
                                log.sentAt != null &&
                                _isSameDay(log.sentAt!, _selectedDate)
                            ).toList();
                            final bool reminderDone = medReminders.isNotEmpty;
                            final String? reminderChannel = reminderDone ? medReminders.first.channel : null;

                            return MedicineTile(
                              medicine: med,
                              isTaken: isTaken,
                              userLanguage: widget.profile.language,
                              reminderDone: reminderDone,
                              reminderChannel: reminderChannel,
                              onTap: () async {
                                final ok = await db.toggleMedicineIntake(med.id, widget.profile.id, _selectedDate);
                                if (ok) {
                                  if (!isTaken) {
                                    DesignSystem.showSuccessOverlay(context, "Medicine Taken");
                                  }
                                  _triggerSuccessAnimation(med.name);
                                }
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 24),

                      // 3. Daily Progress progress bar
                      _buildDailyProgressCard(takenCount, totalCount, progressPercent),
                      const SizedBox(height: 24),

                      // 4. Today's Timeline view
                      _buildTimeline(activeMedicinesForSelectedDate),
                      const SizedBox(height: 24),

                      // 5. Weekly Adherence indicators
                      _buildWeeklyAdherenceChart(db),
                      const SizedBox(height: 24),

                      // 6. AI Health Tips
                      _buildAiTipsCard(context, db),
                      const SizedBox(height: 24),

                      // Safety Status
                      if (widget.profile.role == UserRole.self && db.linkedParents.isNotEmpty) ...[
                        Text(
                          TranslationService.getTranslation(widget.profile.language, 'linked_elder_safety'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 12),
                        ...db.linkedParents.map((parent) => _buildElderSafetyCard(context, parent, db)),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
                if (_showSuccessAnim) _buildSuccessAnimationOverlay(),
              ],
            ),
    );
  }

  Widget _buildHeroNextMedicineCard(Medicine? nextMed, Duration? timeDiff, DbService db) {
    if (nextMed == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3A86F0), Color(0xFF5A9CF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            "🎉 ${TranslationService.getTranslation(widget.profile.language, 'no_scheduled_medicines')}",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return ReminderBanner(
      medicine: nextMed,
      userLanguage: widget.profile.language,
      onTakeNow: () {
        db.markMedicineTaken(nextMed.id, widget.profile.id, date: _selectedDate);
        DesignSystem.showSuccessOverlay(context, "Medicine Taken");
        _triggerSuccessAnimation(nextMed.name);
      },
    );
  }

  Widget _buildDailyProgressCard(int taken, int total, double percent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Daily Progress",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
              ),
              Text(
                "✅ $taken of $total medicines taken",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2E7D32)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: const Color(0xFFEBF3FF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyAdherenceChart(DbService db) {
    final last7Days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Weekly Adherence",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
              ),
              Text(
                "Hold for details".toUpperCase(),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: last7Days.map((day) {
              final dayName = _getDayName(day.weekday).substring(0, 1);
              final isFuture = day.isAfter(DateTime.now()) && !_isSameDay(day, DateTime.now());
              
              // Count intakes for this day
              final dayIntakes = db.intakeLogs.where((log) {
                final takenAt = DateTime.tryParse(log['taken_at'] ?? '') ?? DateTime.now();
                return _isSameDay(takenAt, day);
              }).toList();
              
              // Filter active medicines for that day
              final activeMeds = db.medicines.where((med) {
                final bool started = med.startDate.isBefore(day) || _isSameDay(med.startDate, day);
                final bool notEnded = med.endDate == null || med.endDate!.isAfter(day) || _isSameDay(med.endDate!, day);
                return started && notEnded;
              }).toList();

              final int takenOnDay = dayIntakes.map((log) => log['medicine_id']).toSet().length;
              final int totalOnDay = activeMeds.length;
              
              Color dayBgColor = Colors.transparent;
              Border? dayBorder = Border.all(color: Colors.black12, width: 1);
              Widget dayChild;
              String adherenceText = "—";
              Color adherenceColor = Colors.black26;

              if (isFuture) {
                dayChild = const Text("—", style: TextStyle(fontSize: 14, color: Colors.black26, fontWeight: FontWeight.bold));
              } else if (totalOnDay == 0) {
                dayChild = const Text("—", style: TextStyle(fontSize: 14, color: Colors.black26, fontWeight: FontWeight.bold));
              } else if (takenOnDay >= totalOnDay) {
                dayBgColor = const Color(0xFF00B894);
                dayBorder = null;
                dayChild = const Icon(Icons.check_rounded, size: 18, color: Colors.white);
                adherenceText = "🟢 Taken";
                adherenceColor = const Color(0xFF00B894);
              } else if (takenOnDay > 0) {
                dayBgColor = const Color(0xFFFDCB6E);
                dayBorder = null;
                dayChild = Text(
                  "$takenOnDay/$totalOnDay",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                );
                adherenceText = "🟡 Partial";
                adherenceColor = const Color(0xFFE17055);
              } else {
                dayBgColor = const Color(0xFFFF7675);
                dayBorder = null;
                dayChild = const Icon(Icons.close_rounded, size: 18, color: Colors.white);
                adherenceText = "🔴 Missed";
                adherenceColor = const Color(0xFFD63031);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = day;
                    _scheduleFilter = 'all';
                  });
                },
                onLongPress: () {
                  _showDayDetailsDialog(day, dayIntakes, activeMeds);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: dayBgColor,
                          shape: BoxShape.circle,
                          border: dayBorder,
                        ),
                        child: dayChild,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        adherenceText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: adherenceColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTipsCard(BuildContext context, DbService db) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final tips = widget.profile.careTips;
    final isLoading = db.isLoading;

    final List<Map<String, String>> parsedTips = [];
    if (tips != null && tips.isNotEmpty) {
      final lines = tips.split('\n');
      for (final line in lines) {
        final cleanLine = line.trim();
        if (cleanLine.isEmpty) continue;
        
        final regExp = RegExp(r'^(\d+)\.\s*([^:-]+)[:\-]\s*(.*)$');
        final match = regExp.firstMatch(cleanLine);
        if (match != null) {
          parsedTips.add({
            'index': match.group(1)!,
            'title': match.group(2)!.trim(),
            'description': match.group(3)!.trim(),
          });
        } else {
          final genericRegExp = RegExp(r'^(\d+)\.\s*(.*)$');
          final genericMatch = genericRegExp.firstMatch(cleanLine);
          if (genericMatch != null) {
            parsedTips.add({
              'index': genericMatch.group(1)!,
              'title': 'AI Tip #${genericMatch.group(1)}',
              'description': genericMatch.group(2)!.trim(),
            });
          }
        }
      }
    }

    String getTipTitle(String index, String rawTitle, String description) {
      final t = (rawTitle + " " + description).toLowerCase();
      if (t.contains('hydration') || t.contains('water') || t.contains('drink') || t.contains('पानी')) {
        return "💧 Stay Hydrated";
      }
      if (t.contains('mobility') || t.contains('walk') || t.contains('stretching') || t.contains('सैर') || t.contains('चलणे')) {
        return "🚶 Take a Daily Walk";
      }
      if (t.contains('diet') || t.contains('nutrition') || t.contains('food') || t.contains('खाना') || t.contains('जेवण') || t.contains('balanced')) {
        return "🥗 Eat a Balanced Diet";
      }
      if (t.contains('sleep') || t.contains('rest') || t.contains('sleep') || t.contains('नींद')) {
        return "😴 Maintain Healthy Sleep";
      }
      if (t.contains('blood pressure') || t.contains('bp') || t.contains('heart') || t.contains('रक्तचाप')) {
        return "❤️ Monitor Blood Pressure";
      }
      if (t.contains('sugar') || t.contains('glucose') || t.contains('diabetes') || t.contains('मधुमेह')) {
        return "🩸 Check Blood Sugar";
      }
      if (t.contains('medicine') || t.contains('dose') || t.contains('pill') || t.contains('दवा')) {
        return "💊 Take Meds on Time";
      }
      return rawTitle.isNotEmpty && !rawTitle.toLowerCase().contains('ai tip') ? rawTitle : "💡 Care Recommendation #$index";
    }

    IconData getTipIcon(String title) {
      final t = title.toLowerCase();
      if (t.contains('hydration') || t.contains('water') || t.contains('drink') || t.contains('पानी')) {
        return Icons.water_drop_rounded;
      }
      if (t.contains('mobility') || t.contains('walk') || t.contains('stretching') || t.contains('सैर') || t.contains('चलणे')) {
        return Icons.directions_walk_rounded;
      }
      if (t.contains('diet') || t.contains('nutrition') || t.contains('food') || t.contains('खाना') || t.contains('जेवण')) {
        return Icons.restaurant_rounded;
      }
      if (t.contains('fall') || t.contains('safety') || t.contains('बचाव') || t.contains('सुरक्षा')) {
        return Icons.gpp_good_rounded;
      }
      return Icons.lightbulb_rounded;
    }
    
    Color getTipColor(String title) {
      final t = title.toLowerCase();
      if (t.contains('hydration') || t.contains('water') || t.contains('drink') || t.contains('पानी')) {
        return Colors.blue;
      }
      if (t.contains('mobility') || t.contains('walk') || t.contains('stretching') || t.contains('सैर') || t.contains('चलणे')) {
        return Colors.orange;
      }
      if (t.contains('diet') || t.contains('nutrition') || t.contains('food') || t.contains('खाना') || t.contains('जेवण')) {
        return Colors.green;
      }
      return const Color(0xFF3A86F0);
    }

    String getFormattedUpdateStr() {
      final dt = widget.profile.careTipsUpdatedAt;
      if (dt == null) return "Last updated: Never";
      
      final now = DateTime.now();
      String timeStr = _formatTimeString("${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}");
      
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "Updated Today • $timeStr";
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.subtract(const Duration(days: 1)).day) {
        return "Last updated Yesterday • $timeStr";
      } else {
        return "Last updated ${dt.day}/${dt.month} • $timeStr";
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF3A86F0), size: 24),
            const SizedBox(width: 8),
            Text(
              TranslationService.getTranslation(widget.profile.language, 'ai_care_tips'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3A86F0)),
              onPressed: isLoading ? null : () async {
                await db.triggerCareTipsRegen(widget.profile.id);
                await auth.switchProfile(widget.profile.id);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.profile.careTipsUpdatedAt != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              getFormattedUpdateStr(),
              style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
            ),
          ),
        ],
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                SkeletonCard(height: 80),
                SizedBox(height: 12),
                SkeletonCard(height: 80),
              ],
            ),
          )
        else if (parsedTips.isEmpty) ...[
          EmptyStateWidget(
            title: "No health tips yet",
            subtitle: db.medicines.isEmpty 
                ? "Add medicines to receive personalized AI health tips."
                : "Tips are ready to be generated for your medicines.",
            onActionPressed: () async {
              if (db.medicines.isEmpty) {
                // Switch tab or trigger add medicine sheet
              } else {
                await db.triggerCareTipsRegen(widget.profile.id);
                await auth.switchProfile(widget.profile.id);
              }
            },
            buttonText: db.medicines.isEmpty ? "Add Medicine" : "Generate Tips",
          ),
        ] else
          ...parsedTips.map((tip) {
            final parsedTitle = getTipTitle(tip['index']!, tip['title']!, tip['description']!);
            return ExpandableTipCard(
              title: parsedTitle,
              description: tip['description']!,
              icon: getTipIcon(parsedTitle),
              iconColor: getTipColor(parsedTitle),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildTimeline(List<Medicine> medicines) {
    if (medicines.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Timeline",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 16),
          ...medicines.map((med) {
            final isLast = medicines.last == med;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A86F0).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatTimeString(med.doseTime),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF3A86F0)),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 32,
                        color: Colors.black12,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        TranslationService.getTranslation(widget.profile.language, med.foodInstruction),
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyMedicinesCard(BuildContext context) {
    String msg = TranslationService.getTranslation(widget.profile.language, 'no_scheduled_medicines');
    if (_scheduleFilter == 'completed') {
      msg = "No completed medicines for today.";
    } else if (_scheduleFilter == 'remaining') {
      msg = "No remaining medicines for today. All done!";
    }
    
    return EmptyStateWidget(
      title: "🎉 You're all set!",
      subtitle: _scheduleFilter == 'all'
          ? "Add your first medicine to start receiving reminders."
          : msg,
      onActionPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) {
            return _AddMedicineSheet(profile: widget.profile);
          },
        );
      },
      buttonText: "Add Medicine",
    );
  }

  Widget _buildElderSafetyCard(BuildContext context, Profile parent, DbService db) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_rounded, color: Colors.redAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parent.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(
                  "SOS Safety Status: ACTIVE",
                  style: TextStyle(fontSize: 12, color: Colors.redAccent.withOpacity(0.8), fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).switchProfile(parent.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F2937),
              side: BorderSide(color: Colors.black.withOpacity(0.1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text("Configure", style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildSuccessAnimationOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _showSuccessAnim ? 1.2 : 0.5,
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 70),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Well Done!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(height: 8),
              Text(
                _lastTakenMedName != null ? "Took $_lastTakenMedName" : "Medicine logged successfully",
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileSwitcherBottomSheet(BuildContext context, AuthService auth, DbService db) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final caregiverNameText = auth.caregiverName ?? "Caregiver Profile";
        final isCaregiverActive = widget.profile.role == UserRole.self;
        
        final caregiverProfile = Profile(
          id: widget.profile.role == UserRole.parent ? (widget.profile.ownerId ?? '') : widget.profile.id,
          ownerId: null,
          role: UserRole.self,
          fullName: caregiverNameText,
          phone: auth.phoneNumber ?? '',
          planTier: widget.profile.planTier,
          language: 'english',
          sosAction: 'notify',
        );

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // M3 Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2.25),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                ),
              ),
              const Text(
                "Switch Profile",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Profiles List
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Caregiver profile tile
                      ProfileTile(
                        profile: caregiverProfile,
                        isSelected: isCaregiverActive,
                        onTap: () async {
                          Navigator.pop(context);
                          final targetId = widget.profile.role == UserRole.parent 
                              ? widget.profile.ownerId 
                              : widget.profile.id;
                          if (targetId != null) {
                            await auth.switchProfile(targetId);
                          }
                        },
                      ),

                      // Parent profiles
                      ...db.linkedParents.map((parent) {
                        final isParentActive = widget.profile.id == parent.id;
                        return ProfileTile(
                          profile: parent,
                          isSelected: isParentActive,
                          onTap: () async {
                            Navigator.pop(context);
                            await auth.switchProfile(parent.id);
                          },
                        );
                      }),

                      // Add Profile Card
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFFEBF3FF), shape: BoxShape.circle),
                            child: const Icon(Icons.add_rounded, color: Color(0xFF3A86F0), size: 20),
                          ),
                          title: const Text(
                            "Add Profile",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) => AddProfileDialog(currentProfile: widget.profile),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: "Upgrade / Renew Plan",
                icon: Icons.star_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  _openBillingSheet(context, Provider.of<BillingService>(context, listen: false));
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

// ================= MEDICATIONS TAB =================
class _MedicationsTab extends StatefulWidget {
  final Profile profile;
  const _MedicationsTab({required this.profile});

  @override
  State<_MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends State<_MedicationsTab> {
  void _openAddMedicineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _AddMedicineSheet(profile: widget.profile);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Active Medications", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF3A86F0), size: 28),
            onPressed: () => _openAddMedicineSheet(context),
          )
        ],
      ),
      body: db.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3A86F0)))
          : db.medicines.isEmpty
              ? _buildEmptyView()
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: db.medicines.length,
                  itemBuilder: (context, idx) {
                    final med = db.medicines[idx];
                    return _buildMedCard(context, med, db);
                  },
                ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_rounded, size: 80, color: Colors.black.withOpacity(0.06)),
          const SizedBox(height: 16),
          Text(
            "No medications added yet.",
            style: TextStyle(color: Colors.black.withOpacity(0.4), fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openAddMedicineSheet(context),
            icon: const Icon(Icons.add),
            label: const Text("Add Medication"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A86F0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDefaultIcon(Medicine med) {
    Color medColor = const Color(0xFF3A86F0);
    if (med.color != null && med.color!.isNotEmpty) {
      try {
        medColor = Color(int.parse(med.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: medColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        med.form.toLowerCase() == 'liquid' 
            ? Icons.water_drop_rounded 
            : med.form.toLowerCase() == 'injection' 
                ? Icons.vaccines_rounded 
                : Icons.circle_rounded,
        color: medColor,
      ),
    );
  }

  Widget _buildMedCard(BuildContext context, Medicine med, DbService db) {
    Color medColor = const Color(0xFF3A86F0);
    if (med.color != null && med.color!.isNotEmpty) {
      try {
        medColor = Color(int.parse(med.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    // Determine status badge
    String statusText = "Active";
    Color statusColor = const Color(0xFF2E7D32);
    
    final today = DateTime.now();
    final isOutOfStock = med.pillsLeft != null && med.pillsLeft! <= 0;
    
    if (isOutOfStock) {
      statusText = "Out of Stock";
      statusColor = Colors.redAccent;
    } else if (med.endDate != null) {
      final diff = med.endDate!.difference(today).inDays;
      if (diff >= 0 && diff <= 3) {
        statusText = "Ending Soon";
        statusColor = Colors.orangeAccent;
      } else if (diff < 0) {
        statusText = "Expired";
        statusColor = Colors.grey;
      }
    }

    // Calculate days remaining
    String durationText = "Continuous";
    if (med.endDate != null) {
      final diff = med.endDate!.difference(today).inDays;
      durationText = diff >= 0 ? "$diff days left" : "Ended";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Photo or Icon
              if (med.photoUrl != null && med.photoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    med.photoUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultIcon(med),
                  ),
                )
              else
                _buildDefaultIcon(med),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusText.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Dosage Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "1 ${med.form.toUpperCase()}",
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF3A86F0)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    builder: (context) {
                      return _AddMedicineSheet(profile: widget.profile, medicine: med);
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () {
                  db.deleteMedicine(med, widget.profile);
                },
              )
            ],
          ),
          const Divider(height: 24, color: Colors.black12),
          
          // Details Grid Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant_rounded, size: 16, color: Colors.black38),
                  const SizedBox(width: 6),
                  Text(
                    med.foodInstruction.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded, size: 16, color: Color(0xFF3A86F0)),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimeString(med.doseTime),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3A86F0)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, size: 16, color: Colors.black38),
                  const SizedBox(width: 6),
                  Text(
                    med.pillsLeft != null ? "${med.pillsLeft} remaining" : "Continuous stock",
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.black38),
                  const SizedBox(width: 6),
                  Text(
                    durationText,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          
          // Refill warning banner
          if (med.pillsLeft != null && med.pillsLeft! < 5) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Low stock warning! Refill soon.",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

// ADD / EDIT MEDICINE DIALOG / SHEET
class _AddMedicineSheet extends StatefulWidget {
  final Profile profile;
  final Medicine? medicine;
  const _AddMedicineSheet({required this.profile, this.medicine});

  @override
  State<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();

  String _selectedForm = 'Tablet';
  String _selectedFreq = '1 time, Daily';
  String _selectedFoodInst = 'before_food';
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(days: 10));
  String _selectedTime = "08:00";
  String _selectedColor = '#3A86F0';
  String? _photoUrl;

  bool _isScanning = false;
  bool _isUploadingPhoto = false;
  int _currentStep = 1;

  final List<Map<String, dynamic>> _medForms = [
    {'name': 'Tablet', 'icon': Icons.circle_rounded},
    {'name': 'Capsule', 'icon': Icons.cookie_rounded},
    {'name': 'Liquid', 'icon': Icons.water_drop_rounded},
    {'name': 'Lotion', 'icon': Icons.sanitizer_rounded},
    {'name': 'Spray', 'icon': Icons.air_rounded},
    {'name': 'Ointment', 'icon': Icons.healing_rounded},
    {'name': 'Drops', 'icon': Icons.opacity_rounded},
    {'name': 'Gel', 'icon': Icons.bubble_chart_rounded},
    {'name': 'Suppository', 'icon': Icons.egg_rounded},
    {'name': 'Injection', 'icon': Icons.vaccines_rounded},
    {'name': 'Cream', 'icon': Icons.spa_rounded},
    {'name': 'Powder', 'icon': Icons.blur_on_rounded},
    {'name': 'Foam', 'icon': Icons.cloud_rounded},
    {'name': 'Inhaler', 'icon': Icons.wind_power_rounded},
    {'name': 'Gummy', 'icon': Icons.child_care_rounded},
  ];

  final List<String> _freqOptions = [
    '1 time, Daily',
    '2 time, Daily',
    '3 time, Daily',
    'More than 3 times, Daily',
    'Specific Days of the Week',
    'Every X Days',
    'Every X Weeks',
    'Every X Months',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.medicine != null) {
      _nameController.text = widget.medicine!.name;
      _selectedTime = widget.medicine!.doseTime.substring(0, 5);
      _qtyController.text = widget.medicine!.pillsLeft?.toString() ?? "1";
      _selectedForm = widget.medicine!.form;
      _selectedFreq = widget.medicine!.frequency;
      _selectedFoodInst = widget.medicine!.foodInstruction;
      _selectedStartDate = widget.medicine!.startDate;
      if (widget.medicine!.endDate != null) {
        _selectedEndDate = widget.medicine!.endDate!;
      }
      _selectedColor = widget.medicine!.color ?? '#3A86F0';
      _photoUrl = widget.medicine!.photoUrl;
    } else {
      _qtyController.text = "1";
    }
  }

  String _formatDateString(DateTime dt) {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[dt.month - 1]} ${dt.day}";
  }

  void _showFormSelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Select Medication",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black45),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: _medForms.length,
                      itemBuilder: (context, idx) {
                        final form = _medForms[idx];
                        final isSel = form['name'] == _selectedForm;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedForm = form['name'];
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF3A86F0).withOpacity(0.08) : Colors.black.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSel ? const Color(0xFF3A86F0) : Colors.black.withOpacity(0.05)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(form['icon'], color: isSel ? const Color(0xFF3A86F0) : Colors.black54),
                                const SizedBox(height: 8),
                                Text(
                                  form['name'],
                                  style: TextStyle(
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    color: isSel ? const Color(0xFF3A86F0) : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showFrequencySelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Set Frequency",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black45),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _freqOptions.length,
                  itemBuilder: (context, idx) {
                    final freq = _freqOptions[idx];
                    final isSelected = freq == _selectedFreq;
                    return ListTile(
                      title: Text(
                        freq,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF3A86F0) : const Color(0xFF1F2937),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF3A86F0)) : null,
                      onTap: () {
                        setState(() {
                          _selectedFreq = freq;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final supabase = Supabase.instance.client;
      final bytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'medicine_photos/$fileName';

      await supabase.storage.from('medaayu_photos').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final url = supabase.storage.from('medaayu_photos').getPublicUrl(path);
      setState(() {
        _photoUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medicine photo uploaded successfully!")),
      );
    } catch (e) {
      debugPrint("Photo upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload photo: $e")),
      );
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  void _save(DbService db) {
    if (_nameController.text.trim().isEmpty) return;

    if (widget.medicine == null && widget.profile.planTier == PlanTier.basic && db.medicines.length >= 2) {
      _showLimitReachedDialog(context);
      return;
    }

    final med = Medicine(
      id: widget.medicine?.id ?? '',
      profileId: widget.profile.id,
      name: _nameController.text.trim(),
      form: _selectedForm,
      frequency: _selectedFreq,
      doseTime: "${_selectedTime}:00",
      pillsLeft: int.tryParse(_qtyController.text.trim()),
      foodInstruction: _selectedFoodInst,
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      color: _selectedColor,
      photoUrl: _photoUrl,
    );

    if (widget.medicine != null) {
      db.updateMedicine(med, widget.profile);
    } else {
      db.addMedicine(med, widget.profile);
    }
    Navigator.pop(context);
  }

  void _showLimitReachedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Plan Limit Reached", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        content: const Text(
          "The Free plan only allows up to 2 medicine reminders per day.\n\nPlease upgrade to Premium (₹129/month + ₹49/medicine/month compulsory) to add unlimited reminders and unlock Voice Calls.",
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              final billing = Provider.of<BillingService>(context, listen: false);
              _openBillingSheet(context, billing);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A86F0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text("Upgrade Plan"),
          ),
        ],
      ),
    );
  }

  void _openBillingSheet(BuildContext context, BillingService billing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("📞 Voice Calling Feature", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 16),
              Text("Automated Voice Call Reminders are active as the standard feature for your account. Calls will ring on your registered mobile number for every scheduled medicine.", style: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.7))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86F0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Got It"),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepProgressIndicator() {
    if (_currentStep == 5) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Step $_currentStep of 4",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black45),
            ),
            Text(
              _getStepName(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3A86F0)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            final isDone = index + 1 <= _currentStep;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF3A86F0) : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _getStepName() {
    switch (_currentStep) {
      case 1:
        return "Medicine Info";
      case 2:
        return "Schedule Info";
      case 3:
        return "Reminder Channels";
      case 4:
        return "Photo & Appearance";
      default:
        return "";
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.medicine == null) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleScan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text("Scan Prescription"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.04),
                    foregroundColor: const Color(0xFF3A86F0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleScan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text("Upload Prescription"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.04),
                    foregroundColor: const Color(0xFF3A86F0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (_isScanning)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Color(0xFF3A86F0))))
        else ...[
          const Text(
            "Medicine Name",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "Search or type medicine name",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Medicine Form",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showFormSelectorSheet,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedForm,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Pills Quantity",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                onPressed: () {
                  final val = int.tryParse(_qtyController.text) ?? 1;
                  if (val > 1) {
                    setState(() => _qtyController.text = (val - 1).toString());
                  }
                },
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _qtyController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
              const SizedBox(width: 24),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: () {
                  final val = int.tryParse(_qtyController.text) ?? 1;
                  setState(() => _qtyController.text = (val + 1).toString());
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Frequency",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showFrequencySelectorSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedFreq,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Dose Time",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            int initHour = 8;
            int initMin = 0;
            if (_selectedTime.contains(":")) {
              final parts = _selectedTime.split(":");
              initHour = int.tryParse(parts[0]) ?? 8;
              initMin = int.tryParse(parts[1]) ?? 0;
            }
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: initHour, minute: initMin),
            );
            if (picked != null) {
              setState(() {
                _selectedTime = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimeString(_selectedTime),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Icon(Icons.alarm_rounded, color: Color(0xFF3A86F0)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Food Instruction",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            {'val': 'before_food', 'label': 'Before Food', 'icon': Icons.restaurant_rounded},
            {'val': 'after_food', 'label': 'After Food', 'icon': Icons.free_breakfast_rounded},
            {'val': 'with_food', 'label': 'With Food', 'icon': Icons.lunch_dining_rounded},
            {'val': 'empty_stomach', 'label': 'Empty Stomach', 'icon': Icons.no_food_rounded},
          ].map((item) {
            final isSel = _selectedFoodInst == item['val'];
            final color = isSel ? const Color(0xFF3A86F0) : Colors.black54;
            return ChoiceChip(
              avatar: Icon(item['icon'] as IconData, size: 18, color: isSel ? Colors.white : color),
              label: Text(
                item['label'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              selected: isSel,
              selectedColor: const Color(0xFF3A86F0),
              backgroundColor: const Color(0xFFF4F6FA),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFoodInst = item['val'] as String);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          "Duration Dates",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedStartDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedStartDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Start", style: TextStyle(fontSize: 11, color: Colors.black45)),
                      const SizedBox(height: 4),
                      Text(_formatDateString(_selectedStartDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedEndDate,
                    firstDate: _selectedStartDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedEndDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("End", style: TextStyle(fontSize: 11, color: Colors.black45)),
                      const SizedBox(height: 4),
                      Text(_formatDateString(_selectedEndDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final isPremium = widget.profile.planTier == PlanTier.premium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Configured Reminder Channels",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 8),
        const Text(
          "MedAayu automatically sends reminders via local alarms and automated voice calls.",
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const ListTile(
          leading: Icon(Icons.phone_callback_rounded, color: Color(0xFF6C5CE7)),
          title: Text("Automated Voice Call Reminders"),
          subtitle: Text("Active Standard Feature • Ring Calls for Doses", style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.check_circle_rounded, color: Color(0xFF00B894)),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.notifications_active_rounded, color: Color(0xFF3A86F0)),
          title: Text("Local Phone Notifications (Alarms)"),
          subtitle: Text("Active Standard Feature • Unlimited Alarms", style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.check_circle_rounded, color: Color(0xFF00B894)),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Color Theme",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['#3A86F0', '#2E7D32', '#FFAA00', '#8E24AA', '#E53935'].map((hex) {
            final isSel = _selectedColor == hex;
            final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = hex),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSel ? Border.all(color: Colors.black, width: 3) : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          "Medicine Photo",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 12),
        if (_photoUrl != null && _photoUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _photoUrl!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: _isUploadingPhoto ? null : _pickPhoto,
          icon: _isUploadingPhoto 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.photo_camera_rounded),
          label: Text(_isUploadingPhoto ? "Uploading..." : (_photoUrl != null ? "Change Photo" : "Upload Photo")),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF3F4F6),
            foregroundColor: const Color(0xFF3A86F0),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Review Details",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 4),
        const Text(
          "Verify everything is correct before saving.",
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            children: [
              _buildReviewRow("Name", _nameController.text),
              const Divider(),
              _buildReviewRow("Form", _selectedForm),
              const Divider(),
              _buildReviewRow("Pills Quantity", _qtyController.text),
              const Divider(),
              _buildReviewRow("Frequency", _selectedFreq),
              const Divider(),
              _buildReviewRow("Time", _formatTimeString(_selectedTime)),
              const Divider(),
              _buildReviewRow("Instruction", _selectedFoodInst.replaceAll('_', ' ').toUpperCase()),
              const Divider(),
              _buildReviewRow("Start Date", _formatDateString(_selectedStartDate)),
              const Divider(),
              _buildReviewRow("End Date", _formatDateString(_selectedEndDate)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(DbService db) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          if (_currentStep > 1) ...[
            Expanded(
              child: SecondaryButton(
                text: "Back",
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: PrimaryButton(
              text: _currentStep == 5 ? (widget.medicine != null ? "Save Changes" : "Save Medicine") : "Continue",
              onPressed: () {
                if (_currentStep == 1) {
                  if (_nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter medicine name")),
                    );
                    return;
                  }
                }
                if (_currentStep < 5) {
                  setState(() {
                    _currentStep++;
                  });
                } else {
                  _save(db);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DbService>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle / Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.medicine != null ? "Edit Medication" : "Add Medication",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStepProgressIndicator(),
                  if (_currentStep == 1) _buildStep1(),
                  if (_currentStep == 2) _buildStep2(),
                  if (_currentStep == 3) _buildStep3(),
                  if (_currentStep == 4) _buildStep4(),
                  if (_currentStep == 5) _buildStep5(),
                ],
              ),
            ),
          ),

          // Sticky Bottom Bar
          _buildStickyBottomBar(db),
        ],
      ),
    );
  }

  // Future OCR Scan Prescription
  Future<void> _handleScan(ImageSource source) async {
    setState(() => _isScanning = true);
    final parsed = await OcrService.scanPrescription(context, source);
    setState(() => _isScanning = false);

    if (parsed != null) {
      setState(() {
        _nameController.text = parsed.name;
        _selectedForm = parsed.form;
        _selectedTime = parsed.doseTime.substring(0, 5);
        _selectedFoodInst = parsed.foodInstruction;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Prescription parsed! Please confirm details before saving.")),
      );
    }
  }
}

// ================= ADD PROFILE DIALOG (2-Step Wizard) =================
class AddProfileDialog extends StatefulWidget {
  final Profile currentProfile;
  const AddProfileDialog({super.key, required this.currentProfile});

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<AddProfileDialog> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = 'Male';
  String _language = 'english';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A86F0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_alt_rounded, color: Color(0xFF3A86F0), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Add Profile",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937)),
                      ),
                      Text(
                        "Step ${_step + 1} of 2",
                        style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Colors.black.withOpacity(0.4)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_step + 1) / 2,
                backgroundColor: const Color(0xFFE5E7EB),
                color: const Color(0xFF3A86F0),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 24),
            // Step content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _step == 0 ? _buildStep1() : _buildStep2(),
            ),
            const SizedBox(height: 24),
            // Actions
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step = 0),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1F2937),
                        side: BorderSide(color: Colors.black.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Back"),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A86F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_step == 0 ? "Continue" : "Create Profile"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Profile Information",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 4),
        Text(
          "Enter the name and phone number of the person you want to manage medicines for.",
          style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5)),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: Color(0xFF1F2937)),
          textCapitalization: TextCapitalization.words,
          decoration: DesignSystem.premiumInputDecoration(
            labelText: "Full Name",
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: const TextStyle(color: Color(0xFF1F2937), letterSpacing: 1.5),
          decoration: DesignSystem.premiumInputDecoration(
            labelText: "Mobile Number",
            hintText: "10-digit number",
            prefixIcon: const Icon(Icons.phone_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      key: const ValueKey('step2'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Additional Details",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 4),
        Text(
          "Help us personalize reminders and health tips.",
          style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF1F2937)),
                decoration: DesignSystem.premiumInputDecoration(
                  labelText: "Age",
                  prefixIcon: const Icon(Icons.cake_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _gender,
                style: const TextStyle(color: Color(0xFF1F2937)),
                dropdownColor: Colors.white,
                decoration: DesignSystem.premiumInputDecoration(labelText: "Gender"),
                items: ['Male', 'Female', 'Other'].map((g) {
                  return DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w600)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _gender = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _language,
          style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontWeight: FontWeight.w600),
          dropdownColor: Colors.white,
          decoration: DesignSystem.premiumInputDecoration(
            labelText: "Reminder Language",
            prefixIcon: const Icon(Icons.translate_rounded, size: 20, color: Color(0xFF3A86F0)),
          ),
          items: const [
            DropdownMenuItem(value: 'english', child: Text("🇬🇧 English", style: TextStyle(color: Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'hindi', child: Text("🇮🇳 Hindi (हिंदी)", style: TextStyle(color: Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'marathi', child: Text("🇮🇳 Marathi (मराठी)", style: TextStyle(color: Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w600))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _language = val);
          },
        ),
      ],
    );
  }

  void _onNext() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a name"), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
        return;
      }
      if (_phoneCtrl.text.trim().length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid 10-digit phone number"), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
        return;
      }
      setState(() => _step = 1);
    } else {
      _createProfile();
    }
  }

  Future<void> _createProfile() async {
    setState(() => _isLoading = true);
    try {
      final db = Provider.of<DbService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);

      final newProfile = await db.createParentProfile(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text.trim()),
        gender: _gender,
        planTier: widget.currentProfile.planTier,
        language: _language,
        sosAction: 'notify',
        sosContactPhone: widget.currentProfile.phone,
      );

      if (!mounted) return;

      if (newProfile != null) {
        Navigator.pop(context);
        await auth.switchProfile(newProfile.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("✅ Profile for ${newProfile.fullName} created!"),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        throw Exception("Failed to create profile. The phone number may already be registered.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Error", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            content: Text(e.toString().replaceAll("Exception: ", ""), style: const TextStyle(color: Color(0xFF1F2937))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: Color(0xFF3A86F0))),
              )
            ],
          ),
        );
      }
    }
  }
}

// ================= MANAGE TAB =================
class _ManageTab extends StatefulWidget {
  final Profile profile;
  const _ManageTab({required this.profile});

  @override
  State<_ManageTab> createState() => _ManageTabState();
}

class _ManageTabState extends State<_ManageTab> {
  void _openEditParentPhoneDialog(BuildContext context, DbService db, Profile parent) {
    final phoneCtrl = TextEditingController(text: parent.phone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Edit Phone — ${parent.fullName}",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18, letterSpacing: 2),
          decoration: InputDecoration(
            labelText: "10-digit Mobile Number",
            prefixText: "+91 ",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF3A86F0)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text("Save"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A86F0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              final newPhone = phoneCtrl.text.trim();
              if (newPhone.length < 10) return;
              Navigator.pop(ctx);
              final ok = await db.updateParentPhone(parent.id, newPhone);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? "✅ Phone updated to +91$newPhone" : "❌ Failed to update phone"),
                  backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
          ),
        ],
      ),
    );
  }

  void _openBillingSheet(BuildContext context, BillingService billing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Manage Plan Tiers", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 16),
              Text("Upgrade your plan to unlock Voice Call & WhatsApp reminder channels for safety and delivery assurance:", style: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.7))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await billing.purchasePlan(PlanTier.premium);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86F0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Upgrade to Premium - ₹129/mo"),
              ),
              const SizedBox(height: 12),
              const Text(
                "* Includes 2 medicine reminder calls/WhatsApp per day. Additional medicines/reminders are ₹49/medicine/month compulsory.",
                style: TextStyle(color: Colors.black45, fontSize: 11, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _openEmergencyContactsDialog(BuildContext context, AuthService auth) {
    final primaryController = TextEditingController(text: widget.profile.sosContactPhone);
    final secondaryController = TextEditingController(text: widget.profile.sosContactPhone2);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Configure SOS Contacts", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: primaryController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Color(0xFF1F2937)),
                decoration: const InputDecoration(labelText: "Primary Emergency Number"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secondaryController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Color(0xFF1F2937)),
                decoration: const InputDecoration(labelText: "Secondary Emergency Number"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () async {
                await Supabase.instance.client.from('profiles').update({
                  'sos_contact_phone': primaryController.text.trim(),
                  'sos_contact_phone_2': secondaryController.text.trim(),
                }).eq('id', widget.profile.id);
                
                await auth.loadProfile();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Emergency contacts updated successfully!")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86F0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  void _openLanguageDialog(BuildContext context, AuthService auth) {
    String currentLanguage = widget.profile.language;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Select Reminders Language", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: currentLanguage,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF1F2937)),
                    items: const [
                      DropdownMenuItem(value: 'english', child: Text("English")),
                      DropdownMenuItem(value: 'hindi', child: Text("Hindi (हिंदी)")),
                      DropdownMenuItem(value: 'marathi', child: Text("Marathi (मराठी)")),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => currentLanguage = val);
                    },
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: const Color(0xFF1F2937).withOpacity(0.5))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await Supabase.instance.client.from('profiles').update({
                      'language': currentLanguage,
                    }).eq('id', widget.profile.id);
                    await auth.switchProfile(widget.profile.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Language preference saved!")),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A86F0), foregroundColor: Colors.white),
                  child: const Text("Save"),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _exportMedicationHistory(BuildContext context, DbService db) {
    final buffer = StringBuffer();
    buffer.writeln("MedAayu Medication History Report");
    buffer.writeln("Generated on: ${DateTime.now().toIso8601String().split('T')[0]}");
    buffer.writeln("=================================");
    buffer.writeln("");
    
    for (final med in db.medicines) {
      buffer.writeln("Medicine: ${med.name}");
      buffer.writeln("- Form: ${med.form}");
      buffer.writeln("- Frequency: ${med.frequency}");
      buffer.writeln("- Time: ${med.doseTime}");
      buffer.writeln("- Guideline: ${med.foodInstruction.replaceAll('_', ' ')}");
      buffer.writeln("- Stock remaining: ${med.pillsLeft ?? 'Continuous'}");
      buffer.writeln("---------------------------------");
    }
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Medication history copied to clipboard! Ready to export.")),
    );
  }

  Widget _buildPremiumCard(BuildContext context, BillingService billing) {
    final activeTier = widget.profile.planTier;
    if (activeTier == PlanTier.premium) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFAA00), Color(0xFFFF7700)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFAA00).withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("⭐ Premium", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text("Voice Calls", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Spacer(),
                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text("WhatsApp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text("SOS Alerts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Spacer(),
                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text("AI Care Tips", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Expires: 20 Aug 2026",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                TextButton(
                  onPressed: () => _openBillingSheet(context, billing),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text("Manage Plan >", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_outline_rounded, color: Colors.amber, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Upgrade to Premium", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(
                  "Get automated voice calls & SOS escalation",
                  style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4)),
                )
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text("📞 Active", style: TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF3A86F0),
    Color textColor = const Color(0xFF1F2937),
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black45))
            : null,
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final db = Provider.of<DbService>(context);
    final billing = Provider.of<BillingService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF1F2937))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 1. Premium card
          _buildPremiumCard(context, billing),

          // 2. Linked Profiles Section
          _buildSectionHeader("👵 Linked Profiles"),
          _buildSettingsTile(
            icon: Icons.person_add_alt_rounded,
            title: "Add / Link New Profile",
            onTap: () => showDialog(
              context: context,
              builder: (context) => AddProfileDialog(currentProfile: widget.profile),
            ),
          ),
          ...db.linkedParents.map((parent) => _buildSettingsTile(
            icon: parent.role == UserRole.parent
                ? Icons.supervisor_account_rounded
                : Icons.person_outline_rounded,
            iconColor: const Color(0xFF2E7D32),
            title: parent.fullName,
            subtitle: "📱 ${parent.phone.isNotEmpty ? parent.phone : 'No phone linked'}",
            onTap: () => auth.switchProfile(parent.id),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.phone_android_rounded, color: Color(0xFF3A86F0)),
                  tooltip: "Edit Phone",
                  onPressed: () => _openEditParentPhoneDialog(context, db, parent),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: "Delete",
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("Delete Profile?", style: TextStyle(fontWeight: FontWeight.bold)),
                        content: Text("Are you sure you want to permanently delete the profile for ${parent.fullName}? This will erase all medicines and history. This action is irreversible."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel", style: TextStyle(color: Colors.black45)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      if (widget.profile.id == parent.id) {
                        final primaryId = widget.profile.role == UserRole.parent ? widget.profile.ownerId : widget.profile.id;
                        if (primaryId != null) {
                          await auth.switchProfile(primaryId);
                        }
                      }
                      
                      final ok = await db.deleteProfile(parent.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? "✅ Profile deleted successfully" : "❌ Failed to delete profile"),
                          backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),

          // 3. Languages Section
          _buildSectionHeader("🌐 Language Settings"),
          _buildSettingsTile(
            icon: Icons.language_rounded,
            title: "Reminders Language",
            trailing: Text(
              widget.profile.language.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3A86F0)),
            ),
            onTap: () => _openLanguageDialog(context, auth),
          ),
          const SizedBox(height: 16),

          // 4. Emergency Contacts Section
          _buildSectionHeader("📞 Emergency Contacts"),
          _buildSettingsTile(
            icon: Icons.contact_phone_rounded,
            title: "SOS Primary: ${widget.profile.sosContactPhone ?? 'Not set'}",
            onTap: () => _openEmergencyContactsDialog(context, auth),
          ),
          if (widget.profile.sosContactPhone2 != null && widget.profile.sosContactPhone2!.isNotEmpty)
            _buildSettingsTile(
              icon: Icons.contact_phone_outlined,
              title: "SOS Secondary: ${widget.profile.sosContactPhone2}",
              onTap: () => _openEmergencyContactsDialog(context, auth),
            ),
          const SizedBox(height: 16),

          // 5. Billing Settings / Reminder Type
          _buildSectionHeader("🔔 Reminder Settings"),
          _buildSettingsTile(
            icon: Icons.alarm_rounded,
            title: "Active channel: ${BillingService.getReminderChannelName(widget.profile.planTier)}",
            trailing: TextButton(
              onPressed: () => _openBillingSheet(context, billing),
              child: const Text("Change Plan", style: TextStyle(color: Color(0xFF3A86F0), fontWeight: FontWeight.bold)),
            ),
            onTap: () => _openBillingSheet(context, billing),
          ),
          const SizedBox(height: 16),

          // App Settings Section
          _buildSectionHeader("⚙️ App Settings"),
          _buildSettingsTile(
            icon: Icons.notifications_rounded,
            title: "Notification Settings",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Notification Settings will be configurable in a future release.")),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.cloud_upload_rounded,
            title: "Backup & Restore",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Backup & Restore will be configurable in a future release.")),
              );
            },
          ),
          const SizedBox(height: 16),

          // Security & Legal Section
          _buildSectionHeader("🔒 Security & Legal"),
          _buildSettingsTile(
            icon: Icons.privacy_tip_rounded,
            title: "Privacy Policy",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("MedAayu Privacy Policy")),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: "About MedAayu",
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "MedAayu",
                applicationVersion: "1.0.0",
                applicationLegalese: "© 2026 MedAayu Team. All rights reserved.",
                applicationIcon: Image.asset('assets/logo.png', height: 60, width: 60, fit: BoxFit.contain),
              );
            },
          ),
          const SizedBox(height: 16),

          // 6. Caregiver Management Section
          _buildSectionHeader("👨 Caregiver Management"),
          _buildSettingsTile(
            icon: Icons.person_rounded,
            title: "Profile: ${auth.caregiverName ?? widget.profile.fullName}",
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.exit_to_app_rounded,
            iconColor: Colors.redAccent,
            title: "Sign Out",
            textColor: Colors.redAccent,
            onTap: () => auth.signOut(),
            trailing: const SizedBox(),
          ),
          if (widget.profile.role == UserRole.self)
            _buildSettingsTile(
              icon: Icons.delete_forever_rounded,
              iconColor: Colors.redAccent,
              title: "Delete Account",
              textColor: Colors.redAccent,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Delete Account?"),
                    content: const Text("Are you sure you want to permanently delete your account? This will erase all profiles and medicines. This action is irreversible."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        child: const Text("Delete"),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await db.deleteProfile(widget.profile.id);
                  await auth.signOut();
                }
              },
              trailing: const SizedBox(),
            ),
          const SizedBox(height: 16),

          // 7. Data export Section
          _buildSectionHeader("📄 Export Data"),
          _buildSettingsTile(
            icon: Icons.download_rounded,
            title: "Export Medication History",
            onTap: () => _exportMedicationHistory(context, db),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
      ),
    );
  }

  InputDecoration _buildDialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black45, fontSize: 13),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3A86F0))),
    );
  }
}

// ================= FIRST TIME SETUP WIDGET =================
class _FirstTimeSetupWidget extends StatefulWidget {
  final Profile profile;
  final VoidCallback onComplete;

  const _FirstTimeSetupWidget({required this.profile, required this.onComplete});

  @override
  State<_FirstTimeSetupWidget> createState() => _FirstTimeSetupWidgetState();
}

class _FirstTimeSetupWidgetState extends State<_FirstTimeSetupWidget> {
  int _currentStep = 0; // 0: Role Select, 1: Plan Select, 2: Form Details

  // Selection state
  String _selectedRoleType = 'self'; // 'self' or 'parent'
  PlanTier _selectedPlanTier = PlanTier.basic;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _sosPhoneController = TextEditingController();

  DateTime? _selectedDob;
  String _selectedGender = 'Male';
  String _selectedBlood = 'O+';
  String _selectedLanguage = 'english';

  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Default name to the logged-in caregiver's name
    _nameController.text = widget.profile.fullName;
  }

  String _getGreetingText(String name) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Good Morning, $name";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon, $name";
    } else if (hour >= 17 && hour < 22) {
      return "Good Evening, $name";
    } else {
      return "Good Night, $name";
    }
  }

  String _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "☀️";
    } else if (hour >= 12 && hour < 17) {
      return "☀️";
    } else if (hour >= 17 && hour < 22) {
      return "🌙";
    } else {
      return "🌙";
    }
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
    if (_selectedDob == null) {
      setState(() => _errorMessage = "Please select Date of Birth.");
      return;
    }

    if (_selectedRoleType == 'parent') {
      if (_parentPhoneController.text.trim().length < 10) {
        setState(() => _errorMessage = "Please enter a valid 10-digit Parent phone number.");
        return;
      }
      if (_sosPhoneController.text.trim().length < 10) {
        setState(() => _errorMessage = "Please enter a valid 10-digit Emergency contact number.");
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final db = Provider.of<DbService>(context, listen: false);
      final calculatedAge = _calculateAge(_selectedDob!);

      if (_selectedRoleType == 'self') {
        final ok = await auth.setupProfile(
          fullName: _nameController.text.trim(),
          role: UserRole.self,
          age: calculatedAge,
          gender: _selectedGender,
          bloodGroup: _selectedBlood,
          planTier: _selectedPlanTier,
          language: 'english',
          sosAction: 'notify',
        );
        if (ok) {
          widget.onComplete();
        } else {
          setState(() => _errorMessage = "Failed to update profile.");
        }
      } else {
        // 1. Create/upsert the caregiver's own profile row first to satisfy foreign key constraints (owner_id REFERENCES profiles(id))
        final cgOk = await auth.setupProfile(
          fullName: auth.caregiverName ?? (widget.profile.fullName.isNotEmpty ? widget.profile.fullName : "Caregiver"),
          role: UserRole.self,
          age: -1, // Placeholder indicating parent mode setup completed
          gender: 'Other',
          bloodGroup: 'O+',
          planTier: _selectedPlanTier,
          language: 'english',
          sosAction: 'notify',
        );

        if (!cgOk) {
          setState(() => _errorMessage = "Failed to initialize caregiver profile.");
          return;
        }

        // 2. Parent Profile Creation
        final parentProfile = await db.createParentProfile(
          fullName: _nameController.text.trim(),
          age: calculatedAge,
          gender: _selectedGender,
          bloodGroup: _selectedBlood,
          phone: _parentPhoneController.text.trim(),
          sosContactPhone: _sosPhoneController.text.trim(),
          planTier: _selectedPlanTier,
          language: _selectedLanguage,
          sosAction: 'notify',
        );

        if (parentProfile != null) {
          // Switch active view to parent
          await auth.switchProfile(parentProfile.id);
          widget.onComplete();
        } else {
          setState(() => _errorMessage = "Failed to create parent profile. Phone might already be registered.");
        }
      }
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      setState(() => _errorMessage = cleanErr);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final greeting = _getGreetingText(auth.caregiverName ?? widget.profile.fullName);
    final icon = _getGreetingIcon();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$icon $greeting",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Let's complete your quick setup",
                  style: TextStyle(fontSize: 14, color: Colors.black45),
                ),
              ],
            ),
          ),

          // Steps
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildCurrentStepView(),
            ),
          ),
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
        const SizedBox(height: 12),
        const Text(
          "Who will be using MedAayu reminders?",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 24),
        _buildRoleSelectionCard(
          title: "Add Myself",
          description: "Reminders go to this device/registered number.",
          icon: Icons.person_outline_rounded,
          role: 'self',
        ),
        const SizedBox(height: 16),
        _buildRoleSelectionCard(
          title: "Add Parent / Elder",
          description: "Reminders go to your parent's phone (voice calls/WhatsApp).",
          icon: Icons.elderly_rounded,
          role: 'parent',
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentStep = 1;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3A86F0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: isSelected ? const Color(0xFF3A86F0) : Colors.black.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3A86F0).withOpacity(0.08) : Colors.black.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: isSelected ? const Color(0xFF3A86F0) : Colors.black38),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: Colors.black45),
                  ),
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
        const Text(
          "Reminder Delivery Feature",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 16),
        _buildPlanTierCard(
          tier: PlanTier.premium,
          title: "📞 Medaayu Voice Calling",
          price: "Standard Feature",
          color: const Color(0xFF6C5CE7),
          features: [
            "Automated Voice Call Reminders for every dose",
            "Multi-lingual support (English, Hindi, Marathi)",
            "Local phone alarms & notifications included",
            "Medicine & adherence tracking",
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
                child: const Text("Back", style: TextStyle(color: Colors.black54)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 2;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86F0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
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
      onTap: () {
        setState(() {
          _selectedPlanTier = tier;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: isSelected ? color : Colors.black.withOpacity(0.05),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? color : Colors.black26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
                Text(
                  price,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_rounded, size: 16, color: Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            )),
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
            isParent ? "Parent's Personal Details" : "Personal Details",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 20),

          // Name Input
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Color(0xFF1F2937)),
            decoration: _buildFormInputDecoration(isParent ? "Parent's Full Name" : "Full Name"),
            validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
          ),
          const SizedBox(height: 16),

          // DOB Date Picker Input
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 40)),
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 110)),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDob = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDob,
                    style: TextStyle(
                      color: _selectedDob == null ? Colors.black38 : const Color(0xFF1F2937),
                      fontSize: 15,
                      fontWeight: _selectedDob == null ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF3A86F0)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gender Dropdown
          DropdownButtonFormField<String>(
            value: _selectedGender,
            style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontWeight: FontWeight.w600),
            dropdownColor: Colors.white,
            decoration: _buildFormInputDecoration("Gender"),
            items: ['Male', 'Female', 'Other'].map((g) {
              return DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600)));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedGender = val);
            },
          ),
          const SizedBox(height: 16),

          // Blood Group Dropdown
          DropdownButtonFormField<String>(
            value: _selectedBlood,
            style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontWeight: FontWeight.w600),
            dropdownColor: Colors.white,
            decoration: _buildFormInputDecoration("Blood Group"),
            items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((b) {
              return DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600)));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedBlood = val);
            },
          ),
          const SizedBox(height: 16),

          // Conditional fields for parent
          if (isParent) ...[
            // Parent Phone Number
            TextFormField(
              controller: _parentPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontWeight: FontWeight.w600),
              decoration: _buildFormInputDecoration("Parent's Mobile Number (for Login)").copyWith(
                counterText: "",
                prefixText: "+91 ",
              ),
              validator: (val) => val == null || val.trim().length < 10 ? "Valid 10-digit number required" : null,
            ),
            const SizedBox(height: 16),

            // Emergency Contact Number
            TextFormField(
              controller: _sosPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontWeight: FontWeight.w600),
              decoration: _buildFormInputDecoration("Caregiver/SOS Contact Number").copyWith(
                counterText: "",
                prefixText: "+91 ",
              ),
              validator: (val) => val == null || val.trim().length < 10 ? "Valid 10-digit number required" : null,
            ),
            const SizedBox(height: 16),

            // Preferred Language
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontWeight: FontWeight.w600),
              dropdownColor: Colors.white,
              decoration: _buildFormInputDecoration("Reminders/App Language"),
              items: const [
                DropdownMenuItem(value: 'english', child: Text("🇬🇧 English", style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600))),
                DropdownMenuItem(value: 'hindi', child: Text("🇮🇳 Hindi (हिंदी)", style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600))),
                DropdownMenuItem(value: 'marathi', child: Text("🇮🇳 Marathi (मराठी)", style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedLanguage = val);
              },
            ),
            const SizedBox(height: 16),
          ],

          if (_errorMessage.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                    });
                  },
                  child: const Text("Back", style: TextStyle(color: Colors.black54)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF3A86F0)))
                    : ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A86F0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text("Finish Setup", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  InputDecoration _buildFormInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
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

