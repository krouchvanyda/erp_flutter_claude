import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../viewmodel/profile_view_model_bloc.dart';
import '../widgets/profile_content.dart';
import '../widgets/profile_logout_button.dart';

/// Screen 9.9 — My Profile (Step 4.1: view only).
///
/// Layout only. Which body to draw comes from the state:
///
/// ```
/// state.profile != null  → ProfileContent (pull to refresh)
/// ProfileErrorState      → AppErrorView + "Try again"
/// otherwise              → spinner
/// ```
///
/// [onLogout] comes from the app layer (`AuthRepository.logout`). The
/// profile feature doesn't import the auth repository (CLAUDE.md: features
/// don't use each other's internals).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProfileViewModelBloc>()..add(OnProfileLoadEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: const AppLabel(
            text: 'My Profile',
            fontSize: AppFontSize.value20,
            fontWeight: FontWeight.w600,
          ),
          actions: [
            ProfileLogoutButton(onLogout: onLogout), // top right
            const SizedBox(width: 4),
          ],
        ),
        body: BlocConsumer<ProfileViewModelBloc, ProfileViewModelState>(
          // A REFRESH failed while data is on screen → snackbar, keep data.
          listenWhen: (previous, current) =>
              current is ProfileErrorState && current.lastProfile != null,
          listener: (context, state) {
            if (state is ProfileErrorState) {
              AppSnackBar.error(
                context,
                title: state.error.title,
                message: state.error.description,
              );
            }
          },
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType ||
              previous.profile != current.profile, // thanks to == on models
          builder: (context, state) {
            final bloc = context.read<ProfileViewModelBloc>();
            final profile = state.profile;

            if (profile != null) {
              return RefreshIndicator(
                onRefresh: () {
                  bloc.add(OnProfileLoadEvent());
                  // the spinner stays until the bloc answers
                  return bloc.stream.firstWhere(
                    (s) => s is ProfileLoadedState || s is ProfileErrorState,
                  );
                },
                child: ProfileContent(profile: profile),
              );
            }
            if (state is ProfileErrorState) {
              return AppErrorView(
                title: state.error.title,
                message: state.error.description,
                onRetry: () => bloc.add(OnProfileLoadEvent()),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
