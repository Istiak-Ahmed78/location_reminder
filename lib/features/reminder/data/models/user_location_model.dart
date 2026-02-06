import 'dart:convert';
import '../../domain/entities/user_location.dart';

class UserLocationModel extends UserLocation {
  const UserLocationModel({
    required super.latitude,
    required super.longitude,
    required super.timestamp,
    super.accuracy,
  });

  // Factory: Create model from entity
  factory UserLocationModel.fromEntity(UserLocation location) {
    return UserLocationModel(
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: location.timestamp,
      accuracy: location.accuracy,
    );
  }

  // Factory: Create model from JSON
  factory UserLocationModel.fromJson(Map<String, dynamic> json) {
    return UserLocationModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
    );
  }

  // Convert model to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
    };
  }

  // Helper: Parse from JSON string
  static UserLocationModel fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return UserLocationModel.fromJson(json);
  }

  // Helper: Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
