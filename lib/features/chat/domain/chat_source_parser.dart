import 'chat_source.dart';

/// Sealed class representing segments of an answer text (plain text vs. inline citation chip).
sealed class ChatTextSegment {
  const ChatTextSegment();
}

/// Plain conversational text without citations.
class PlainTextSegment extends ChatTextSegment {
  final String text;
  const PlainTextSegment(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlainTextSegment &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'PlainTextSegment("$text")';
}

/// Inline citation chip marker, e.g. [Source 1] pointing to sources[0].
class SourceCitationSegment extends ChatTextSegment {
  final int sourceIndex; // 0-based index: [Source 1] -> 0
  final int sourceNumber; // 1-based display number: 1
  final ChatSource source;

  const SourceCitationSegment({
    required this.sourceIndex,
    required this.sourceNumber,
    required this.source,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceCitationSegment &&
          runtimeType == other.runtimeType &&
          sourceIndex == other.sourceIndex &&
          sourceNumber == other.sourceNumber &&
          source == other.source;

  @override
  int get hashCode => Object.hash(sourceIndex, sourceNumber, source);

  @override
  String toString() =>
      'SourceCitationSegment(sourceIndex: $sourceIndex, sourceNumber: $sourceNumber, source: $source)';
}

final _sourceCitationRegex = RegExp(r'\[Source\s+(\d+)\]');

/// Pure function to parse inline citations such as `[Source 1]`, `[Source 2]`
/// into typed [ChatTextSegment]s.
///
/// `[Source N]` refers to `sources[N - 1]`.
/// If N is out of bounds (e.g. `[Source 9]` when there are only 3 sources)
/// or non-positive (e.g. `[Source 0]`), it is left as plain text.
List<ChatTextSegment> parseSourceCitations(
  String text,
  List<ChatSource> sources,
) {
  if (text.isEmpty) return const [];

  final matches = _sourceCitationRegex.allMatches(text);
  if (matches.isEmpty) {
    return [PlainTextSegment(text)];
  }

  final segments = <ChatTextSegment>[];
  int lastEnd = 0;

  for (final match in matches) {
    if (match.start > lastEnd) {
      segments.add(PlainTextSegment(text.substring(lastEnd, match.start)));
    }

    final numberStr = match.group(1);
    final number = numberStr != null ? int.tryParse(numberStr) : null;

    if (number != null && number > 0 && number <= sources.length) {
      final index = number - 1;
      segments.add(
        SourceCitationSegment(
          sourceIndex: index,
          sourceNumber: number,
          source: sources[index],
        ),
      );
    } else {
      // Out-of-bounds or invalid citation marker: preserve as raw text
      segments.add(PlainTextSegment(match.group(0)!));
    }

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    segments.add(PlainTextSegment(text.substring(lastEnd)));
  }

  return _mergeAdjacentPlainText(segments);
}

List<ChatTextSegment> _mergeAdjacentPlainText(List<ChatTextSegment> segments) {
  if (segments.length <= 1) return segments;
  final merged = <ChatTextSegment>[];
  for (final seg in segments) {
    if (merged.isNotEmpty &&
        merged.last is PlainTextSegment &&
        seg is PlainTextSegment) {
      final prev = merged.removeLast() as PlainTextSegment;
      merged.add(PlainTextSegment('${prev.text}${seg.text}'));
    } else {
      merged.add(seg);
    }
  }
  return merged;
}
