part of 'typing_view_model_bloc.dart';

/// Who is typing in this conversation right now (never me).
@immutable
final class TypingViewModelState {
  const TypingViewModelState([this.userIds = const {}]);

  final Set<String> userIds;

  bool get anyone => userIds.isNotEmpty;

  static const _eq = SetEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is TypingViewModelState && _eq.equals(other.userIds, userIds);

  @override
  int get hashCode => _eq.hash(userIds);
}
