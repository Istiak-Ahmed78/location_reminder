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

  // ✅ FIXED: Proper hashCode that works with Bloc's distinct()
  @override
  int get hashCode {
    // Combine all fields into a single hash
    // Use bitwise operations to combine hashes properly
    int hash = 0;
    hash = hash ^ (eta?.hashCode ?? 0);
    hash = hash ^ isActive.hashCode;
    hash = hash ^ isFetchingAPI.hashCode;
    hash = hash ^ isMoving.hashCode;
    hash = hash ^ isMovingToward.hashCode;
    hash = hash ^ (error?.hashCode ?? 0);
    hash = hash ^ rateLimitStatus.hashCode;
    hash = hash ^ remainingAPIRequests.hashCode;
    hash = hash ^ (rateLimitResetAt?.hashCode ?? 0);
    hash = hash ^ (lastAPICall?.hashCode ?? 0);
    hash = hash ^ timestamp.hashCode;

    print(
      '🔍 ETAState.hashCode: $hash (timestamp: $timestamp, eta: ${eta?.seconds})',
    );
    return hash;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is ETAState) {
      print('🔍 ETAState == comparison:');
      print(
        '   this.timestamp: $timestamp vs other.timestamp: ${other.timestamp}',
      );
      print('   this.eta: ${eta?.seconds} vs other.eta: ${other.eta?.seconds}');
      print('   this.hashCode: $hashCode vs other.hashCode: ${other.hashCode}');

      final result = super == other;
      print('   Result: $result');
      return result;
    }

    return false;
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
