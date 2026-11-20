import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../viewmodel/profile_view_model_bloc.dart';
import '../widgets/profile_content.dart';
import '../widgets/profile_logout_button.dart';

/// Screen 9.9 — My Profile (4.1 view · 4.2 avatar).
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
          // One-time messages:
          // - refresh / avatar failed while data is on screen → red bar
          // - avatar changed → green-ish bar
          listenWhen: (previous, current) =>
              (current is ProfileErrorState && current.lastProfile != null) ||
              current is ProfileAvatarUpdatedState,
          listener: (context, state) {
            switch (state) {
              case ProfileErrorState(:final error):
                AppSnackBar.error(
                  context,
                  title: error.title,
                  message: error.description,
                );
              case ProfileAvatarUpdatedState(:final profile, :final removed):
                // If the server reuses the same URL for a new photo, the
                // disk cache would still show the old one → forget it.
                final url = ApiEndPoint.fileUrl(profile.avatarUrl);
                if (url != null) CachedNetworkImage.evictFromCache(url);
                AppSnackBar.success(
                  context,
                  message: removed ? 'Photo removed' : 'Photo updated',
                );
              default:
                break;
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
                    (s) =>
                        s is! ProfileLoadingState &&
                        s is! ProfileAvatarUploadingState,
                  );
                },
                child: ProfileContent(
                  profile: profile,
                  avatarBusy: state is ProfileAvatarUploadingState,
                ),
              );
            }
            if (state is ProfileErrorState) {
              return AppErrorView.fromError(
                state.error,
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
