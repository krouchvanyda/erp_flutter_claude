import 'package:collection/collection.dart';
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error_model.dart';
import '../../model/contact_model.dart';
import '../../model/conversation_model.dart';
import '../../repository/chat_repository.dart';

part 'member_picker_view_model_event.dart';
part 'member_picker_view_model_state.dart';

/// The member picker's ViewModel (Step 5.4). ONE picker, three jobs:
///
/// ```
/// new chat     tap a person ──► createDirect ──► Done(conversation)
/// new group    tick people ──► (name page) ──► createGroup ──► Done
/// add members  tick people ──► addMembers ──► Done(updated group)
/// ```
///
/// Loading: page 1 shows at once, the other pages follow in the background
/// (the server ignores `search`, so the phone needs everyone to search).
class MemberPickerViewModelBloc
    extends Bloc<MemberPickerViewModelEvent, MemberPickerViewModelState> {
  MemberPickerViewModelBloc(this._repository, {this.excludeIds = const {}})
    : super(MemberPickerInitial()) {
    on<OnPickerLoadEvent>(_onLoad);
    on<OnPickerSearchEvent>(_onSearch);
    on<OnPickerToggleEvent>(_onToggle);
    on<OnPickerCreateDirectEvent>(_onCreateDirect);
    on<OnPickerCreateGroupEvent>(_onCreateGroup);
    on<OnPickerAddMembersEvent>(_onAddMembers);
  }

  final ChatRepository _repository;

  /// Already in the group (add-members mode) → not shown.
  final Set<String> excludeIds;

  /// A safety cap: 50 × 100 = 5 000 people.
  static const int maxPages = 50;

  Future<void> _onLoad(
    OnPickerLoadEvent event,
    Emitter<MemberPickerViewModelState> emit,
  ) async {
    if (state is MemberPickerLoadingState) return;
    if (state.data == null) emit(MemberPickerLoadingState());

    final myId = await _repository.myUserId();
    bool keep(ContactModel c) =>
        c.enabled && c.id != myId && !excludeIds.contains(c.id);

    var page = 1;
    var hasMore = true;
    var first = true;
    while (hasMore && page <= maxPages) {
      final result = await _repository.loadContacts(page: page);
      final ok = result.fold(
        (error) {
          emit(MemberPickerErrorState(error: error, lastData: _calm()));
          return false;
        },
        (p) {
          final current = state.data; // keep the query / selection
          final base = first ? <ContactModel>[] : (current?.contacts ?? []);
          final seen = base.map((c) => c.id).toSet();
          emit(
            MemberPickerLoadedState(
              contacts: [
                ...base,
                ...p.items.where((c) => keep(c) && seen.add(c.id)),
              ],
              query: current?.query ?? '',
              selected: current?.selected ?? const [],
              isLoadingMore: p.hasMore,
            ),
          );
          hasMore = p.hasMore;
          return true;
        },
      );
      if (!ok) return;
      first = false;
      page++;
    }
  }

  void _onSearch(
    OnPickerSearchEvent event,
    Emitter<MemberPickerViewModelState> emit,
  ) {
    final data = state.data;
    if (data == null) return;
    _emitData(emit, data.copyWith(query: event.query));
  }

  void _onToggle(
    OnPickerToggleEvent event,
    Emitter<MemberPickerViewModelState> emit,
  ) {
    final data = state.data;
    if (data == null || data.isSubmitting) return;
    final c = event.contact;
    _emitData(
      emit,
      data.copyWith(
        selected: data.isSelected(c)
            ? [
                for (final s in data.selected)
                  if (s.id != c.id) s,
              ]
            : [...data.selected, c],
      ),
    );
  }

  Future<void> _onCreateDirect(
    OnPickerCreateDirectEvent event,
    Emitter<MemberPickerViewModelState> emit,
  ) => _submit(emit, () => _repository.createDirect(event.contact.id));

  Future<void> _onCreateGroup(
    OnPickerCreateGroupEvent event,
    Emitter<MemberPickerViewModelState> emit,
  ) async {
    final data = state.data;
    if (event.name.trim().isEmpty || data == null || data.selected.isEmpty) {
      return;
    }
    await _submit(
      emit,
      () => _repository.createGroup(
        name: event.name,
        memberIds: [for (final c in data.selected) c.id],
      ),
    );
  }

  Future<void> _onAddMembers(
    OnPickerAddMembersEvent event,
    Emitter<MemberPickerViewModelState> emit,
  ) async {
    final data = state.data;
    if (data == null || data.selected.isEmpty) return;
    await _submit(
      emit,
      () => _repository.addMembers(event.conversationId, [
        for (final c in data.selected) c.id,
      ]),
    );
  }

  /// Busy → call → Done or SubmitFailed. One at a time (double taps ignored).
  Future<void> _submit(
    Emitter<MemberPickerViewModelState> emit,
    Future<Either<NetworkErrorModel, ConversationModel>> Function() call,
  ) async {
    final data = state.data;
    if (data == null || data.isSubmitting) return;
    _emitData(emit, data.copyWith(isSubmitting: true));

    final result = await call();
    final after = (state.data ?? data).copyWith(isSubmitting: false);
    result.fold(
      (error) =>
          emit(MemberPickerSubmitFailedState(error: error, lastData: after)),
      (conversation) => emit(
        MemberPickerDoneState(conversation: conversation, lastData: after),
      ),
    );
  }

  /// The current data, not busy.
  MemberPickerLoadedState? _calm() =>
      state.data?.copyWith(isLoadingMore: false, isSubmitting: false);

  /// Keep a load error's banner; otherwise a plain Loaded.
  void _emitData(
    Emitter<MemberPickerViewModelState> emit,
    MemberPickerLoadedState data,
  ) {
    final current = state;
    emit(
      current is MemberPickerErrorState
          ? MemberPickerErrorState(error: current.error, lastData: data)
          : data,
    );
  }
}
