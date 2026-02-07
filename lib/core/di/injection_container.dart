import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:location_reminder/core/notifications/local_notifications_service.dart';
import 'package:location_reminder/core/notifications/notification_permission_bloc.dart';
import 'package:location_reminder/features/reminder/domain/usecases/get_last_cached_location.dart';
import 'package:location_reminder/features/reminder/domain/usecases/save_active_reminder.dart';
import 'package:location_reminder/features/reminder/domain/usecases/watch_position.dart';
import 'package:location_reminder/features/reminder/presentation/bloc/tracking_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Location imports
import '../../features/reminder/data/datasources/location_datasource.dart';
import '../../features/reminder/data/datasources/location_local_datasource.dart';
import '../../features/reminder/data/repositories/location_repository_impl.dart';
import '../../features/reminder/domain/repositories/location_repository.dart';
import '../../features/reminder/domain/usecases/ensure_location_permission.dart';
import '../../features/reminder/domain/usecases/get_current_location.dart';
import '../../features/reminder/presentation/bloc/location_bloc.dart';

// Reminder imports
import '../../features/reminder/data/datasources/reminder_local_datasource.dart';
import '../../features/reminder/data/repositories/reminder_repository_impl.dart';
import '../../features/reminder/domain/repositories/reminder_repository.dart';
import '../../features/reminder/domain/usecases/clear_active_reminder.dart';
import '../../features/reminder/domain/usecases/get_active_reminder.dart';
import '../../features/reminder/presentation/bloc/reminder_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ========== Core ==========
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);

  // ========== Location Feature ==========

  // Data sources
  sl.registerLazySingleton<LocationDataSource>(
    () => GeolocatorLocationDataSource(),
  );

  sl.registerLazySingleton<LocationLocalDataSource>(
    () => SharedPreferencesLocationDataSource(sl()),
  );

  // Repository
  sl.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(
      sl(), // LocationDataSource
      sl(), // LocationLocalDataSource
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => EnsureLocationPermission(sl()));
  sl.registerLazySingleton(() => GetCurrentLocation(sl()));
  sl.registerLazySingleton(() => WatchPosition(sl()));
  sl.registerLazySingleton(() => GetLastCachedLocation(sl()));

  // Bloc
  sl.registerFactory(
    () => LocationBloc(ensurePermission: sl(), getCurrentLocation: sl()),
  );

  // ========== Reminder Feature ==========

  // Data source
  sl.registerLazySingleton<ReminderLocalDataSource>(
    () => ReminderLocalDataSourceImpl(sl()),
  );

  // Repository
  sl.registerLazySingleton<ReminderRepository>(
    () => ReminderRepositoryImpl(localDataSource: sl()), // ← FIXED
  );

  // Use cases
  sl.registerLazySingleton(() => SaveActiveReminder(sl()));
  sl.registerLazySingleton(() => GetActiveReminder(sl()));
  sl.registerLazySingleton(() => ClearActiveReminder(sl()));

  // Bloc
  sl.registerFactory(
    () => ReminderBloc(
      saveActiveReminder: sl(),
      getActiveReminder: sl(),
      clearActiveReminder: sl(),
    ),
  );

  // ========== Tracking Bloc ==========
  sl.registerFactory(
    () => TrackingBloc(
      watchPosition: sl(),
      getActiveReminder: sl(),
      notifications: sl(),
      getLastCachedLocation: sl(),
    ),
  );

  // ========== Notifications ==========
  sl.registerLazySingleton(() => FlutterLocalNotificationsPlugin());
  sl.registerLazySingleton(() => LocalNotificationsService(sl()));

  // Initialize notifications (must be awaited)
  await sl<LocalNotificationsService>().init();

  // Notification permission bloc
  sl.registerFactory(() => NotificationPermissionBloc());
}
