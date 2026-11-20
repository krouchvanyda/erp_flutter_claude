import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../model/profile_model.dart';
import '../viewmodel/profile_view_model_bloc.dart';
import 'profile_avatar_sheet.dart';

/// Design guide 9.9 "AvatarEditRow": the avatar with a camera badge.
///
/// ```
///    ┌──────┐
///    │  JD  │   tap → sheet → camera / gallery / remove
///    └───(📷)   badge bottom-right
/// ```
///
/// - [busy] → a spinner over the avatar, taps ignored (upload running).
/// - No employee record → no badge (the server has no avatar to change:
///   `/employees/me/avatar` would answer 404).
///
/// Picking a file is UI work (it opens system screens), so it lives here.
/// The upload itself is business → `OnAvatarUploadEvent` → BLoC →
/// repository.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, required this.busy});

  final ProfileModel profile;
  final bool busy;

  static const double _size = 88;

  /// Small photos upload fast and stay under the server's upload limit
  /// (Spring's default is 1 MB). 1024 px is plenty for an 88 px circle on
  /// a 3× screen.
  static const double _maxSide = 1024;
  static const int _quality = 85; // JPEG quality: smaller, no visible loss

  bool get _canEdit => profile.employee != null;

  Future<void> _onTap(BuildContext context) async {
    final bloc = context.read<ProfileViewModelBloc>(); // read BEFORE awaits
    final action = await ProfileAvatarSheet.show(
      context,
      canRemove: profile.avatarUrl != null,
    );
    if (action == null || !context.mounted) return;

    if (action == AvatarAction.remove) {
      bloc.add(OnAvatarRemoveEvent());
      return;
    }

    try {
      final file = await ImagePicker().pickImage(
        source: action == AvatarAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front, // selfie
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (file == null) return; // the user cancelled
      bloc.add(OnAvatarUploadEvent(filePath: file.path));
    } on PlatformException catch (e) {
      // Usually: camera / photos permission denied.
      if (!context.mounted) return;
      AppSnackBar.error(
        context,
        title:
            'Cannot open ${action == AvatarAction.camera ? 'camera' : 'photos'}',
        message: e.code.contains('denied')
            ? 'Please allow access in Settings.'
            : (e.message ?? 'Please try again.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        AppAvatar(
          name: profile.displayName,
          imageUrl: ApiEndPoint.fileUrl(profile.avatarUrl),
          size: _size,
        ),
        if (busy)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Light: dark veil + light spinner. Dark: light veil + dark
                // spinner. Always readable, no hard-coded colours.
                color: colors.onSurface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.surface,
                  ),
                ),
              ),
            ),
          ),
        if (_canEdit && !busy)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                // a ring in the card colour separates badge and photo
                border: Border.all(color: colors.primaryContainer, width: 3),
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 15,
                color: colors.onPrimary,
              ),
            ),
          ),
      ],
    );

    if (!_canEdit) return avatar;
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        onTap: busy ? null : () => _onTap(context),
        child: avatar,
      ),
    );
  }
}
