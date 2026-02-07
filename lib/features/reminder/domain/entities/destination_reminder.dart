import 'package:equatable/equatable.dart';

class DestinationReminder extends Equatable {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final double triggerDistanceMeters;
  final DateTime createdAt;
  final bool isActive;

  const DestinationReminder({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.triggerDistanceMeters,
    required this.createdAt,
    required this.isActive,
  });

  @override
  List<Object?> get props => [
    id,
    label,
    latitude,
    longitude,
    triggerDistanceMeters,
    createdAt,
    isActive,
  ];

  /// Creates a copy with updated fields
  DestinationReminder copyWith({
    String? id,
    String? label,
    double? latitude,
    double? longitude,
    double? triggerDistanceMeters,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return DestinationReminder(
      id: id ?? this.id,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      triggerDistanceMeters:
          triggerDistanceMeters ?? this.triggerDistanceMeters,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
