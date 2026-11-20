import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../model/chat_attachment.dart';
import '../model/chat_enums.dart';

/// A file the user picked and that passed [AttachmentRules].
typedef PickedAttachment = ({MessageType type, String path});

/// 📎 → "Camera · Photo library · PDF document" → the picked file.
///
/// Picking opens SYSTEM screens (they need a context), so it lives in the
/// UI, like the profile avatar (Step 4.2). Uploading is the bloc's job.
abstract final class ChatAttachSheet {
  /// null = cancelled, or the file was refused (a snackbar said why).
  static Future<PickedAttachment?> pick(BuildContext context) async {
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in _Choice.values)
                ListTile(
                  leading: Icon(
                    c.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: AppLabel(
                    text: c.label,
                    fontSize: AppFontSize.value16,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () => Navigator.of(context).pop(c),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return null;

    final String? path;
    final MessageType type;
    switch (choice) {
      case _Choice.camera || _Choice.gallery:
        // Shrink like the avatar: a 4 MB photo → ~300 KB, still sharp.
        final photo = await ImagePicker().pickImage(
          source: choice == _Choice.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
        path = photo?.path;
        type = MessageType.image;
      case _Choice.pdf:
        // The server accepts only PDF documents today.
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        path = result?.files.single.path;
        type = MessageType.file;
    }
    if (path == null) return null;

    final problem = AttachmentRules.problem(
      fileName: path,
      sizeBytes: await File(path).length(),
    );
    if (problem != null) {
      if (context.mounted) {
        AppSnackBar.warning(context, title: 'Can\'t send', message: problem);
      }
      return null;
    }
    return (type: type, path: path);
  }
}

enum _Choice {
  camera(Icons.photo_camera_outlined, 'Camera'),
  gallery(Icons.photo_library_outlined, 'Photo library'),
  pdf(Icons.picture_as_pdf_outlined, 'PDF document');

  const _Choice(this.icon, this.label);
  final IconData icon;
  final String label;
}
