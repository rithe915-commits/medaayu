import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medicine.dart';
import '../models/profile.dart';
import '../services/translation.dart';

// ================= DESIGN CONSTANTS =================
class DesignSystem {
  static const double cornerRadiusVal = 16.0;
  static final BorderRadius borderRadius = BorderRadius.circular(cornerRadiusVal);

  // Spacing Tokens
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);

  // Premium Shadows
  static List<BoxShadow> premiumShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.015),
        blurRadius: 10,
        offset: const Offset(0, 4),
      )
    ];
  }

  // Darkened Secondary Color to guarantee contrast
  static Color secondaryTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white70 : const Color(0xFF555555);
  }

  static InputDecoration premiumInputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.black45, fontSize: 13),
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3A86F0), width: 1.5),
      ),
    );
  }

  static void showSuccessOverlay(BuildContext context, String message) {
    HapticFeedback.mediumImpact();
    
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 48),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1200), () {
      entry.remove();
    });
  }

  // Primary Theme definitions
  static ThemeData lightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3A86F0),
      brightness: Brightness.light,
      primary: const Color(0xFF3A86F0),
      secondary: const Color(0xFF2E7D32),
      background: const Color(0xFFF8FAFC),
      surface: Colors.white,
    );
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1F2937)),
        bodyLarge: TextStyle(color: Color(0xFF1F2937)),
        bodyMedium: TextStyle(color: Color(0xFF1F2937)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          minimumSize: const Size(88, 48), // min 48dp touch target
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF3A86F0).withOpacity(0.12),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3A86F0),
      brightness: Brightness.dark,
      primary: const Color(0xFF3A86F0),
      secondary: const Color(0xFF4CAF50),
      background: const Color(0xFF121212),
      surface: const Color(0xFF1E1E1E),
    );
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: const Color(0xFF3A86F0).withOpacity(0.24),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

// ================= REUSABLE DESIGN SYSTEM WIDGETS =================

/// A clean Material 3 card container
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderSide? borderSide;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(DesignSystem.space16),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardTheme.color,
        borderRadius: DesignSystem.borderRadius,
        border: Border.all(
          color: borderSide?.color ?? Colors.black.withOpacity(0.04),
          width: borderSide?.width ?? 1.0,
        ),
        boxShadow: DesignSystem.premiumShadow(context),
      ),
      child: child,
    );
  }
}

/// Primary Material 3 action button
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}

/// Secondary action button
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );
    }
    return FilledButton.tonal(
      onPressed: onPressed,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}

/// Status tag badge (Taken, Active, Premium)
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// Section headers
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DesignSystem.space24, bottom: DesignSystem.space12, left: DesignSystem.space4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.black54,
                ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ]
        ],
      ),
    );
  }
}

/// A pulsing skeleton loading block
class SkeletonCard extends StatefulWidget {
  final double height;
  final double? width;
  final double? radius;

  const SkeletonCard({
    super.key,
    required this.height,
    this.width,
    this.radius,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _animation,
      child: Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(widget.radius ?? DesignSystem.cornerRadiusVal),
        ),
      ),
    );
  }
}

/// The visual centerpiece of the Home screen showing the next medicine
class ReminderBanner extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onTakeNow;
  final String userLanguage;

  const ReminderBanner({
    super.key,
    required this.medicine,
    required this.onTakeNow,
    required this.userLanguage,
  });

  @override
  Widget build(BuildContext context) {
    Color medColor = const Color(0xFF3A86F0);
    if (medicine.color != null && medicine.color!.isNotEmpty) {
      try {
        medColor = Color(int.parse(medicine.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(DesignSystem.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            medColor,
            medColor.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignSystem.borderRadius,
        boxShadow: [
          BoxShadow(
            color: medColor.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.alarm_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                "NEXT REMINDER".toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            medicine.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                medicine.doseTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Text("•", style: TextStyle(color: Colors.white54)),
              const SizedBox(width: 8),
              Text(
                TranslationService.getTranslation(userLanguage, medicine.foodInstruction),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (medicine.pillsLeft != null) ...[
                const SizedBox(width: 8),
                const Text("•", style: TextStyle(color: Colors.white54)),
                const SizedBox(width: 8),
                Text(
                  "${medicine.pillsLeft} tablets left",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTakeNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: medColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              "TAKE NOW",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A premium visual medicine schedule tile
class MedicineTile extends StatelessWidget {
  final Medicine medicine;
  final bool isTaken;
  final VoidCallback onTap;
  final String userLanguage;
  final bool reminderDone;
  final String? reminderChannel;

  const MedicineTile({
    super.key,
    required this.medicine,
    required this.isTaken,
    required this.onTap,
    required this.userLanguage,
    this.reminderDone = false,
    this.reminderChannel,
  });

  @override
  Widget build(BuildContext context) {
    Color medColor = const Color(0xFF3A86F0);
    if (medicine.color != null && medicine.color!.isNotEmpty) {
      try {
        medColor = Color(int.parse(medicine.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(DesignSystem.space16),
      child: Row(
        children: [
          // Color indicator with pill icon representation
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: medColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTaken ? Icons.check_rounded : Icons.medication_rounded,
              color: isTaken ? const Color(0xFF2E7D32) : medColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1F2937),
                    decoration: isTaken ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${medicine.form} • ${TranslationService.getTranslation(userLanguage, medicine.foodInstruction)}",
                  style: TextStyle(fontSize: 13, color: DesignSystem.secondaryTextColor(context)),
                ),
                if (medicine.pillsLeft != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "${medicine.pillsLeft} tablets left",
                    style: TextStyle(
                      fontSize: 12,
                      color: medicine.pillsLeft! <= 5 ? Colors.redAccent : DesignSystem.secondaryTextColor(context),
                      fontWeight: medicine.pillsLeft! <= 5 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
                if (reminderDone && reminderChannel != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        reminderChannel == 'local_alarm'
                            ? Icons.notifications_active_rounded
                            : Icons.phone_callback_rounded,
                        size: 12,
                        color: const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        TranslationService.getTranslation(
                          userLanguage,
                          reminderChannel == 'local_alarm'
                              ? 'local_alarm_done'
                              : 'tts_call_done',
                        ),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isTaken)
            const StatusBadge(text: "TAKEN", color: Color(0xFF2E7D32), icon: Icons.check_circle_rounded)
          else ...[
            Text(
              medicine.doseTime,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: medColor),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: medColor.withOpacity(0.08),
                  foregroundColor: medColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Take", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom branded empty state layout
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onActionPressed;
  final String buttonText;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onActionPressed,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Branded illustration vector (Pill bottle + calendar + bell representation)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3A86F0).withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.medication_rounded, size: 64, color: Color(0xFF3A86F0)),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_active_rounded, size: 20, color: Colors.amber),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.calendar_month_rounded, size: 18, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: DesignSystem.secondaryTextColor(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: buttonText,
            onPressed: onActionPressed,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }
}

/// A premium list tile row inside the profile switcher
class ProfileTile extends StatelessWidget {
  final Profile profile;
  final bool isSelected;
  final VoidCallback onTap;

  const ProfileTile({
    super.key,
    required this.profile,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = profile.fullName.isNotEmpty ? profile.fullName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase() : '?';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF3A86F0).withOpacity(0.04) : Colors.white,
        borderRadius: DesignSystem.borderRadius,
        border: Border.all(
          color: isSelected ? const Color(0xFF3A86F0) : Colors.black.withOpacity(0.05),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Hero(
          tag: 'avatar_${profile.id}',
          child: CircleAvatar(
            radius: 22,
            backgroundColor: isSelected ? const Color(0xFF3A86F0) : const Color(0xFF2E7D32),
            child: Text(
              initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              profile.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
            ),
            const SizedBox(width: 8),
            if (profile.planTier == PlanTier.premium)
              const StatusBadge(text: "Premium", color: Colors.amber, icon: Icons.star_rounded)
            else
              const StatusBadge(text: "Basic", color: Colors.blueGrey),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    profile.role == UserRole.self ? "Self" : (profile.relationship ?? "Parent"),
                    style: TextStyle(fontSize: 13, color: DesignSystem.secondaryTextColor(context), fontWeight: FontWeight.w600),
                  ),
                  if (profile.age != null) ...[
                    const SizedBox(width: 6),
                    const Text("•"),
                    const SizedBox(width: 6),
                    Text(
                      "${profile.age} yrs",
                      style: TextStyle(fontSize: 13, color: DesignSystem.secondaryTextColor(context)),
                    ),
                  ],
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 2),
                const Text(
                  "Current Profile",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3A86F0)),
                ),
              ],
            ],
          ),
        ),
        trailing: isSelected 
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF3A86F0), size: 24)
            : const Icon(Icons.radio_button_off_rounded, color: Colors.black26, size: 24),
        onTap: onTap,
      ),
    );
  }
}

/// A premium card to display AI health tips with expandable animation
class ExpandableTipCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;

  const ExpandableTipCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
  });

  @override
  State<ExpandableTipCard> createState() => _ExpandableTipCardState();
}

class _ExpandableTipCardState extends State<ExpandableTipCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(DesignSystem.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                    ),
                  ),
                  Text(
                    _isExpanded ? "Show Less" : "Read More >",
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 40.0),
              child: Text(
                widget.description,
                style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: DesignSystem.animNormal,
          ),
        ],
      ),
    );
  }
}

enum StatusType { active, premium, basic, completed, pending, missed }

class StatusChip extends StatelessWidget {
  final StatusType type;
  final String? customText;

  const StatusChip({super.key, required this.type, this.customText});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    switch (type) {
      case StatusType.active:
        color = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        text = customText ?? "Active";
        break;
      case StatusType.premium:
        color = const Color(0xFFFFAA00);
        icon = Icons.star_rounded;
        text = customText ?? "Premium Plan";
        break;
      case StatusType.basic:
        color = Colors.black45;
        icon = Icons.person_outline_rounded;
        text = customText ?? "Basic Plan";
        break;
      case StatusType.completed:
        color = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        text = customText ?? "Completed";
        break;
      case StatusType.pending:
        color = const Color(0xFF3A86F0);
        icon = Icons.watch_later_rounded;
        text = customText ?? "Pending";
        break;
      case StatusType.missed:
        color = Colors.redAccent;
        icon = Icons.cancel_rounded;
        text = customText ?? "Missed";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
