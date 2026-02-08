import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ← Add this import
import 'package:location_reminder/core/di/injection_container.dart' as di;
import 'package:location_reminder/features/reminder/presentation/bloc/reminder_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/tracking_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/pages/home_page.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file (ADD THIS LINE)
  await dotenv.load(fileName: ".env");

  await di.initDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ReminderBloc>(create: (context) => di.sl<ReminderBloc>()),
        BlocProvider<TrackingBloc>(create: (context) => di.sl<TrackingBloc>()),
        BlocProvider<ETABloc>(
          create: (context) => di.sl<ETABloc>(),
        ), // ← Add this
      ],
      child: MaterialApp(
        title: 'Location Reminder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
