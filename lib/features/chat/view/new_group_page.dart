import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../viewmodel/member_picker/member_picker_view_model_bloc.dart';
import '../widgets/new_group_form.dart';
import '../widgets/selected_contacts_bar.dart';

/// New group, step 2: the name (Step 5.4). Layout only.
///
/// Shares the picker's bloc (`BlocProvider.value`), so it knows who was
/// ticked. "Create" → Done → closes with the new group.
class NewGroupPage extends StatelessWidget {
  const NewGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const AppLabel(
          text: 'New group',
          fontSize: AppFontSize.value20,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: BlocConsumer<MemberPickerViewModelBloc, MemberPickerViewModelState>(
        listenWhen: (previous, current) =>
            (current is MemberPickerDoneState ||
                current is MemberPickerSubmitFailedState) &&
            (ModalRoute.of(context)?.isCurrent ?? false),
        listener: (context, state) {
          if (state is MemberPickerDoneState) {
            Navigator.of(context).pop(state.conversation);
          } else if (state is MemberPickerSubmitFailedState) {
            AppSnackBar.error(
              context,
              title: state.error.title,
              message: state.error.description,
            );
          }
        },
        buildWhen: (previous, current) => previous.data != current.data,
        builder: (context, state) {
          final data = state.data;
          final selected = data?.selected ?? const [];
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NewGroupForm(
                      isLoading: data?.isSubmitting ?? false,
                      onCreate: (name) => context
                          .read<MemberPickerViewModelBloc>()
                          .add(OnPickerCreateGroupEvent(name)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: AppLabel(
                        text: '${selected.length + 1} members (with you)',
                        fontSize: AppFontSize.value14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    SelectedContactsBar(selected: selected),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
