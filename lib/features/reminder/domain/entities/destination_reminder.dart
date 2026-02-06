import 'package:equatable/equatable.dart';

class DestinationReminder extends Equatable {
  final String label;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const DestinationReminder({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  @override
  List<Object?> get props => [label, latitude, longitude, radiusMeters];
}
