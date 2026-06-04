import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:erp_mobile/core/network/token_storage.dart';
import 'package:erp_mobile/core/router/auth_session.dart';

/// Outcome of the splash auto-login probe.
enum AppInitStatus { probing, authenticated, unauthenticated }

/// ViewModel state for the splash screen.
class AppInitState {
  const AppInitState({this.status = AppInitStatus.probing});

  final AppInitStatus status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppInitState &&
          runtimeType == other.runtimeType &&
          status == other.status;

  @override
  int get hashCode => Object.hash(runtimeType, status);
}

/// ViewModel for [SplashScreen] (Slice 1.1.5 auto-login).
///
/// Probes [TokenStorage]: if tokens are present it hydrates the in-process
/// session (so the router's redirect treats the user as signed in) and
/// emits [AppInitStatus.authenticated]; otherwise [unauthenticated]. The
/// View navigates on the resulting state — the Cubit never touches a
/// `BuildContext`.
///
/// An expired access token is fine here — the splash does NOT validate it;
/// the first authenticated call refreshes it via the `AuthInterceptor`.
class AppInitViewModel extends Cubit<AppInitState> {
  AppInitViewModel({
    required TokenStorage tokenStorage,
    required AuthSession authSession,
  })  : _tokenStorage = tokenStorage,
        _authSession = authSession,
        super(const AppInitState());

  final TokenStorage _tokenStorage;
  final AuthSession _authSession;

  /// Run the probe after [delay] (the splash animation runtime).
  Future<void> decide({
    Duration delay = const Duration(milliseconds: 2000),
  }) async {
    await Future<void>.delayed(delay);
    final tokens = await _tokenStorage.read();
    if (isClosed) return;

    final hasTokens = tokens != null && tokens.accessToken.isNotEmpty;
    if (hasTokens) {
      // Flip the in-process session BEFORE the View navigates — the
      // router's redirect reads `AuthSession.isAuthenticated` and would
      // bounce back to /login otherwise.
      _authSession.markAuthenticated();
      emit(const AppInitState(status: AppInitStatus.authenticated));
    } else {
      emit(const AppInitState(status: AppInitStatus.unauthenticated));
    }
  }
}
