part of 'tracking_bloc.dart';

enum TrackingStatus { initial, idle, loading, tracking, failure }

class TrackingSettings extends Equatable {
  final double distanceFilter;
  final String accuracy;
  final DateTime lastUpdated;

  const TrackingSettings({
    required this.distanceFilter,
    required this.accuracy,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [distanceFilter, accuracy, lastUpdated];
}

class TrackingState extends Equatable {
  final TrackingStatus status;
  final DestinationReminder? activeReminder;
  final UserLocation? current;
  final double? distanceMeters;
  final bool? insideRadius;
  final bool triggered;
  final String? errorMessage;
  final TrackingSettings? trackingSettings;
  final bool isLive;

  const TrackingState({
    required this.status,
    this.activeReminder,
    this.current,
    this.distanceMeters,
    this.insideRadius,
    required this.triggered,
    this.errorMessage,
    this.trackingSettings,
    this.isLive = false,
  });

  const TrackingState.initial()
    : status = TrackingStatus.initial,
      activeReminder = null,
      current = null,
      distanceMeters = null,
      insideRadius = null,
      triggered = false,
      isLive = false,
      errorMessage = null,
      trackingSettings = null;

  TrackingState copyWith({
    TrackingStatus? status,
    DestinationReminder? activeReminder,
    UserLocation? current,
    double? distanceMeters,
    bool? insideRadius,
    bool? triggered,
    bool? isLive,
    String? errorMessage,
    TrackingSettings? trackingSettings,
    bool clearErrorMessage = false,
  }) {
    return TrackingState(
      status: status ?? this.status,
      activeReminder: activeReminder ?? this.activeReminder,
      current: current ?? this.current,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      insideRadius: insideRadius ?? this.insideRadius,
      triggered: triggered ?? this.triggered,
      isLive: isLive ?? this.isLive,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      trackingSettings: trackingSettings ?? this.trackingSettings,
    );
  }

  @override
  List<Object?> get props => [
    status,
    activeReminder,
    current,
    distanceMeters,
    insideRadius,
    triggered,
    isLive,
    errorMessage,
    trackingSettings,
  ];
}
