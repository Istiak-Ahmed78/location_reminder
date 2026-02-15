import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:location_reminder/core/notifications/notification_permission_bloc.dart';
import 'package:location_reminder/features/reminder/data/datasources/location_datasource.dart';
import 'package:location_reminder/features/reminder/data/datasources/location_local_datasource.dart';
import 'package:location_reminder/features/reminder/data/repositories/location_repository_impl.dart';
import 'package:location_reminder/features/reminder/data/services/openrouteservice_client.dart';
import 'package:location_reminder/features/reminder/domain/repositories/location_repository.dart';
import 'package:location_reminder/features/reminder/domain/usecases/ensure_location_permission.dart';
import 'package:location_reminder/features/reminder/domain/usecases/get_current_location.dart';
import 'package:location_reminder/features/reminder/domain/usecases/watch_position.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/location_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Core
import 'package:location_reminder/core/background/background_location_service.dart';
import 'package:location_reminder/core/background/foreground_location_service.dart';
import 'package:location_reminder/core/notifications/local_notifications_service.dart';
import 'package:location_reminder/core/notifications/alarm_service.dart';

// Reminder Feature
import 'package:location_reminder/features/reminder/data/datasources/reminder_local_datasource.dart';
import 'package:location_reminder/features/reminder/data/repositories/reminder_repository_impl.dart';
import 'package:location_reminder/features/reminder/domain/repositories/reminder_repository.dart';
import 'package:location_reminder/features/reminder/domain/usecases/clear_active_reminder.dart';
import 'package:location_reminder/features/reminder/domain/usecases/get_active_reminder.dart';
import 'package:location_reminder/features/reminder/domain/usecases/get_last_cached_location.dart';
import 'package:location_reminder/features/reminder/domain/usecases/save_active_reminder.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/reminder_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/tracking_bloc.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/eta_bloc.dart';

// ETA Feature
import 'package:location_reminder/features/reminder/data/services/eta_cache_service.dart';
import 'package:location_reminder/features/reminder/domain/usecases/calculate_local_eta.dart';
import 'package:location_reminder/features/reminder/domain/usecases/fetch_api_eta.dart';
import 'package:location_reminder/features/reminder/domain/usecases/get_blended_eta.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  print('🔧 Initializing dependencies...');

  // ========== Core Services ==========
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);
  print('✅ SharedPreferences registered');

  // HTTP Client (for API calls)
  sl.registerLazySingleton(() => http.Client());
  print('✅ HTTP Client registered');

  // ========== Notifications & Alarms ==========
  sl.registerLazySingleton(() => FlutterLocalNotificationsPlugin());
  print('✅ FlutterLocalNotificationsPlugin registered');

  sl.registerLazySingleton(() => LocalNotificationsService(sl()));
  print('✅ LocalNotificationsService registered');

  sl.registerLazySingleton(() => AlarmService(sl()));
  print('✅ AlarmService registered');

  // Initialize notification services
  await sl<LocalNotificationsService>().init();
  print('✅ LocalNotificationsService initialized');

  await sl<AlarmService>().init();
  print('✅ AlarmService initialized');

  // ========== Background Services ==========
  sl.registerLazySingleton<BackgroundLocationService>(
    () => BackgroundLocationService(sl()),
  );
  print('✅ BackgroundLocationService registered');

  sl.registerLazySingleton<ForegroundLocationService>(
    () => ForegroundLocationService(),
  );
  print('✅ ForegroundLocationService registered');

  // ========== Location Feature ==========
  // Data sources
  sl.registerLazySingleton<LocationDataSource>(
    () => GeolocatorLocationDataSource(),
  );
  print('✅ LocationDataSource registered');

  sl.registerLazySingleton<LocationLocalDataSource>(
    () => SharedPreferencesLocationDataSource(sl()),
  );
  print('✅ LocationLocalDataSource registered');

  // Repository
  sl.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(sl(), sl()),
  );
  print('✅ LocationRepository registered');

  // Use cases
  sl.registerLazySingleton(() => EnsureLocationPermission(sl()));
  sl.registerLazySingleton(() => GetCurrentLocation(sl()));
  sl.registerLazySingleton(() => WatchPosition(sl()));
  sl.registerLazySingleton(() => GetLastCachedLocation(sl()));
  print('✅ Location use cases registered');

  // Bloc
  sl.registerFactory(
    () => LocationBloc(ensurePermission: sl(), getCurrentLocation: sl()),
  );
  print('✅ LocationBloc registered');

  // ========== Reminder Feature ==========
  // Data source
  sl.registerLazySingleton<ReminderLocalDataSource>(
    () => ReminderLocalDataSourceImpl(sl()),
  );
  print('✅ ReminderLocalDataSource registered');

  // Repository
  sl.registerLazySingleton<ReminderRepository>(
    () => ReminderRepositoryImpl(localDataSource: sl()),
  );
  print('✅ ReminderRepository registered');

  // Use cases
  sl.registerLazySingleton(() => SaveActiveReminder(sl()));
  sl.registerLazySingleton(() => GetActiveReminder(sl()));
  sl.registerLazySingleton(() => ClearActiveReminder(sl()));
  print('✅ Reminder use cases registered');

  // Bloc
  sl.registerFactory(
    () => ReminderBloc(
      saveActiveReminder: sl(),
      getActiveReminder: sl(),
      clearActiveReminder: sl(),
    ),
  );
  print('✅ ReminderBloc registered');

  // ========== ETA Feature ==========
  // OpenRouteService client
  sl.registerLazySingleton(
    () => OpenRouteServiceClient(
      apiKey: dotenv.env['OPENROUTE_API_KEY'] ?? '',
      httpClient: sl(),
    ),
  );
  print('✅ OpenRouteServiceClient registered');

  // ETA cache service
  sl.registerLazySingleton(() => ETACacheService(sl()));
  print('✅ ETACacheService registered');

  // Use Cases
  sl.registerLazySingleton(() => CalculateLocalETA());
  sl.registerLazySingleton(
    () => FetchAPIETA(apiClient: sl(), cacheService: sl()),
  );
  sl.registerLazySingleton(() => GetBlendedETA());
  print('✅ ETA use cases registered');

  // ETABloc (SINGLETON - very important!)
  sl.registerLazySingleton<ETABloc>(
    () => ETABloc(
      calculateLocalETA: sl(),
      fetchAPIETA: sl(),
      getBlendedETA: sl(),
      cacheService: sl(),
    ),
  );
  print('✅ ETABloc registered as SINGLETON');

  // ========== TrackingBloc ==========
  sl.registerFactory(
    () => TrackingBloc(
      watchPosition: sl(),
      getActiveReminder: sl(),
      notifications: sl(),
      alarmService: sl(), // ← AlarmService dependency
      getLastCachedLocation: sl(),
      etaBloc: sl(),
      backgroundService: sl(),
      foregroundService: sl(),
    ),
  );
  print('✅ TrackingBloc registered');

  // ========== Notification Permission ==========
  sl.registerFactory(() => NotificationPermissionBloc());
  print('✅ NotificationPermissionBloc registered');

  print('🎉 All dependencies initialized successfully!');
}
