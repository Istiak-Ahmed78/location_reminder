import 'package:equatable/equatable.dart';
import '../../domain/entities/eta_result.dart';

/// States for ETA BLoC
class ETAState extends Equatable {
  /// Current ETA result
  final ETAResult? eta;

  /// Whether ETA calculation is active
  final bool isActive;

  /// Whether currently fetching from API
  final bool isFetchingAPI;

  /// Last API call timestamp
  final DateTime? lastAPICall;

  /// Error message if any
  final String? error;

  /// Whether user is moving
  final bool isMoving;

  /// Whether user is moving toward destination
  final bool isMovingToward;

  /// API rate limit status
  final RateLimitStatus rateLimitStatus;

  /// Remaining API requests today
  final int remainingAPIRequests;

  const ETAState({
    this.eta,
    this.isActive = false,
    this.isFetchingAPI = false,
    this.lastAPICall,
    this.error,
    this.isMoving = false,
    this.isMovingToward = true,
    this.rateLimitStatus = RateLimitStatus.ok,
    this.remainingAPIRequests = 2000,
  });

  /// Initial state
  factory ETAState.initial() => const ETAState();

  /// Check if should call API (based on time since last call)
  bool shouldCallAPI({Duration interval = const Duration(minutes: 10)}) {
    if (lastAPICall == null) return true;
    return DateTime.now().difference(lastAPICall!) > interval;
  }

  /// Get display message based on state
  String? get displayMessage {
    if (error != null) return error;
    if (!isActive) return null;
    if (!isMoving) return 'Not moving';
    if (!isMovingToward) return 'Moving away';
    if (eta == null) return 'Calculating...';
    if (rateLimitStatus == RateLimitStatus.exceeded) {
      return 'API limit reached (GPS mode)';
    }
    return null;
  }

  @override
  List<Object?> get props => [
    eta,
    isActive,
    isFetchingAPI,
    lastAPICall,
    error,
    isMoving,
    isMovingToward,
    rateLimitStatus,
    remainingAPIRequests,
  ];

  ETAState copyWith({
    ETAResult? eta,
    bool? isActive,
    bool? isFetchingAPI,
    DateTime? lastAPICall,
    String? error,
    bool? isMoving,
    bool? isMovingToward,
    RateLimitStatus? rateLimitStatus,
    int? remainingAPIRequests,
  }) {
    return ETAState(
      eta: eta ?? this.eta,
      isActive: isActive ?? this.isActive,
      isFetchingAPI: isFetchingAPI ?? this.isFetchingAPI,
      lastAPICall: lastAPICall ?? this.lastAPICall,
      error: error,
      isMoving: isMoving ?? this.isMoving,
      isMovingToward: isMovingToward ?? this.isMovingToward,
      rateLimitStatus: rateLimitStatus ?? this.rateLimitStatus,
      remainingAPIRequests: remainingAPIRequests ?? this.remainingAPIRequests,
    );
  }

  /// Clear error
  ETAState clearError() {
    return copyWith(error: null);
  }
}

/// API rate limit status
enum RateLimitStatus {
  ok, // Normal operation
  warning, // Approaching limit (80%+)
  exceeded, // Limit exceeded
}
