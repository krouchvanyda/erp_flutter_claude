part of 'member_picker_view_model_bloc.dart';

@immutable
sealed class MemberPickerViewModelState {
  /// The list to draw, if any (same idea as the inbox).
  MemberPickerLoadedState? get data => null;
}

final class MemberPickerInitial extends MemberPickerViewModelState {}

final class MemberPickerLoadingState extends MemberPickerViewModelState {}

final class MemberPickerLoadedState extends MemberPickerViewModelState {
  MemberPickerLoadedState({
    required this.contacts,
    this.query = '',
    this.selected = const [],
    this.isLoadingMore = false,
    this.isSubmitting = false,
  });

  /// Everyone loaded so far, WITHOUT me, disabled accounts and people who
  /// are already in the group (add-members mode).
  final List<ContactModel> contacts;
  final String query;

  /// Ticked people, in the order they were ticked (the chips on top).
  final List<ContactModel> selected;

  /// More pages still coming in the background → small spinner.
  final bool isLoadingMore;

  /// Create / Add on its way → buttons show a spinner, taps ignored.
  final bool isSubmitting;

  @override
  MemberPickerLoadedState get data => this;

  /// What the list shows: [contacts] filtered by [query].
  List<ContactModel> get visible => [
    for (final c in contacts)
      if (c.matches(query)) c,
  ];

  bool isSelected(ContactModel c) => selected.any((s) => s.id == c.id);

  MemberPickerLoadedState copyWith({
    List<ContactModel>? contacts,
    String? query,
    List<ContactModel>? selected,
    bool? isLoadingMore,
    bool? isSubmitting,
  }) => MemberPickerLoadedState(
    contacts: contacts ?? this.contacts,
    query: query ?? this.query,
    selected: selected ?? this.selected,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isSubmitting: isSubmitting ?? this.isSubmitting,
  );

  static const _eq = ListEquality<ContactModel>();

  @override
  bool operator ==(Object other) =>
      other is MemberPickerLoadedState &&
      _eq.equals(other.contacts, contacts) &&
      other.query == query &&
      _eq.equals(other.selected, selected) &&
      other.isLoadingMore == isLoadingMore &&
      other.isSubmitting == isSubmitting;

  @override
  int get hashCode => Object.hash(
    _eq.hash(contacts),
    query,
    _eq.hash(selected),
    isLoadingMore,
    isSubmitting,
  );
}

/// The FIRST page failed (nothing to show) → AppErrorView, or a later page
/// failed → keep what we have (lastData) + AppErrorBanner.
final class MemberPickerErrorState extends MemberPickerViewModelState {
  MemberPickerErrorState({required this.error, this.lastData});

  final NetworkErrorModel error;
  final MemberPickerLoadedState? lastData;

  @override
  MemberPickerLoadedState? get data => lastData;
}

/// Create / Add failed → the list stays, the page shows a snackbar.
final class MemberPickerSubmitFailedState extends MemberPickerViewModelState {
  MemberPickerSubmitFailedState({required this.error, required this.lastData});

  final NetworkErrorModel error;
  final MemberPickerLoadedState lastData;

  @override
  MemberPickerLoadedState get data => lastData;
}

/// Done → the page closes with [conversation] (the inbox then opens it).
final class MemberPickerDoneState extends MemberPickerViewModelState {
  MemberPickerDoneState({required this.conversation, required this.lastData});

  final ConversationModel conversation;
  final MemberPickerLoadedState lastData;

  @override
  MemberPickerLoadedState get data => lastData;
}
