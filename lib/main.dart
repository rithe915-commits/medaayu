import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'services/billing_service.dart';
import 'services/alarm_service.dart';
import 'models/profile.dart';
import 'theme/design_system.dart';
import 'views/onboarding_view.dart';
import 'views/dashboard_view.dart';
import 'views/elder_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase Client
  // Replace these with your actual Supabase Project Credentials.
  // We use fallbacks so the app compiles and launches immediately in local/development mode.
  const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ttndxxmtetfnwayrjucr.supabase.co',
  );
  const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_0LkJnr6s1jWdrCIiHPYoIw_RD-oD73i',
  );

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint("Supabase Initialization Error (using local sandbox defaults): $e");
  }

  // 2. Initialize exact alarms service (Basic Tier)
  try {
    await AlarmService.initialize();
    await AlarmService.requestPermissions();
  } catch (e) {
    debugPrint("Alarm Service Initialization Error: $e");
  }

  runApp(const MedAayuApp());
}

class MedAayuApp extends StatelessWidget {
  const MedAayuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<DbService>(
          create: (_) => DbService(),
        ),
        ChangeNotifierProxyProvider<AuthService, BillingService>(
          create: (context) => BillingService(Provider.of<AuthService>(context, listen: false)),
          update: (context, authService, previousBilling) => BillingService(authService),
        ),
      ],
      child: MaterialApp(
        title: 'MedAayu',
        debugShowCheckedModeBanner: false,
        theme: DesignSystem.lightTheme(),
        darkTheme: DesignSystem.darkTheme(),
        themeMode: ThemeMode.light,
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthGateRoute(),
          '/onboarding': (context) => const OnboardingView(),
          '/dashboard': (context) => const DashboardView(),
          '/elder': (context) => const ElderView(),
        },
      ),
    );
  }
}

// Router Gate deciding between Dashboard and Onboarding based on Authentication State
class AuthGateRoute extends StatefulWidget {
  const AuthGateRoute({super.key});

  @override
  State<AuthGateRoute> createState() => _AuthGateRouteState();
}

class _AuthGateRouteState extends State<AuthGateRoute> {
  static const MethodChannel _channel = MethodChannel("com.medaayu.medaayu/sos_widget");

  @override
  void initState() {
    super.initState();
    _checkWidgetLaunch();
    
    // Listen for widget clicks while app is in background (warm start)
    _channel.setMethodCallHandler((call) async {
      if (call.method == "triggerSosFromWidget") {
        Navigator.pushNamed(context, '/elder');
      }
    });
  }

  Future<void> _checkWidgetLaunch() async {
    try {
      final bool launchFromSosWidget = await _channel.invokeMethod('checkLaunchNotification') ?? false;
      if (launchFromSosWidget && mounted) {
        // Immediately navigate to simplified Elder SOS screen bypassing standard logins
        Navigator.pushNamed(context, '/elder');
      }
    } catch (e) {
      debugPrint("Error checking widget launch: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (!auth.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6FA),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3A86F0)),
        ),
      );
    }

    if (auth.isAuthenticated && auth.currentProfile != null) {
      // If user is authenticated AND profile is fetched, load appropriate Dashboard
      if (auth.currentProfile!.role == UserRole.parent && auth.currentUserId == auth.currentProfile!.id) {
        return const ElderView();
      }
      return const DashboardView();
    }

    // Default to signup/onboarding phone entry page
    return const OnboardingView();
  }
}
