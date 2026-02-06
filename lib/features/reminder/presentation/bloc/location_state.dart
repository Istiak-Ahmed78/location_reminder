part of 'location_bloc.dart';

enum LocationStatus { initial, loading, success, failure }

class LocationState extends Equatable {
  final LocationStatus status;
  final UserLocation? location;
  final String? errorMessage;

  const LocationState({required this.status, this.location, this.errorMessage});

  const LocationState.initial()
    : status = LocationStatus.initial,
      location = null,
      errorMessage = null;

  LocationState copyWith({
    LocationStatus? status,
    UserLocation? location,
    String? errorMessage,
  }) {
    return LocationState(
      status: status ?? this.status,
      location: location ?? this.location,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, location, errorMessage];
}
