class ReadingProgress {
  final int? id;
  final int bookId;
  final int chapterIndex;
  final double scrollOffset;
  final int updatedAt;

  const ReadingProgress({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    this.scrollOffset = 0.0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'scroll_offset': scrollOffset,
        'updated_at': updatedAt,
      };

  factory ReadingProgress.fromMap(Map<String, dynamic> map) =>
      ReadingProgress(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        chapterIndex: map['chapter_index'] as int,
        scrollOffset: (map['scroll_offset'] as num?)?.toDouble() ?? 0.0,
        updatedAt: map['updated_at'] as int,
      );
}
