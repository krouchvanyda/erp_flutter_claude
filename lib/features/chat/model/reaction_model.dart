/// One emoji reaction on a message (backend `ReactionDto`).
class ReactionModel {
  const ReactionModel({required this.userId, required this.emoji});

  final String userId;
  final String emoji;

  factory ReactionModel.fromJson(Map<String, dynamic> json) => ReactionModel(
    userId: '${json['userId'] ?? ''}',
    emoji: json['emoji'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is ReactionModel && other.userId == userId && other.emoji == emoji;

  @override
  int get hashCode => Object.hash(userId, emoji);

  @override
  String toString() => 'ReactionModel($userId, $emoji)';
}
