part of 'member_picker_view_model_bloc.dart';

@immutable
sealed class MemberPickerViewModelEvent {}

/// Page opened / "Try again" → load EVERY page of people (search is
/// done on the phone, so it needs the whole list).
final class OnPickerLoadEvent extends MemberPickerViewModelEvent {}

/// The search box changed.
final class OnPickerSearchEvent extends MemberPickerViewModelEvent {
  OnPickerSearchEvent(this.query);

  final String query;
}

/// Tick / untick a person (group + add-members modes).
final class OnPickerToggleEvent extends MemberPickerViewModelEvent {
  OnPickerToggleEvent(this.contact);

  final ContactModel contact;
}

/// New chat: tapped a person → open (or create) the 1-to-1 chat.
final class OnPickerCreateDirectEvent extends MemberPickerViewModelEvent {
  OnPickerCreateDirectEvent(this.contact);

  final ContactModel contact;
}

/// New group: "Create" on the name page, with the ticked people.
final class OnPickerCreateGroupEvent extends MemberPickerViewModelEvent {
  OnPickerCreateGroupEvent(this.name);

  final String name;
}

/// Add members: "Add" with the ticked people.
final class OnPickerAddMembersEvent extends MemberPickerViewModelEvent {
  OnPickerAddMembersEvent(this.conversationId);

  final String conversationId;
}
