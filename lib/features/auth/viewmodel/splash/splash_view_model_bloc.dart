import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repository/auth_repository.dart';

part 'splash_view_model_event.dart';
part 'splash_view_model_state.dart';

/// The splash screen's ViewModel: the ONLY place that decides auto-login.
///
/// event OnSplashStartedEvent
///   → [onStart] (fire and forget: iOS asks "Local Network?" now, not at login)
///   → at the SAME time: repository.restoreSession()  +  wait [minDuration]
///   → emit SplashFinishedState(isLoggedIn)
///
/// [minDuration] lets the logo animation play (design guide: 900 ms) even
/// when the token check is instant. Tests pass `Duration.zero`.
class SplashViewModelBloc
    extends Bloc<SplashViewModelEvent, SplashViewModelState> {
  SplashViewModelBloc(
    this._repository, {
    this.minDuration = const Duration(milliseconds: 1200),
    void Function()? onStart,
  }) : _onStart = onStart,
       super(SplashViewModelInitial()) {
    on<OnSplashStartedEvent>(_onStarted);
  }

  final AuthRepository _repository;
  final Duration minDuration;
  final void Function()? _onStart;

  Future<void> _onStarted(
    OnSplashStartedEvent event,
    Emitter<SplashViewModelState> emit,
  ) async {
    _onStart?.call(); // never awaited: the splash keeps its normal timing
    // A record of 2 futures + `.wait` = run both together, wait for both.
    // Total time = the LONGER one (not the sum).
    final (isLoggedIn, _) = await (
      _repository.restoreSession(),
      Future<void>.delayed(minDuration),
    ).wait;
    emit(SplashFinishedState(isLoggedIn: isLoggedIn));
  }
}
