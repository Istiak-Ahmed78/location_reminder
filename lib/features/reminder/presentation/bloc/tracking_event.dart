part of 'tracking_bloc.dart';

abstract class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object?> get props => [];
}

class TrackingStarted extends TrackingEvent {
  const TrackingStarted();
}

class TrackingStartedForLocationOnly extends TrackingEvent {
  const TrackingStartedForLocationOnly();
}

class TrackingStopped extends TrackingEvent {
  final String? error;
  const TrackingStopped({this.error});

  @override
  List<Object?> get props => [error];
}

class _TrackingLocationUpdated extends TrackingEvent {
  final UserLocation location;
  const _TrackingLocationUpdated(this.location);

  @override
  List<Object> get props => [location];
}

class TrackingSettingsAdjusted extends TrackingEvent {
  final double distanceFilter;
  final LocationAccuracy accuracy;

  const TrackingSettingsAdjusted({
    required this.distanceFilter,
    required this.accuracy,
  });

  @override
  List<Object> get props => [distanceFilter, accuracy];
}

// ✅ NEW: Service status events
class _TrackingServiceEnabled extends TrackingEvent {
  const _TrackingServiceEnabled();
}

class _TrackingServiceDisabled extends TrackingEvent {
  const _TrackingServiceDisabled();
}
