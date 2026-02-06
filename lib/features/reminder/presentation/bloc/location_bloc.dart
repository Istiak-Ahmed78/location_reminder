import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/usecases/ensure_location_permission.dart';
import '../../domain/usecases/get_current_location.dart';

part 'location_event.dart';
part 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final EnsureLocationPermission ensurePermission;
  final GetCurrentLocation getCurrentLocation;

  LocationBloc({
    required this.ensurePermission,
    required this.getCurrentLocation,
  }) : super(const LocationState.initial()) {
    on<LocationRequested>(_onLocationRequested);
  }

  Future<void> _onLocationRequested(
    LocationRequested event,
    Emitter<LocationState> emit,
  ) async {
    emit(state.copyWith(status: LocationStatus.loading, errorMessage: null));

    try {
      await ensurePermission(const NoParams());
      final loc = await getCurrentLocation(const NoParams());
      emit(state.copyWith(status: LocationStatus.success, location: loc));
    } catch (e) {
      emit(
        state.copyWith(
          status: LocationStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
