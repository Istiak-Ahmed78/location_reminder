import 'package:equatable/equatable.dart';

/// Events for ETA BLoC
abstract class ETAEvent extends Equatable {
  const ETAEvent();

  @override
  List<Object?> get props => [];
}

/// Start calculating ETA for a destination
class ETACalculationStarted extends ETAEvent {
  final double destinationLat;
  final double destinationLon;

  const ETACalculationStarted({
    required this.destinationLat,
    required this.destinationLon,
  });

  @override
  List<Object?> get props => [destinationLat, destinationLon];
}

/// Update ETA with new location data
class ETALocationUpdated extends ETAEvent {
  final double currentLat;
  final double currentLon;
  final double? speed; // m/s
  final double distance; // meters

  const ETALocationUpdated({
    required this.currentLat,
    required this.currentLon,
    this.speed,
    required this.distance,
  });

  @override
  List<Object?> get props => [currentLat, currentLon, speed, distance];
}

/// Request API refresh (manual or automatic)
class ETAAPIRefreshRequested extends ETAEvent {
  final bool isAutomatic; // true for automatic, false for manual user request

  const ETAAPIRefreshRequested({this.isAutomatic = true});

  @override
  List<Object?> get props => [isAutomatic];
}

/// Stop ETA calculation
class ETACalculationStopped extends ETAEvent {
  const ETACalculationStopped();
}

/// Reset ETA state
class ETAResetRequested extends ETAEvent {
  const ETAResetRequested();
}
