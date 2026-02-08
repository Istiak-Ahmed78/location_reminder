import 'package:equatable/equatable.dart';

/// Represents a user's location with metadata
class UserLocation extends Equatable {
  final double latitude;
  final double longitude;
  final double? speed; // m/s
  final double? accuracy; // meters
  final double? heading; // degrees (0-360)
  final DateTime timestamp;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.accuracy,
    this.heading,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    speed,
    accuracy,
    heading,
    timestamp,
  ];

  UserLocation copyWith({
    double? latitude,
    double? longitude,
    double? speed,
    double? accuracy,
    double? heading,
    DateTime? timestamp,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
