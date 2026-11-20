import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error_model.dart';
import '../../model/user_model.dart';
import '../../repository/auth_repository.dart';

part 'login_view_model_event.dart';
part 'login_view_model_state.dart';

/// The login screen's ViewModel (MVVM-template style).
///
/// event OnLoginSubmittedEvent
///   → emit LoginLoadingState
///   → repository.login(...)
///   → emit LoginErrorState(error)  or  LoginSuccessState(user)
class LoginViewModelBloc
    extends Bloc<LoginViewModelEvent, LoginViewModelState> {
  LoginViewModelBloc(this._repository) : super(LoginViewModelInitial()) {
    on<OnLoginSubmittedEvent>(_onLoginSubmitted);
  }

  final AuthRepository _repository;

  Future<void> _onLoginSubmitted(
    OnLoginSubmittedEvent event,
    Emitter<LoginViewModelState> emit,
  ) async {
    if (state is LoginLoadingState) return; // ignore double taps
    emit(LoginLoadingState());
    final result = await _repository.login(
      email: event.email,
      password: event.password,
    );
    result.fold(
      (error) => emit(LoginErrorState(error: error)),
      (user) => emit(LoginSuccessState(user: user)),
    );
  }
}
