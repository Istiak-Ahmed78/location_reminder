import 'package:equatable/equatable.dart';
import 'package:location_reminder/features/reminder/domain/entities/eta_result.dart';

/// Represents the current state of ETA calculation
class ETAState extends Equatable {
  /// Current ETA result (null if not yet calculated)
  final ETAResult? eta;

  /// Whether ETA calculation is currently active
  final bool isActive;

  /// Whether currently fetching API data
  final bool isFetchingAPI;

  /// Whether user is currently moving
  final bool isMoving;

  /// Whether user is moving toward destination
  final bool isMovingToward;

  /// Error message if calculation failed
  final String? error;

  /// Rate limit status
  final RateLimitStatus rateLimitStatus;

  /// Remaining API requests in current window
  final int remainingAPIRequests;

  /// When the rate limit window resets
  final DateTime? rateLimitResetAt;

  /// When the last API call was made
  final DateTime? lastAPICall;

  /// Timestamp to force state changes even when values are the same
  final DateTime timestamp;

  const ETAState({
    this.eta,
    this.isActive = false,
    this.isFetchingAPI = false,
    this.isMoving = false,
    this.isMovingToward = true,
    this.error,
    this.rateLimitStatus = RateLimitStatus.ok,
    this.remainingAPIRequests = 40,
    this.rateLimitResetAt,
    this.lastAPICall,
    required this.timestamp,
  });

  /// Initial state
  factory ETAState.initial() {
    return ETAState(timestamp: DateTime.now());
  }

  /// Check if we should call API (not called in last 5 minutes)
  bool shouldCallAPI() {
    if (lastAPICall == null) return true;
    return DateTime.now().difference(lastAPICall!).inMinutes >= 5;
  }

  @override
  List<Object?> get props {
    final propsList = [
      eta?.seconds,
      eta?.source,
      eta?.timestamp,
      isActive,
      isFetchingAPI,
      isMoving,
      isMovingToward,
      error,
      rateLimitStatus,
      remainingAPIRequests,
      rateLimitResetAt,
      lastAPICall,
      timestamp,
    ];

    print(
      '🔍 ETAState.props: timestamp=$timestamp, eta=${eta?.seconds}, isActive=$isActive',
    );

    return propsList;
  }

  @override
  int get hashCode {
    return Object.hash(
      eta?.seconds,
      eta?.source,
      isActive,
      isFetchingAPI,
      error,
      rateLimitStatus,
      timestamp.millisecondsSinceEpoch ~/ 1000, // Hash by second
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ETAState &&
        other.eta?.seconds == eta?.seconds &&
        other.eta?.source == eta?.source &&
        other.isActive == isActive &&
        other.isFetchingAPI == isFetchingAPI &&
        other.error == error &&
        other.rateLimitStatus == rateLimitStatus &&
        other.timestamp.millisecondsSinceEpoch ~/ 1000 ==
            timestamp.millisecondsSinceEpoch ~/
                1000; // Compare by second, not millisecond
  }

  ETAState copyWith({
    ETAResult? eta,
    bool? isActive,
    bool? isFetchingAPI,
    bool? isMoving,
    bool? isMovingToward,
    String? error,
    RateLimitStatus? rateLimitStatus,
    int? remainingAPIRequests,
    DateTime? rateLimitResetAt,
    DateTime? lastAPICall,
    bool clearError = false,
  }) {
    return ETAState(
      eta: eta ?? this.eta,
      isActive: isActive ?? this.isActive,
      isFetchingAPI: isFetchingAPI ?? this.isFetchingAPI,
      isMoving: isMoving ?? this.isMoving,
      isMovingToward: isMovingToward ?? this.isMovingToward,
      error: clearError ? null : (error ?? this.error),
      rateLimitStatus: rateLimitStatus ?? this.rateLimitStatus,
      remainingAPIRequests: remainingAPIRequests ?? this.remainingAPIRequests,
      rateLimitResetAt: rateLimitResetAt ?? this.rateLimitResetAt,
      lastAPICall: lastAPICall ?? this.lastAPICall,
      timestamp: DateTime.now(), // ✅ Always create new timestamp
    );
  }
}

/// Rate limit status for API requests
enum RateLimitStatus { ok, warning, exceeded }
