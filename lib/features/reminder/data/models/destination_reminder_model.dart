import 'dart:convert';

import '../../domain/entities/destination_reminder.dart';

/// Data model for [DestinationReminder] with JSON serialization
class DestinationReminderModel extends DestinationReminder {
  const DestinationReminderModel({
    required super.id,
    required super.label,
    required super.latitude,
    required super.longitude,
    required super.triggerDistanceMeters,
    required super.createdAt,
    required super.isActive,
  });

  /// Creates model from entity
  factory DestinationReminderModel.fromEntity(DestinationReminder entity) {
    return DestinationReminderModel(
      id: entity.id,
      label: entity.label,
      latitude: entity.latitude,
      longitude: entity.longitude,
      triggerDistanceMeters: entity.triggerDistanceMeters,
      createdAt: entity.createdAt,
      isActive: entity.isActive,
    );
  }

  /// Creates model from JSON map
  factory DestinationReminderModel.fromJson(Map<String, dynamic> json) {
    return DestinationReminderModel(
      id: json['id'] as String,
      label: json['label'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      triggerDistanceMeters: (json['triggerDistanceMeters'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool,
    );
  }

  /// Creates model from JSON string
  factory DestinationReminderModel.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return DestinationReminderModel.fromJson(json);
  }

  /// Converts model to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'triggerDistanceMeters': triggerDistanceMeters,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Converts model to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
