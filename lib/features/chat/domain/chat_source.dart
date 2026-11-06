/// Represents a grounded source citation item returned by cortex-ai.
class ChatSource {
  final String noteId;
  final String title;
  final String chunkText;
  final double? score;
  final double? rerankScore;
  final double? distance;

  const ChatSource({
    required this.noteId,
    required this.title,
    required this.chunkText,
    this.score,
    this.rerankScore,
    this.distance,
  });

  factory ChatSource.fromMap(Map<String, dynamic> map) {
    return ChatSource(
      noteId: (map['note_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      chunkText: (map['chunk_text'] as String?) ?? '',
      score: (map['score'] as num?)?.toDouble(),
      rerankScore: (map['rerank_score'] as num?)?.toDouble(),
      distance: (map['distance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'note_id': noteId,
      'title': title,
      'chunk_text': chunkText,
      if (score != null) 'score': score,
      if (rerankScore != null) 'rerank_score': rerankScore,
      if (distance != null) 'distance': distance,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSource &&
          runtimeType == other.runtimeType &&
          noteId == other.noteId &&
          title == other.title &&
          chunkText == other.chunkText &&
          score == other.score &&
          rerankScore == other.rerankScore &&
          distance == other.distance;

  @override
  int get hashCode =>
      Object.hash(noteId, title, chunkText, score, rerankScore, distance);

  @override
  String toString() => 'ChatSource(noteId: $noteId, title: $title)';
}
