import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:alarm/alarm.dart';
import 'package:location_reminder/core/di/injection_container.dart' as di;
import 'package:location_reminder/features/reminder/presentation/bloc/reminder_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/tracking_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/pages/home_page.dart';
import 'package:location_reminder/features/reminder/presentation/pages/alarm_screen.dart';

// Global navigator key for navigation from background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize alarm system
  await Alarm.init();

  // Initialize dependency injection
  await di.initDependencies();

  // Listen for alarm ring events
  _setupAlarmListener();

  runApp(const MyApp());
}

/// Setup alarm listener to show alarm screen when alarm rings
void _setupAlarmListener() {
  Alarm.ringStream.stream.listen((alarmSettings) {
    print('🚨 Alarm triggered: ${alarmSettings.id}');

    // Parse destination name and distance from notification
    final title = alarmSettings.notificationSettings?.title ?? 'Destination';
    final body = alarmSettings.notificationSettings?.body ?? '';

    // Extract distance from body (format: "You are 50m from your destination!")
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(body);
    final distance = distanceMatch != null
        ? double.tryParse(distanceMatch.group(1) ?? '0') ?? 0.0
        : 0.0;

    // Extract destination name (format: "🚨 ARRIVED AT Home")
    final destinationName = title.replaceAll('🚨 ARRIVED AT ', '').trim();

    // Navigate to alarm screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) =>
            AlarmScreen(destinationName: destinationName, distance: distance),
        fullscreenDialog: true,
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🏗️ MyApp: Starting app...');

    return MultiBlocProvider(
      providers: [
        BlocProvider<ReminderBloc>(
          create: (context) {
            print('🏗️ Creating ReminderBloc');
            return di.sl<ReminderBloc>();
          },
        ),
        BlocProvider<TrackingBloc>(
          create: (context) {
            print('🏗️ Creating TrackingBloc');
            return di.sl<TrackingBloc>();
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // ← IMPORTANT: Add global navigator key
        title: 'Location Reminder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,

          // Custom theme for alarm screen
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          // Elevated button theme
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Card theme
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        home: const HomePage(),

        // Handle routes for deep linking (optional)
        routes: {
          '/alarm': (context) =>
              const AlarmScreen(destinationName: 'Destination', distance: 0),
        },

        // Handle unknown routes
        onUnknownRoute: (settings) {
          return MaterialPageRoute(builder: (context) => const HomePage());
        },
      ),
    );
  }
}
