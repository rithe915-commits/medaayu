import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/fall_detection.dart';

class ElderView extends StatefulWidget {
  const ElderView({super.key});

  @override
  State<ElderView> createState() => _ElderViewState();
}

class _ElderViewState extends State<ElderView> {
  late FallDetectionService _fallDetectionService;
  bool _isCountdownActive = false;
  int _countdownSeconds = 20;
  Timer? _countdownTimer;
  String _statusText = "Monitoring Safety...";
  bool _isSosTriggering = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize Fall Detection Service
    _fallDetectionService = FallDetectionService(
      onFallDetected: () {
        _triggerFallWarning();
      },
    );

    // Auto-start fall detection on view open
    _fallDetectionService.start();
  }

  @override
  void dispose() {
    _fallDetectionService.stop();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Suspended fall detected -> Start Alert warning countdown
  void _triggerFallWarning() {
    if (_isCountdownActive) return;

    setState(() {
      _isCountdownActive = true;
      _countdownSeconds = 20;
      _statusText = "FALL SUSPECTED!";
    });

    // Vibrate device to alert elder
    HapticFeedback.heavyImpact();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
        
        // Beep alert or double vibration every second
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
      } else {
        // Countdown reached 0 -> Trigger SOS automatically
        timer.cancel();
        _confirmSOS();
      }
    });
  }

  // Dismiss fall warning
  void _dismissFall() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountdownActive = false;
      _statusText = "Monitoring Safety...";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Alert Cancelled. Glad you are okay!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Trigger SOS flow
  Future<void> _confirmSOS() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DbService>(context, listen: false);
    final profile = auth.currentProfile;

    if (profile == null) return;
    
    setState(() {
      _isSosTriggering = true;
      _statusText = "TRIGGERING SOS ALERT...";
      _isCountdownActive = false;
    });
    _countdownTimer?.cancel();

    debugPrint("SOS triggered for ${profile.fullName}!");

    double? latitude;
    double? longitude;

    // 1. Fetch GPS Location
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }
    } catch (e) {
      debugPrint("Error fetching GPS location: $e");
    }

    // 2. Insert SOS event and call send-sms Edge Function
    await db.triggerSOSEvent(
      profileId: profile.id,
      latitude: latitude,
      longitude: longitude,
    );

    // 3. Place Phone Call to caregiver/emergency contact
    final contactNumber = profile.sosContactPhone;
    if (contactNumber != null && contactNumber.isNotEmpty) {
      final phoneUri = Uri.parse("tel:$contactNumber");
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    }

    setState(() {
      _isSosTriggering = false;
      _statusText = "Alert Dispatched to Family!";
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final profile = auth.currentProfile;

    // Force high-contrast light theme colors
    const Color background = Color(0xFFF4F6FA); // Matching light blue-grey background
    const Color textDark = Color(0xFF1F2937);
    const Color primaryButton = Color(0xFFFF3333); // Sharp red for SOS

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: background,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "MedAayu Elder Safe",
            style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 24),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: textDark, size: 28),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
              onPressed: () {
                auth.signOut();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _isCountdownActive
                ? _buildCountdownOverlay(primaryButton, textDark)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Elder profile indicator
                      Card(
                        color: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                profile?.fullName ?? "Elder Profile",
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statusText,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      
                      const Spacer(),

                      // PERSISTENT SOS BUTTON
                      GestureDetector(
                        onLongPress: _confirmSOS, // Trigger on long press or simple click
                        onTap: _confirmSOS,
                        child: Container(
                          height: 220,
                          width: 220,
                          decoration: BoxDecoration(
                            color: primaryButton,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryButton.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 8,
                              )
                            ],
                            border: Border.all(color: Colors.white, width: 8),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white),
                                SizedBox(height: 8),
                                Text(
                                  "EMERGENCY\nSOS",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const Spacer(),

                      // Fall detection notification indicator (Foreground limitation notice)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline, color: Colors.blueAccent),
                                SizedBox(width: 8),
                                Text(
                                  "Fall Detection Engine Active",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Notice: Keep this screen open in the foreground for active fall monitoring.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay(Color alertColor, Color textDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: alertColor, width: 6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.directions_run_rounded, size: 80, color: alertColor),
          const SizedBox(height: 24),
          const Text(
            "Fall Detected!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.red),
          ),
          const SizedBox(height: 12),
          const Text(
            "Are you okay?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 32),
          
          // Large countdown number
          Text(
            "$_countdownSeconds",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: alertColor),
          ),
          const SizedBox(height: 8),
          const Text(
            "SOS will trigger automatically if you do not respond.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          
          const Spacer(),

          // Big "I'm Okay" cancellation button
          ElevatedButton(
            onPressed: _dismissFall,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
            ),
            child: const Text(
              "I AM OKAY",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
