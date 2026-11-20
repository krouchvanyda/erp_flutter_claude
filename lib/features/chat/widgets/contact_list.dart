import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/contact_model.dart';
import 'contact_tile.dart';

/// The people in the member picker (+ an optional first row, e.g.
/// "New group", and a small spinner while more pages load).
class ContactList extends StatelessWidget {
  const ContactList({
    super.key,
    required this.contacts,
    required this.onTap,
    required this.isLoadingMore,
    this.selectable = false,
    this.isSelected,
    this.header,
  });

  final List<ContactModel> contacts;
  final ValueChanged<ContactModel>? onTap; // null → busy, taps ignored
  final bool isLoadingMore;
  final bool selectable;
  final bool Function(ContactModel)? isSelected;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final extra = (header == null ? 0 : 1);
    final count = extra + contacts.length + 1; // +1: spinner / empty text

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: count,
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header!;
        final i = index - extra;
        if (i == contacts.length) {
          if (isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (contacts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AppLabel(
                text: 'No people found',
                fontSize: AppFontSize.value14,
                color: colors.onSurfaceVariant,
                textAlign: TextAlign.center,
              ),
            );
          }
          return const SizedBox(height: AppSpacing.xxl); // room for the FAB
        }
        final c = contacts[i];
        return ContactTile(
          key: ValueKey(c.id),
          contact: c,
          selectable: selectable,
          selected: isSelected?.call(c) ?? false,
          onTap: onTap == null ? null : () => onTap!(c),
        );
      },
    );
  }
}
