import 'package:equatable/equatable.dart';

class UserLocation extends Equatable {
  final double latitude;
  final double longitude;
  final double? accuracy; // meters
  final DateTime timestamp;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  @override
  List<Object?> get props => [latitude, longitude, accuracy, timestamp];
}
